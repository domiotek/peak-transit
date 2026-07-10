extends "res://addons/godot_rl_agents/controller/ai_controller_2d.gd"

class_name ChallengeAiController

const BRIGADE_DEMAND_HORIZON_STOPS: int = 3
const BRIGADE_DEMAND_HORIZON_MINUTES: float = 15.0

var game_manager: GameManager = GDInjector.inject("GameManager") as GameManager
var config_manager: ConfigManager = GDInjector.inject("ConfigManager") as ConfigManager
var transport_manager: TransportManager = GDInjector.inject("TransportManager") as TransportManager
var network_manager: NetworkManager = GDInjector.inject("NetworkManager") as NetworkManager
var vehicle_manager: VehicleManager = GDInjector.inject("VehicleManager") as VehicleManager
var buildings_manager: BuildingsManager = GDInjector.inject("BuildingsManager") as BuildingsManager

var _logger: GDLogger = GDLogger.DummyGDLogger.new()

var _depots: Array = []
var _terminals: Array = []
var _brigades: Array = []
var _buses_available: Dictionary = { }
var _buses: Array = []

var _technical_reset_done: bool = false

var _score_manager: ScoreManager

var action_log_path: String = ""
var _action_log_file: FileAccess = null
var _action_log_step: int = 0


func setup() -> void:
	if config_manager.UseRlLogger:
		_logger = GDLogger.new("challenge_rl_train.log", true, true)

	_depots = transport_manager.get_depots()
	_terminals = transport_manager.get_terminals()
	_brigades = transport_manager.brigades.get_all()
	_buses_available = TransportHelper.get_total_bus_availability(_depots)

	_buses.resize(_buses_available["regular"] + _buses_available["articulated"])
	_buses.fill(null)

	_score_manager = game_manager.get_game_controller().score_manager()
	reset_after = RLConstants.RL_RESET_AFTER_STEPS

	game_manager.clock.time_changed.connect(Callable(self, "_time_changed"))
	vehicle_manager.vehicle_destroyed.connect(Callable(self, "_on_vehicle_destroyed"))


func gather_features() -> Dictionary:
	var time_of_day = game_manager.clock.get_time().to_time_of_day().to_sin_cos()
	var brigades = transport_manager.brigades.get_all()

	var bus_features = _gather_bus_features(_buses)
	var brigade_features = _gather_brigade_features(brigades)
	var terminal_features = _gather_terminal_features(_terminals)

	var features = {
		"time_of_day": time_of_day,
	}
	for key in bus_features.keys():
		features[key] = bus_features[key]
	for key in brigade_features.keys():
		features[key] = brigade_features[key]
	for key in terminal_features.keys():
		features[key] = terminal_features[key]
	return features


func get_obs() -> Dictionary:
	_logger.log("getting obs at time: " + game_manager.clock.get_time().to_time_of_day().format())
	var features = gather_features()
	_logger.log("features: " + str(features))

	return { "obs": _flatten_features(features) }


func get_reward() -> float:
	var regular_upkeep_count = 0
	var articulated_upkeep_count = 0

	for bus_idx in range(_buses.size()):
		var bus = _buses[bus_idx] as Vehicle

		if bus == null:
			continue

		if _is_bus_articulated(bus_idx):
			articulated_upkeep_count += 1
		else:
			regular_upkeep_count += 1

	if regular_upkeep_count > 0:
		_score_manager.update_score(ChallengeEnums.ScoreReason.BUS_REGULAR_UPKEEP_COST, regular_upkeep_count)

	if articulated_upkeep_count > 0:
		_score_manager.update_score(ChallengeEnums.ScoreReason.BUS_ARTICULATED_UPKEEP_COST, articulated_upkeep_count)

	var unserved_brigade_count = 0
	for brigade_idx in range(_brigades.size()):
		var brigade = _brigades[brigade_idx] as Brigade

		var ongoing_trip_info = BrigadeHelper.get_ongoing_trip(brigade, game_manager.clock.get_time().to_time_of_day())
		if ongoing_trip_info["ongoing_trip"] == null:
			continue

		if ongoing_trip_info["assigned_bus"] == null:
			unserved_brigade_count += 1

	if unserved_brigade_count > 0:
		_score_manager.update_score(ChallengeEnums.ScoreReason.UNSERVED_BRIGADE, unserved_brigade_count)

	_logger.log("reward: " + str(_score_manager.get_score()))
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


func get_action_mask() -> Array:
	var mask: Array = []
	mask.append(true) # NO_OP

	for bus_idx in range(_buses.size()):
		mask.append(_is_depot_action_valid(bus_idx))
		for reserve_term_idx in range(_terminals.size()):
			mask.append(_is_reserve_action_valid(bus_idx, reserve_term_idx))

	for bus_idx in range(_buses.size()):
		for brigade_idx in range(_brigades.size()):
			mask.append(_is_assign_to_brigade_action_valid(bus_idx, brigade_idx))

	return mask


## Decodes a flattened action index (argmax over the ONNX output) back into the
## composite action dictionary. Mirrors the enumeration in get_action_mask above and
## MaskedLegalActionWrapper._build_legal_actions on the Python side, so index i here
## denotes the same action it did during training.
func decode_flat_action(index: int) -> Dictionary:
	var n := _buses.size()
	var t := _terminals.size()
	var k := _brigades.size()

	var action := {
		"command": RLEnums.ActionType.NO_OP,
		"bus_idx": 0,
		"state": RLEnums.BusStateRequest.DEPOT,
		"brigade_idx": 0,
		"reserve_term_idx": 0,
	}

	if index <= 0:
		return action # NO_OP

	var state_block := n * (1 + t)
	if index <= state_block:
		var offset := index - 1
		action["command"] = RLEnums.ActionType.SET_STATE
		action["bus_idx"] = offset / (1 + t)
		var slot := offset % (1 + t)
		if slot == 0:
			action["state"] = RLEnums.BusStateRequest.DEPOT
		else:
			action["state"] = RLEnums.BusStateRequest.RESERVE
			action["reserve_term_idx"] = slot - 1
	else:
		var offset := index - 1 - state_block
		action["command"] = RLEnums.ActionType.ASSIGN_TO_BRIGADE
		action["bus_idx"] = offset / k
		action["brigade_idx"] = offset % k

	return action


## Picks an action from a flat ONNX output vector (Maskable PPO logits or DQN Q-values).
## When apply_mask is true, illegal actions are excluded first, reproducing the masking
## Maskable PPO relied on during training. DQN runs with apply_mask false, matching how
## it was trained.
## When sample is false (default), picks the argmax (greedy/deterministic). When sample
## is true, treats the legal logits as unnormalized log-probabilities and draws from the
## resulting categorical distribution (softmax + weighted random pick) — this mirrors
## MaskableCategorical.sample() in sb3-contrib, i.e. the actual stochastic policy PPO was
## trained and evaluated with, as opposed to a point estimate over it. Meaningless for
## DQN (Q-values aren't log-probabilities), so leave sample false there.
func pick_flat_action(logits: Array, apply_mask: bool, sample: bool = false) -> Dictionary:
	var mask: Array = get_action_mask() if apply_mask else []

	var legal_indices: Array = []
	for i in range(logits.size()):
		if apply_mask and i < mask.size() and not mask[i]:
			continue
		legal_indices.append(i)

	if legal_indices.is_empty():
		return decode_flat_action(0) # everything masked out; fall back to NO_OP

	if not sample:
		var best_idx: int = legal_indices[0]
		var best_val: float = logits[best_idx]
		for i in legal_indices:
			var value: float = logits[i]
			if value > best_val:
				best_val = value
				best_idx = i
		return decode_flat_action(best_idx)

	var max_logit: float = -INF
	for i in legal_indices:
		max_logit = max(max_logit, logits[i])

	var exp_values: Array = []
	var sum_exp: float = 0.0
	for i in legal_indices:
		var e: float = exp(logits[i] - max_logit)
		exp_values.append(e)
		sum_exp += e

	var roll: float = randf() * sum_exp
	var cumulative: float = 0.0
	var chosen_idx: int = legal_indices[legal_indices.size() - 1] # guards float rounding
	for j in range(legal_indices.size()):
		cumulative += exp_values[j]
		if roll <= cumulative:
			chosen_idx = legal_indices[j]
			break

	return decode_flat_action(chosen_idx)


func set_action(action) -> void:
	_score_manager.push_action(action)
	_maybe_log_action(action)

	match action["command"] as int:
		RLEnums.ActionType.NO_OP:
			_logger.log("Received NO_OP action, doing nothing")
			return
		RLEnums.ActionType.SET_STATE:
			_set_state_action(action["bus_idx"], action["state"], action["reserve_term_idx"])
		RLEnums.ActionType.ASSIGN_TO_BRIGADE:
			_assign_to_brigade_action(action["bus_idx"], action["brigade_idx"])


func reset():
	super.reset()
	vehicle_manager.clear_all_vehicles()
	buildings_manager.reset_spawner_buildings()
	network_manager.reset_network()
	transport_manager.reset_state()
	game_manager.clock.reset(true)

	if _technical_reset_done:
		_score_manager.end_episode()
		_buses.fill(null)
	else:
		_technical_reset_done = true


func _safe_ratio(numerator: float, denominator: float) -> float:
	return numerator / max(denominator, 1.0)


func _is_bus_delay_valid(bus: Vehicle, bus_state: int) -> bool:
	if bus == null:
		return false

	var bus_ai = bus.ai as BusAI

	if bus_ai == null:
		return false

	return bus_state == RLEnums.BusState.EN_ROUTE


func _gather_bus_features(buses: Array) -> Dictionary:
	var features = {
		"bus_state_onehot": [],
		"bus_type_onehot": [],
		"bus_utilization": [],
		"bus_exists": [],
		"bus_load_ratio": [],
		"bus_load_valid": [],
		"bus_delay": [],
		"bus_delay_valid": [],
	}

	var current_bus_counts = TransportHelper.get_total_deployed_buses(_depots)

	features["bus_utilization"] = [
		_safe_ratio(current_bus_counts["regular"], _buses_available["regular"]),
		_safe_ratio(current_bus_counts["articulated"], _buses_available["articulated"]),
	]

	for bus_idx in range(buses.size()):
		var bus = buses[bus_idx] as Vehicle
		var bus_type = RLEnums.BusType.ARTICULATED if _is_bus_articulated(bus_idx) else RLEnums.BusType.REGULAR
		features["bus_type_onehot"].append_array(_onehot_encode(bus_type, RLEnums.BusType.size()))

		if bus == null:
			features["bus_exists"].append(0.0)
			features["bus_state_onehot"].append_array(_onehot_encode(RLEnums.BusState.AT_DEPOT, RLEnums.BusState.size()))
			features["bus_load_ratio"].append(0.0)
			features["bus_load_valid"].append(0.0)
			features["bus_delay"].append(0.0)
			features["bus_delay_valid"].append(0.0)
			continue

		features["bus_exists"].append(1.0)

		var bus_ai = bus.ai as BusAI
		var bus_state = _get_bus_state(bus)
		features["bus_state_onehot"].append_array(_onehot_encode(bus_state, RLEnums.BusState.size()))

		if bus_ai != null:
			var passenger_stats = bus_ai.get_passenger_counts()
			features["bus_load_ratio"].append(
				_safe_ratio(passenger_stats.current_passengers, passenger_stats.max_passengers)
			)
			features["bus_load_valid"].append(1.0)
		else:
			features["bus_load_ratio"].append(0.0)
			features["bus_load_valid"].append(0.0)

		if _is_bus_delay_valid(bus, bus_state):
			var time_diff = bus_ai.get_time_difference_to_schedule(game_manager.clock.get_time().to_time_of_day())
			features["bus_delay"].append(time_diff / 1440.0)
			features["bus_delay_valid"].append(1.0)
		else:
			features["bus_delay"].append(0.0)
			features["bus_delay_valid"].append(0.0)

	return features


func _gather_brigade_features(brigades: Array) -> Dictionary:
	var features = {
		"brigade_bus_count": [],
		"brigade_unserved_demand": [],
		"brigade_immediate_pressure_std": [],
		"brigade_zone_pressure_std": [],
		"brigade_zone_pressure_artic": [],
		"brigade_traffic_intensity": [],
		"brigade_time_to_next_departure": [],
		"brigade_gap_ahead_norm": [],
		"brigade_active": [],
		"brigade_has_assigned_bus": [],
		"brigade_gap_valid": [],
	}

	var total_buses = _buses_available["regular"] + _buses_available["articulated"]
	var current_time = game_manager.clock.get_time().to_time_of_day()

	for brigade in brigades as Array[Brigade]:
		features["brigade_bus_count"].append(_safe_ratio(brigade.get_vehicle_count(), total_buses))

		var next_trip = brigade.get_next_trip(current_time)
		var time_to_next_departure = 0.0
		if next_trip != null:
			time_to_next_departure = next_trip.get_time_till_departure() / 1440.0
		features["brigade_time_to_next_departure"].append(time_to_next_departure)

		var ongoing_trip = BrigadeHelper.get_ongoing_trip(brigade, current_time)

		if ongoing_trip["ongoing_trip"] == null:
			features["brigade_active"].append(0.0)
			features["brigade_has_assigned_bus"].append(0.0)
			features["brigade_unserved_demand"].append(0.0)
			features["brigade_immediate_pressure_std"].append(0.0)
			features["brigade_zone_pressure_std"].append(0.0)
			features["brigade_zone_pressure_artic"].append(0.0)
			features["brigade_traffic_intensity"].append(0.0)
			features["brigade_gap_ahead_norm"].append(0.0)
			features["brigade_gap_valid"].append(0.0)
			continue

		features["brigade_active"].append(1.0)

		var waiting_passengers_ahead = BrigadeHelper.get_waiting_passengers(
			brigade,
			ongoing_trip["ongoing_trip"],
			ongoing_trip["next_stop_idx"]
		)

		var serving_vehicle = ongoing_trip["assigned_bus"] as Vehicle
		var bus_ai = serving_vehicle.ai as BusAI if serving_vehicle != null else null
		features["brigade_has_assigned_bus"].append(1.0 if bus_ai != null else 0.0)

		var unserved_demand = _safe_ratio(
			waiting_passengers_ahead["own_waiting"],
			waiting_passengers_ahead["max_waiting"]
		)
		features["brigade_unserved_demand"].append(unserved_demand)

		var demand_pressure = _estimate_brigade_demand_pressure(
			brigade,
			ongoing_trip["ongoing_trip"],
			ongoing_trip["next_stop_idx"],
			current_time,
			waiting_passengers_ahead
		)

		features["brigade_immediate_pressure_std"].append(demand_pressure["immediate_pressure_std"])
		features["brigade_zone_pressure_std"].append(demand_pressure["zone_pressure_std"])
		features["brigade_zone_pressure_artic"].append(demand_pressure["zone_pressure_artic"])

		var transport_line = transport_manager.get_line(brigade.line_id) as TransportLine
		features["brigade_traffic_intensity"].append(
			BrigadeHelper.get_average_traffic(
				network_manager,
				transport_line,
				ongoing_trip["ongoing_trip"],
				ongoing_trip["next_stop_idx"],
				ongoing_trip["assigned_bus"]
			)
		)

		var departure_time = ongoing_trip["ongoing_trip"].get_departure_terminal().get_departure_time_for_line(brigade.line_id)

		if departure_time == null:
			features["brigade_gap_ahead_norm"].append(0.0)
			features["brigade_gap_valid"].append(0.0)
			continue

		features["brigade_gap_valid"].append(1.0)

		var gap_ahead = current_time.to_minutes() - departure_time.to_minutes()
		if gap_ahead < 0:
			gap_ahead += 1440

		var normalization = 2.0 * transport_line.get_frequency_minutes()
		features["brigade_gap_ahead_norm"].append(clamp(gap_ahead / normalization, 0.0, 1.0))

	return features


func _estimate_brigade_demand_pressure(
		brigade: Brigade,
		trip: BrigadeTrip,
		next_stop_idx: int,
		current_time: TimeOfDay,
		waiting_passengers_ahead: Dictionary
) -> Dictionary:
	if next_stop_idx < 0:
		return {
			"immediate_pressure_std": 0.0,
			"zone_pressure_std": 0.0,
			"zone_pressure_artic": 0.0,
		}

	var line = transport_manager.get_line(brigade.line_id) as TransportLine

	if line == null:
		return {
			"immediate_pressure_std": 0.0,
			"zone_pressure_std": 0.0,
			"zone_pressure_artic": 0.0,
		}

	var stops = trip.get_stops()
	if stops.size() == 0:
		return {
			"immediate_pressure_std": 0.0,
			"zone_pressure_std": 0.0,
			"zone_pressure_artic": 0.0,
		}

	var start_idx = clamp(next_stop_idx, 0, stops.size() - 1)
	var end_idx = min(stops.size(), start_idx + BRIGADE_DEMAND_HORIZON_STOPS)

	var expected_zone_arrivals = 0.0
	var expected_immediate_arrivals = 0.0

	for stop_idx in range(start_idx, end_idx):
		var line_stop = stops[stop_idx] as LineStop
		if line_stop == null:
			continue

		var stop_selection = line_stop.get_stop_selection() as StopSelection
		if stop_selection == null:
			continue

		var time_to_relief = _get_minutes_to_next_departure(stop_selection, line, current_time)
		var horizon_minutes = min(time_to_relief, BRIGADE_DEMAND_HORIZON_MINUTES)
		var expected_arrivals = _estimate_expected_arrivals(stop_selection, horizon_minutes)

		expected_zone_arrivals += expected_arrivals

		if stop_idx == start_idx:
			expected_immediate_arrivals = expected_arrivals

	var immediate_predicted_boardings = waiting_passengers_ahead["own_waiting_next_stop"] + expected_immediate_arrivals
	var zone_predicted_boardings = waiting_passengers_ahead["own_waiting"] + expected_zone_arrivals

	return {
		"immediate_pressure_std": _capacity_pressure(immediate_predicted_boardings, TransportConstants.BUS_MAX_CAPACITY),
		"zone_pressure_std": _capacity_pressure(zone_predicted_boardings, TransportConstants.BUS_MAX_CAPACITY),
		"zone_pressure_artic": _capacity_pressure(zone_predicted_boardings, TransportConstants.ARTICULATED_BUS_MAX_CAPACITY),
	}


func _capacity_pressure(predicted_demand: float, capacity: float) -> float:
	if capacity <= 0.0:
		return 0.0

	return clamp((predicted_demand - capacity) / capacity, -1.0, 2.0)


func _estimate_expected_arrivals(stop_selection: StopSelection, horizon_minutes: float) -> float:
	if horizon_minutes <= 0.0:
		return 0.0

	var passenger_spawner = stop_selection.get_passengers()
	if passenger_spawner == null:
		return 0.0

	var current_clock_time = game_manager.clock.get_time()
	var spawn_chance = passenger_spawner.get_effective_spawn_chance(current_clock_time) / 100.0
	var spawn_range = passenger_spawner.get_effective_passenger_spawn_range(current_clock_time)

	if spawn_range.size() < 2:
		return 0.0

	var average_spawn_size = (float(spawn_range[0]) + float(spawn_range[1])) * 0.5
	var spawn_interval_minutes = TransportConstants.PASSENGER_SPAWN_INTERVAL_DELTA / 60.0
	var spawn_rolls = horizon_minutes / max(spawn_interval_minutes, 0.0001)

	# Approximate line share when a stop is served by multiple lines.
	var stop_lines = stop_selection.get_lines()
	var per_line_share = 1.0 / max(float(stop_lines.size()), 1.0)

	return spawn_rolls * spawn_chance * average_spawn_size * per_line_share


func _get_minutes_to_next_departure(stop_selection: StopSelection, line: TransportLine, current_time: TimeOfDay) -> float:
	var departures = stop_selection.get_departures(line, current_time)

	if departures.size() == 0:
		return BRIGADE_DEMAND_HORIZON_MINUTES

	var next_departure = departures[0] as StopDeparture

	if next_departure == null:
		return BRIGADE_DEMAND_HORIZON_MINUTES

	var delta = next_departure.departure_time.to_minutes() - current_time.to_minutes()
	if delta < 0:
		delta += 1440

	return float(delta)



func _gather_terminal_features(terminals: Array) -> Dictionary:
	var features = {
		"terminal_bus_count": [],
	}

	for terminal in terminals as Array[Terminal]:
		features["terminal_bus_count"].append(terminal.get_current_bus_count() / float(_buses_available["regular"] + _buses_available["articulated"]))

	return features


func _get_bus_state(bus: Vehicle) -> RLEnums.BusState:
	var bus_ai = bus.ai as BusAI

	var state = bus_ai.get_current_state()

	match state:
		BusAI.BusState.IDLE:
			return RLEnums.BusState.IN_RESERVE
		BusAI.BusState.CONFUSED:
			push_error("Bus ID %d is in CONFUSED state. Resetting environment." % bus.id)
			_reset_environment()
			return RLEnums.BusState.IN_RESERVE
		BusAI.BusState.RETURNING_TO_DEPOT, BusAI.BusState.TRANSFERING_TO_TERMINAL, BusAI.BusState.TRANSFERING_TO_STOP:
			return RLEnums.BusState.TRANSFER
		BusAI.BusState.EN_ROUTE, BusAI.BusState.BOARDING_PASSENGERS, BusAI.BusState.SYNCING_WITH_SCHEDULE:
			return RLEnums.BusState.EN_ROUTE
		BusAI.BusState.WAIT_BETWEEN_TRIPS:
			return RLEnums.BusState.IN_RESERVE if bus_ai.get_brigade() == null else RLEnums.BusState.WAITING_FOR_TRIP
		_:
			return RLEnums.BusState.AT_DEPOT


func _maybe_log_action(action) -> void:
	if action_log_path == "":
		return

	if _action_log_file == null:
		_action_log_file = FileAccess.open(action_log_path, FileAccess.WRITE)
		if _action_log_file == null:
			push_error("Could not open action log at %s; disabling logging." % action_log_path)
			action_log_path = ""
			return
		_action_log_file.store_line("step,time,command,bus_idx,state,brigade_idx,reserve_term_idx,active_buses,unserved_brigades")

	var command_names := RLEnums.ActionType.keys()
	var state_names := RLEnums.BusStateRequest.keys()
	var command_idx: int = action["command"]
	var state_idx: int = action["state"]

	_action_log_file.store_line("%d,%s,%s,%d,%s,%d,%d,%d,%d" % [
		_action_log_step,
		game_manager.clock.get_time().to_time_of_day().format(),
		command_names[command_idx] if command_idx < command_names.size() else str(command_idx),
		action["bus_idx"],
		state_names[state_idx] if state_idx < state_names.size() else str(state_idx),
		action["brigade_idx"],
		action["reserve_term_idx"],
		_count_active_buses(),
		_count_unserved_brigades(),
	])
	_action_log_file.flush()
	_action_log_step += 1


func _count_active_buses() -> int:
	var count := 0
	for bus in _buses:
		if bus != null:
			count += 1
	return count


func _count_unserved_brigades() -> int:
	var count := 0
	var now = game_manager.clock.get_time().to_time_of_day()
	for brigade in _brigades:
		var ongoing_trip_info = BrigadeHelper.get_ongoing_trip(brigade, now)
		if ongoing_trip_info["ongoing_trip"] == null:
			continue
		if ongoing_trip_info["assigned_bus"] == null:
			count += 1
	return count


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


func _is_depot_action_valid(bus_idx: int) -> bool:
	var bus = _buses[bus_idx] as Vehicle
	if bus == null:
		return false

	var bus_ai = bus.ai as BusAI
	if bus_ai == null:
		return false

	if bus_ai.get_current_state() == BusAI.BusState.RETURNING_TO_DEPOT:
		return false

	return bus_ai.get_passenger_counts().current_passengers == 0


func _is_reserve_action_valid(bus_idx: int, reserve_term_idx: int) -> bool:
	if reserve_term_idx < 0 or reserve_term_idx >= _terminals.size():
		return false

	var bus = _buses[bus_idx] as Vehicle
	if bus == null:
		return _get_depot_with_available_buses(_is_bus_articulated(bus_idx)) != null

	var bus_ai = bus.ai as BusAI
	if bus_ai == null:
		return false

	return bus_ai.get_passenger_counts().current_passengers == 0


func _is_assign_to_brigade_action_valid(bus_idx: int, brigade_idx: int) -> bool:
	if brigade_idx < 0 or brigade_idx >= _brigades.size():
		return false

	var bus = _buses[bus_idx] as Vehicle
	if bus == null:
		return false

	var bus_ai = bus.ai as BusAI
	if bus_ai == null:
		return false

	return bus_ai.get_passenger_counts().current_passengers == 0


func _set_state_action(bus_idx: int, state: RLEnums.BusStateRequest, reserve_term_idx: int) -> void:
	var bus = _buses[bus_idx] as Vehicle

	_logger.log("Setting state of bus index %d to state %d with reserve terminal index %d" % [bus_idx, state, reserve_term_idx])

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

			bus_ai.drive_to_terminal(target_terminal_id)


func _assign_to_brigade_action(bus_idx: int, brigade_idx: int) -> void:
	_logger.log(
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


func _on_vehicle_destroyed(vehicle_id: int, vehicle_type: VehicleManager.VehicleType) -> void:
	if not _technical_reset_done:
		return

	if vehicle_type != VehicleManager.VehicleType.BUS and vehicle_type != VehicleManager.VehicleType.ARTICULATED_BUS:
		return

	_del_bus_with_idx(vehicle_id)


func _time_changed(new_time: ClockTime) -> void:
	var minutes_in_day = new_time.to_time_of_day().to_minutes()

	if minutes_in_day == 0 && not get_done(): # is midnight
		_logger.log("New day reached, ending episode and resetting environment.")
		_reset_environment()

	if minutes_in_day % 60 == 0: # every hour
		_logger.flush()


func _reset_environment() -> void:
	done = true
	reset()
