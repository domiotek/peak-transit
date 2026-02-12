extends "res://addons/godot_rl_agents/controller/ai_controller_2d.gd"

class_name ChallengeAiController

var game_manager: GameManager = GDInjector.inject("GameManager") as GameManager
var transport_manager: TransportManager = GDInjector.inject("TransportManager") as TransportManager
var network_manager: NetworkManager = GDInjector.inject("NetworkManager") as NetworkManager
var vehicle_manager: VehicleManager = GDInjector.inject("VehicleManager") as VehicleManager

var _depots: Array = []
var _terminals: Array = []
var _brigades: Array = []
var _buses_available: Dictionary = { }
var _buses: Array = []

var _score_manager: ScoreManager


func setup() -> void:
	_depots = transport_manager.get_depots()
	_terminals = transport_manager.get_terminals()
	_brigades = transport_manager.brigades.get_all()
	_buses_available = TransportHelper.get_total_bus_availability(_depots)

	_buses.resize(_buses_available["regular"] + _buses_available["articulated"])
	_buses.fill(null)

	_score_manager = game_manager.get_game_controller().score_manager()
	reset_after = RLConstants.RL_RESET_AFTER_STEPS


func gather_features() -> Dictionary:
	var time_of_day = game_manager.clock.get_time().to_time_of_day().to_sin_cos()
	var brigades = transport_manager.brigades.get_all()

	var bus_features = _gather_bus_features(_buses)
	var brigade_features = _gather_brigade_features(brigades)

	return {
		"time_of_day": time_of_day,
		"bus_state_onehot": bus_features["bus_state_onehot"],
		"bus_type_onehot": bus_features["bus_type_onehot"],
		"bus_availability": bus_features["bus_availability"],
		"bus_load_ratio": bus_features["bus_load_ratio"],
		"bus_delay": bus_features["bus_delay"],
		"brigade_bus_count": brigade_features["brigade_bus_count"],
		"brigade_unserved_demand": brigade_features["brigade_unserved_demand"],
		"brigade_spillover_risk": brigade_features["brigade_spillover_risk"],
		"brigade_traffic_intensity": brigade_features["brigade_traffic_intensity"],
		"brigade_time_to_next_departure": brigade_features["brigade_time_to_next_departure"],
		"brigade_gap_ahead_norm": brigade_features["brigade_gap_ahead_norm"],
	}


func get_obs() -> Dictionary:
	print("getting obs at time: ", game_manager.clock.get_time().to_time_of_day().format())
	var features = gather_features()

	return { "obs": _flatten_features(features) }


func get_reward() -> float:
	for bus_idx in range(_buses.size()):
		var bus = _buses[bus_idx] as Vehicle

		if bus == null:
			continue

		var cost_reason = (ChallengeEnums.ScoreReason.BUS_ARTICULATED_UPKEEP_COST
			if _is_bus_articulated(bus_idx) else ChallengeEnums.ScoreReason.BUS_REGULAR_UPKEEP_COST )

		_score_manager.update_score(cost_reason)

	for brigade_idx in range(_brigades.size()):
		var brigade = _brigades[brigade_idx] as Brigade

		var ongoing_trip_info = BrigadeHelper.get_ongoing_trip(brigade, game_manager.clock.get_time().to_time_of_day())
		if ongoing_trip_info["ongoing_trip"] == null:
			continue

		if ongoing_trip_info["assigned_bus"] == null:
			_score_manager.update_score(ChallengeEnums.ScoreReason.UNSERVED_BRIGADE)

	print("reward: ", _score_manager.get_score())
	return _score_manager.get_score()


func zero_reward() -> void:
	_score_manager.reset_score()


func get_action_space() -> Dictionary:
	var n = _buses_available["regular"] + _buses_available["articulated"]
	var k = transport_manager.brigades.get_count()
	var t = transport_manager.terminal_count()

	return {
		"command": {
			"size": RLEnums.ActionType.size(),
			"action_type": "discrete",
		},
		"bus_idx": {
			"size": n,
			"action_type": "discrete",
		},
		"state": {
			"size": RLEnums.BusStateRequest.size(),
			"action_type": "discrete",
		},
		"brigade_idx": {
			"size": k,
			"action_type": "discrete",
		},
		"reserve_term_idx": {
			"size": t,
			"action_type": "discrete",
		},
	}


func set_action(action) -> void:
	match action["command"] as int:
		RLEnums.ActionType.NO_OP:
			print("Received NO_OP action, doing nothing")
			return
		RLEnums.ActionType.SET_STATE:
			_set_state_action(action["bus_idx"], action["state"], action["reserve_term_idx"])
		RLEnums.ActionType.ASSIGN_TO_BRIGADE:
			_assign_to_brigade_action(action["bus_idx"], action["brigade_idx"])


func _gather_bus_features(buses: Array) -> Dictionary:
	var features = {
		"bus_state_onehot": [],
		"bus_type_onehot": [],
		"bus_availability": [],
		"bus_load_ratio": [],
		"bus_delay": [],
	}

	var current_bus_counts = TransportHelper.get_total_deployed_buses(_depots)

	features["bus_availability"] = [
		current_bus_counts["regular"] / _buses_available["regular"],
		current_bus_counts["articulated"] / _buses_available["articulated"],
	]

	for bus_idx in range(buses.size()):
		var bus = buses[bus_idx] as Vehicle
		var bus_type = RLEnums.BusType.ARTICULATED if _is_bus_articulated(bus_idx) else RLEnums.BusType.REGULAR

		features["bus_type_onehot"].append_array(_onehot_encode(bus_type, RLEnums.BusType.size()))

		if bus == null:
			features["bus_state_onehot"].append_array(_onehot_encode(RLEnums.BusState.AT_DEPOT, RLEnums.BusState.size()))
			features["bus_load_ratio"].append(1.0)
			features["bus_delay"].append(0.0)
			continue

		var bus_ai = bus.ai as BusAI

		var bus_state = _get_bus_state(bus)
		features["bus_state_onehot"].append_array(_onehot_encode(bus_state, RLEnums.BusState.size()))

		var passenger_stats = bus_ai.get_passenger_counts()
		features["bus_load_ratio"].append(passenger_stats.current_passengers / max(passenger_stats.max_passengers, 1))

		var time_diff = bus_ai.get_time_difference_to_schedule(game_manager.clock.get_time().to_time_of_day())
		features["bus_delay"].append(time_diff / 60.0)

	return features


func _gather_brigade_features(brigades: Array) -> Dictionary:
	var features = {
		"brigade_bus_count": [],
		"brigade_unserved_demand": [],
		"brigade_spillover_risk": [],
		"brigade_traffic_intensity": [],
		"brigade_time_to_next_departure": [],
		"brigade_gap_ahead_norm": [],
	}

	var total_buses = _buses_available["regular"] + _buses_available["articulated"]
	var current_time = game_manager.clock.get_time().to_time_of_day()

	for brigade in brigades as Array[Brigade]:
		features["brigade_bus_count"].append(brigade.get_vehicle_count() / total_buses)

		var ongoing_trip = BrigadeHelper.get_ongoing_trip(brigade, current_time)

		if ongoing_trip["ongoing_trip"] == null:
			features["brigade_unserved_demand"].append(0.0)
			features["brigade_spillover_risk"].append(0.0)
			features["brigade_traffic_intensity"].append(0.0)
			features["brigade_time_to_next_departure"].append(1.0)
			features["brigade_gap_ahead_norm"].append(1.0)
			continue

		var waiting_passengers_ahead = BrigadeHelper.get_waiting_passengers(brigade, ongoing_trip["ongoing_trip"], ongoing_trip["next_stop_idx"])

		var serving_vehicle = ongoing_trip["assigned_bus"] as Vehicle
		var bus_ai = serving_vehicle.ai as BusAI if serving_vehicle != null else null

		features["brigade_unserved_demand"].append(waiting_passengers_ahead["own_waiting"] / max(waiting_passengers_ahead["max_waiting"], 1))

		if bus_ai != null:
			var passenger_stats = bus_ai.get_passenger_counts()
			var next_bus_capacity = passenger_stats.max_passengers - passenger_stats.current_passengers

			features["brigade_spillover_risk"].append(
				clamp(
					(waiting_passengers_ahead["own_waiting_next_stop"] - next_bus_capacity) / max(waiting_passengers_ahead["max_waiting_next_stop"], 1),
					0.0,
					1.0,
				),
			)
		else:
			features["brigade_spillover_risk"].append(1.0)

		var transport_line = transport_manager.get_line(brigade.line_id) as TransportLine

		features["brigade_traffic_intensity"].append(
			BrigadeHelper.get_average_traffic(
				network_manager,
				transport_line,
				ongoing_trip["ongoing_trip"],
				ongoing_trip["next_stop_idx"],
				ongoing_trip["assigned_bus"],
			),
		)

		var next_trip = brigade.get_next_trip(current_time)
		features["brigade_time_to_next_departure"].append(next_trip.get_time_till_departure() / 60.0)

		var departure_time = ongoing_trip["ongoing_trip"].get_departure_terminal().get_departure_time_for_line(brigade.line_id)
		if departure_time == null:
			features["brigade_gap_ahead_norm"].append(1.0)
			continue
		var time_diff = departure_time.difference_in_minutes_sin_cos(current_time) as int
		features["brigade_gap_ahead_norm"].append(clamp(time_diff / 2.0 * transport_line.get_frequency_minutes(), 0.0, 1.0))

	return features


func _get_bus_state(bus: Vehicle) -> RLEnums.BusState:
	var bus_ai = bus.ai as BusAI

	var state = bus_ai.get_current_state()

	match state:
		BusAI.BusState.IDLE:
			return RLEnums.BusState.IN_RESERVE
		BusAI.BusState.CONFUSED:
			push_error("Bus ID %d is in CONFUSED state. Breaking training." % bus.id)
			done = true
			return RLEnums.BusState.IN_RESERVE
		BusAI.BusState.RETURNING_TO_DEPOT, BusAI.BusState.TRANSFERING_TO_TERMINAL, BusAI.BusState.TRANSFERING_TO_STOP:
			return RLEnums.BusState.TRANSFER
		BusAI.BusState.EN_ROUTE, BusAI.BusState.BOARDING_PASSENGERS, BusAI.BusState.SYNCING_WITH_SCHEDULE:
			return RLEnums.BusState.EN_ROUTE
		BusAI.BusState.WAIT_BETWEEN_TRIPS:
			return RLEnums.BusState.IN_RESERVE if bus_ai.get_brigade() == null else RLEnums.BusState.WAITING_FOR_TRIP
		_:
			return RLEnums.BusState.AT_DEPOT


func _is_bus_articulated(bus_idx: int) -> bool:
	return bus_idx >= _buses_available["regular"]


func _flatten_features(features: Dictionary) -> Array:
	var flat = []
	for key in features.keys():
		flat += features[key]
	return flat


func _onehot_encode(value: int, size: int) -> Array:
	var onehot = []
	for i in range(size):
		onehot.append(1.0 if i == value else 0.0)
	return onehot


func _set_state_action(bus_idx: int, state: RLEnums.BusStateRequest, reserve_term_idx: int) -> void:
	var bus = _buses[bus_idx] as Vehicle

	print("Setting state of bus index %d to state %d with reserve terminal index %d" % [bus_idx, state, reserve_term_idx])

	match state:
		RLEnums.BusStateRequest.DEPOT:
			if bus == null:
				_score_manager.update_score(ChallengeEnums.ScoreReason.BUS_INVALID_STATE_FOR_ACTION)
				return

			var bus_ai = bus.ai as BusAI

			if bus_ai.get_current_state() == BusAI.BusState.RETURNING_TO_DEPOT:
				_score_manager.update_score(ChallengeEnums.ScoreReason.BUS_INVALID_STATE_FOR_ACTION)
				return

			if bus_ai.get_passenger_counts().current_passengers > 0:
				_score_manager.update_score(ChallengeEnums.ScoreReason.BUS_CHANGED_STATE_WITH_PASSENGERS_ONBOARD)
				return

			bus_ai.return_to_depot()
		RLEnums.BusStateRequest.RESERVE:
			if bus == null:
				var is_articulated = _is_bus_articulated(bus_idx)
				var bus_type = RLEnums.BusType.ARTICULATED if is_articulated else RLEnums.BusType.REGULAR
				var depot = _get_depot_with_available_buses(is_articulated)

				if depot == null:
					push_error("[Unexpected state] No depot with available buses of type %s for deployment action" % bus_type)
					breakpoint
					return

				var new_bus = depot.try_spawn(is_articulated)

				if new_bus == null:
					push_error("[Unexpected state] Failed to spawn bus of type %s from depot %d during deployment action" % [bus_type, depot.id])
					breakpoint
					return

				new_bus.destroyed.connect(_del_bus_with_idx)
				_buses[bus_idx] = new_bus
				bus = new_bus

			var bus_ai = bus.ai as BusAI

			if bus_ai.get_passenger_counts().current_passengers > 0:
				_score_manager.update_score(ChallengeEnums.ScoreReason.BUS_CHANGED_STATE_WITH_PASSENGERS_ONBOARD)
				return

			bus_ai.unassign_brigade()

			var target_terminal_id = _terminals[reserve_term_idx].terminal_id
			var is_target_terminal_same_as_current = bus_ai.get_target_terminal() != null and bus_ai.get_target_terminal().terminal_id == target_terminal_id

			if is_target_terminal_same_as_current:
				_score_manager.update_score(ChallengeEnums.ScoreReason.BUS_ALREADY_IN_RESERVE_SAME_TERMINAL)
				return

			bus_ai.drive_to_terminal(target_terminal_id)


func _assign_to_brigade_action(bus_idx: int, brigade_idx: int) -> void:
	print(
		"Assigning bus #%d (articulated=%s) to brigade #%d (%s)" % [
			bus_idx,
			_is_bus_articulated(bus_idx),
			brigade_idx,
			_brigades[brigade_idx].get_identifier(),
		],
	)
	var bus = _buses[bus_idx] as Vehicle

	if bus == null:
		_score_manager.update_score(ChallengeEnums.ScoreReason.BUS_INVALID_STATE_FOR_ACTION)
		return

	var bus_ai = bus.ai as BusAI

	if bus_ai.get_passenger_counts().current_passengers > 0:
		_score_manager.update_score(ChallengeEnums.ScoreReason.BUS_CHANGED_STATE_WITH_PASSENGERS_ONBOARD)
		return

	var brigade = _brigades[brigade_idx] as Brigade

	bus_ai.assign_brigade(brigade.id)


func _get_depot_with_available_buses(is_articulated: bool) -> Depot:
	for depot in _depots as Array[Depot]:
		if depot.get_current_bus_count(is_articulated) > 0:
			return depot
	return null


func _del_bus_with_idx(bus_id: int) -> void:
	var bus_idx = _buses.find_custom(
		func(bus) -> bool:
			return bus != null and bus.id == bus_id,
	)

	if bus_idx == -1:
		push_error("Trying to delete bus with ID %d that is not tracked in controller's bus list" % bus_id)
		return
	_buses[bus_idx] = null
