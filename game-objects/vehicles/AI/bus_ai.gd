extends RefCounted

class_name BusAI

enum BusState {
	IDLE,
	CONFUSED,
	RETURNING_TO_DEPOT,
	TRANSFERING_TO_TERMINAL,
	EN_ROUTE,
	BOARDING_PASSENGERS,
	SYNCING_WITH_SCHEDULE,
	WAIT_BETWEEN_TRIPS,
}

enum ActionBusState {
	EN_ROUTE,
	RELOCATING,
}

var _vehicle: Vehicle
var _vehicle_manager: VehicleManager
var _transport_manager: TransportManager
var _game_manager: GameManager
var _state: BusState = BusState.IDLE
var _is_at_depot: bool = true
var _is_at_terminal: bool = false

var _origin_depot: Depot = null
var _current_terminal: Terminal = null
var _target_terminal: Terminal = null
var _brigade: Brigade = null
var _brigade_trip_idx: int = -1
var _brigade_trip_current_stop_idx: int = -1

var _is_leaving_building: bool = false
var _is_entering_building: bool = false
var _has_navigation_set: bool = true
var _current_passengers: int = 0
var _max_passengers: int = 0

var _boarding_timer: float = 0.0


func bind(vehicle: Vehicle) -> void:
	vehicle.driver.set_ai(self)
	vehicle.ai = self
	_vehicle = vehicle
	_vehicle_manager = GDInjector.inject("VehicleManager") as VehicleManager
	_transport_manager = GDInjector.inject("TransportManager") as TransportManager
	_game_manager = GDInjector.inject("GameManager") as GameManager


func get_constants() -> Dictionary:
	return {
		"ACCELERATION": 25.0,
		"DEFAULT_BRAKING": 50.0,
		"EMERGENCY_BRAKING": 150.0,
		"CLOSE_BRAKING": 60.0,
		"CLOSE_BRAKING_LOW_SPEED_THRESHOLD": 30.0,
		"MEDIUM_BRAKING": 120.0,
		"LIGHT_BRAKING": 80.0,
		"MAX_SPEED": 80.0,
		"INTERSECTION_SLOWDOWN_THRESHOLD": 300.0,
		"INTERSECTION_SLOWDOWN": 50.0,
		"BUILDING_ENTRY_SPEED": 40.0,
		"EMERGENCY_STOP_SPEED_MODIFIER": 0.5,
		"MEDIUM_CASTER_SPEED_MODIFIER": 0.3,
		"MEDIUM_CASTER_MIN_SPEED": 1,
		"LONG_CASTER_SPEED_MODIFIER": 0.4,
		"LONG_CASTER_MIN_SPEED": 5,
		"TURN_CRAWL_SPEED": 10.0,
		"REROUTE_THRESHOLD": 0.0,
		"REROUTE_CHANCE": 0,
	}


func get_state_name() -> String:
	match _state:
		BusState.IDLE:
			return "Idle"
		BusState.RETURNING_TO_DEPOT:
			return "Returning to Depot"
		BusState.TRANSFERING_TO_TERMINAL:
			return "Transfering to Terminal"
		BusState.EN_ROUTE:
			return "En Route"
		BusState.WAIT_BETWEEN_TRIPS:
			return "Wating for next trip" if _brigade != null else "Idle"
		BusState.BOARDING_PASSENGERS:
			return "Exchanging Passengers"
		BusState.SYNCING_WITH_SCHEDULE:
			return "Waiting to depart"
		BusState.CONFUSED:
			return "Confused"
		_:
			return "Unknown"


func get_passenger_counts() -> Dictionary:
	return {
		"current_passengers": _current_passengers,
		"max_passengers": _max_passengers,
	}


func get_brigade() -> Brigade:
	return _brigade


func get_current_trip() -> BrigadeTrip:
	if _brigade == null or _brigade_trip_idx == -1:
		return null

	return _brigade.get_trip(_brigade_trip_idx)


func get_next_stop() -> LineStop:
	var current_trip = get_current_trip()
	if current_trip == null:
		return null

	return current_trip.get_stop(_brigade_trip_current_stop_idx)


func get_current_terminal() -> Terminal:
	return _current_terminal


func assign_brigade(brigade_id: int) -> void:
	var brigade: Brigade = _transport_manager.brigades.get_by_id(brigade_id)

	if _brigade != null:
		_brigade.unassign_vehicle(_vehicle.id)

	_brigade = brigade
	var trip_index = brigade.assign_vehicle(_vehicle.id)
	_brigade_trip_idx = trip_index
	_join_trip()


func unassign_brigade() -> void:
	if _brigade:
		_brigade.unassign_vehicle(_vehicle.id)
		_brigade = null
		return


func set_current_trip(trip_idx: int) -> void:
	if _brigade == null:
		return

	if trip_idx < 0 or _brigade.get_trip_count() <= trip_idx:
		return

	if not _brigade.switch_trip(_vehicle.id, trip_idx):
		return

	_brigade_trip_idx = trip_idx

	_join_trip()


func set_origin_depot(depot: Depot) -> void:
	_origin_depot = depot


func mark_leaving_terminal() -> void:
	_is_leaving_building = true
	_is_at_terminal = false


func return_to_depot() -> void:
	if _state == BusState.RETURNING_TO_DEPOT:
		return

	if not _origin_depot or _is_at_depot:
		_remove_vehicle()
		return

	match _state:
		_:
			if _is_at_terminal:
				_is_leaving_building = true
			else:
				_drive_to_depot()

	_state = BusState.RETURNING_TO_DEPOT
	unassign_brigade()


func drive_to_terminal(id: int) -> void:
	var terminal_building = _transport_manager.get_terminal(id)
	if not terminal_building:
		return

	_state = BusState.TRANSFERING_TO_TERMINAL

	if terminal_building == _current_terminal:
		return

	_target_terminal = terminal_building

	_is_entering_building = false
	_is_leaving_building = _is_at_depot or (_is_at_terminal and _target_terminal != _current_terminal)

	if not _is_leaving_building:
		_drive_to_terminal()


func process(delta: float) -> void:
	if _state == BusState.IDLE or _state == BusState.CONFUSED:
		return

	var current_trip = get_current_trip()

	match _state:
		BusState.WAIT_BETWEEN_TRIPS:
			if not current_trip:
				return

			if _is_at_terminal and _handle_at_terminal(current_trip, delta):
				return
		BusState.RETURNING_TO_DEPOT:
			if _has_navigation_set:
				return

			if _is_leaving_building:
				if _is_at_terminal:
					var result = _current_terminal.leave_terminal(_vehicle.id)

					match result["error"]:
						null:
							_vehicle.navigator.set_custom_step(result["path"], SimulationConstants.MAX_INSIDE_BUILDING_SPEED)
							_has_navigation_set = true
							return
						TerminalTrackState.TrackSearchError.ALREADY_ON_TARGET:
							_drive_to_depot()
							_current_terminal.notify_vehicle_left_terminal(_vehicle.id)
							_current_terminal = null
							_is_at_terminal = false
							_is_leaving_building = false
							_has_navigation_set = true
							return
						TerminalTrackState.TrackSearchError.TRACK_IN_USE:
							# Wait and try again next frame
							return

			if _is_entering_building:
				var path = _origin_depot.try_enter(_vehicle)
				if path:
					_vehicle.navigator.set_custom_step(path, SimulationConstants.MAX_INSIDE_BUILDING_SPEED)
					_has_navigation_set = true
					_is_at_depot = true
					_is_entering_building = false
					return

			_remove_vehicle()
			return
		BusState.TRANSFERING_TO_TERMINAL:
			if _has_navigation_set:
				return

			if _is_leaving_building and _handle_leaving_building():
				return

			if _is_entering_building and _handle_entering_terminal():
				return

			if _is_at_terminal and _handle_at_terminal(current_trip, delta):
				return
		BusState.EN_ROUTE:
			if _is_at_terminal and _has_navigation_set:
				return

			if _is_leaving_building and not _has_navigation_set and _handle_leaving_building():
				return

			if _is_entering_building and not _has_navigation_set and _handle_entering_terminal():
				return

			if _is_at_terminal and _handle_at_terminal(current_trip, delta):
				return

			if _has_navigation_set:
				return
		BusState.BOARDING_PASSENGERS, BusState.SYNCING_WITH_SCHEDULE:
			_handle_stop(current_trip, delta)
			return

	_state = BusState.CONFUSED


func on_trip_finished(completed: bool, _trip_data: Dictionary) -> void:
	if not completed:
		_remove_vehicle()
		return
	_has_navigation_set = false

	if not _is_at_depot and not _is_at_terminal:
		_is_entering_building = true


func can_drive() -> bool:
	return _state != BusState.IDLE and _state != BusState.CONFUSED


func _drive_to_depot() -> void:
	var current_step = _vehicle.navigator.get_current_step()

	if current_step["type"] == Navigator.StepType.BUILDING:
		return # TODO try to resolve while going in or out of building

	if not _is_at_terminal:
		var start_node_data = _get_start_node_of_network_location(current_step)
		var start_node = start_node_data[0]
		var start_endpoint = start_node_data[1]

		if start_node == -1:
			_remove_vehicle()
			return

		_vehicle.init_trip_to_building(start_node, _origin_depot, start_endpoint)

	_vehicle.init_trip(_target_terminal, _origin_depot)


func _drive_to_terminal() -> void:
	var current_step = _vehicle.navigator.get_current_step()
	var current_trip = get_current_trip()

	if current_step["type"] == Navigator.StepType.BUILDING:
		return # TODO try to resolve while going in or out of building

	if not _is_at_depot and not _is_at_terminal:
		var start_node_data = _get_start_node_of_network_location(current_step)
		var start_node = start_node_data[0]
		var start_endpoint = start_node_data[1]

		if start_node == -1:
			_remove_vehicle()
			return

		_vehicle.init_trip_to_building(start_node, _target_terminal, start_endpoint)
		return

	var source_building = _origin_depot as BaseBuilding if _is_at_depot else _current_terminal as BaseBuilding

	if current_trip and _state == BusState.EN_ROUTE:
		_vehicle.init_trip_with_path(current_trip.get_path(), source_building, _target_terminal)
		for line_stop in current_trip.get_stops():
			if line_stop.is_terminal:
				continue
			var stop = _transport_manager.get_stop(line_stop.target_id)
			var endpoint_id = stop.get_lane().get_endpoint_by_type(true).Id

			_vehicle.navigator.set_node_location_trigger(stop.get_incoming_node_id(), endpoint_id, Callable(self, "_on_location_trigger_reached"))

	else:
		_vehicle.init_trip(source_building, _target_terminal)


func _join_trip() -> void:
	var current_trip = get_current_trip()
	if not current_trip:
		return

	drive_to_terminal(current_trip.get_departure_terminal().terminal_id)
	_brigade_trip_current_stop_idx = 0


func _drive_to_next_stop() -> void:
	var current_trip = get_current_trip()
	if not current_trip:
		return

	if _brigade_trip_current_stop_idx + 1 >= current_trip.get_stops().size():
		var trip_idx = _brigade.assign_next_trip(_vehicle.id, _brigade_trip_idx)
		if trip_idx == -1:
			_state = BusState.TRANSFERING_TO_TERMINAL
			_brigade = null
			_drive_to_terminal()
			return
		_brigade_trip_idx = trip_idx
		_brigade_trip_current_stop_idx = -1
		_join_trip()
		return

	_state = BusState.EN_ROUTE
	_is_leaving_building = _is_at_terminal
	_brigade_trip_current_stop_idx += 1
	_target_terminal = current_trip.get_arrival_terminal()
	_vehicle.driver.resume_driving()


func _get_start_node_of_network_location(step: Dictionary) -> Array:
	match step["type"]:
		Navigator.StepType.NODE:
			return [step["node"].id, step["to_endpoint"]]
		Navigator.StepType.SEGMENT:
			return [step["prev_node"], step["from_endpoint"]]
		_:
			return [-1, -1]


func _remove_vehicle() -> void:
	_origin_depot.insta_return_bus(_vehicle.id)
	_vehicle_manager.remove_vehicle(_vehicle.id)

	if _current_terminal:
		_current_terminal.notify_vehicle_left_terminal(_vehicle.id)


func _handle_entering_terminal() -> bool:
	var path = _target_terminal.try_enter(_vehicle.id)
	if path:
		_vehicle.navigator.set_custom_step(path, SimulationConstants.MAX_INSIDE_BUILDING_SPEED)
		_has_navigation_set = true
		_is_at_terminal = true
		_current_terminal = _target_terminal
		_is_entering_building = false
		return true

	return false


func _handle_leaving_building() -> bool:
	if _is_at_terminal:
		var result = _current_terminal.leave_terminal(_vehicle.id)

		match result["error"]:
			null:
				_vehicle.navigator.set_custom_step(result["path"], SimulationConstants.MAX_INSIDE_BUILDING_SPEED)
				_has_navigation_set = true
				return true
			TerminalTrackState.TrackSearchError.ALREADY_ON_TARGET:
				_drive_to_terminal()
				_current_terminal.notify_vehicle_left_terminal(_vehicle.id)
				_current_terminal = null
				_is_at_terminal = false
				_is_leaving_building = false
				_has_navigation_set = true
				return true

	if _is_at_depot:
		_drive_to_terminal()
		_is_at_depot = false
		_is_leaving_building = false
		_has_navigation_set = true
		return true

	return false


func _handle_at_terminal(current_trip: BrigadeTrip, delta: float) -> bool:
	var result
	if _current_terminal != _target_terminal:
		_is_leaving_building = true

	var is_driving_to_departure = false

	if _brigade != null:
		var peron_index = _current_terminal.get_peron_for_line(_brigade.line_id)

		if current_trip.is_future_trip():
			var time_to_dep = current_trip.get_time_till_departure()
			if time_to_dep > SimulationConstants.BUS_OCCUPY_PERON_THRESHOLD:
				result = _current_terminal.wait_at_terminal(_vehicle.id)
			else:
				result = _current_terminal.navigate_to_peron(_vehicle.id, peron_index)
				is_driving_to_departure = true
		else:
			result = _current_terminal.navigate_to_peron(_vehicle.id, peron_index)
			is_driving_to_departure = true
	else:
		result = _current_terminal.wait_at_terminal(_vehicle.id)

	if is_driving_to_departure:
		_state = BusState.EN_ROUTE

	match result["error"]:
		null:
			_vehicle.navigator.set_custom_step(result["path"], SimulationConstants.MAX_INSIDE_BUILDING_SPEED)
			_has_navigation_set = true
			return true
		TerminalTrackState.TrackSearchError.ALREADY_ON_TARGET:
			if not is_driving_to_departure:
				_state = BusState.WAIT_BETWEEN_TRIPS
				return true

			_handle_stop(current_trip, delta)

			return true
		TerminalTrackState.TrackSearchError.NO_FREE_WAIT_TRACK, TerminalTrackState.TrackSearchError.TRACK_IN_USE:
			# Wait and try again next frame
			return true

	return false


func _handle_stop(current_trip: BrigadeTrip, delta: float) -> void:
	var stop_departure_time = current_trip.get_departure_time_at_stop(_brigade_trip_current_stop_idx)
	var is_last_stop = _brigade_trip_current_stop_idx + 1 >= current_trip.get_stops().size()

	match _state:
		BusState.EN_ROUTE:
			_state = BusState.BOARDING_PASSENGERS
			var passengers_to_move = 0 # to implement
			_boarding_timer = min(SimulationConstants.BUS_MAX_BOARDING_TIME, passengers_to_move * SimulationConstants.BUS_BOARDING_TIME_PER_PASSENGER)
		BusState.BOARDING_PASSENGERS:
			_boarding_timer -= delta

			if _boarding_timer <= 0.0:
				_state = BusState.SYNCING_WITH_SCHEDULE
				_handle_stop(current_trip, delta)
		BusState.SYNCING_WITH_SCHEDULE:
			if is_last_stop or not current_trip.check_if_can_wait_at_stop(_brigade_trip_current_stop_idx):
				_drive_to_next_stop()
				return

			var current_time = _game_manager.clock.get_time().to_time_of_day()

			if current_time.to_minutes() < stop_departure_time.to_minutes():
				return

			_drive_to_next_stop()


func _on_location_trigger_reached(vehicle: Vehicle, _node_id: int, _endpoint_id: int) -> void:
	var current_line_stop = get_current_trip().get_stop(_brigade_trip_current_stop_idx)

	var stop_obj = _transport_manager.get_stop(current_line_stop.target_id)

	var is_articulated = vehicle.type == VehicleManager.VehicleType.ARTICULATED_BUS
	var additional_offset = 15 if is_articulated else 0
	var offset = stop_obj.get_position_offset() + additional_offset

	vehicle.driver.stop_after_distance(offset, Callable(self, "_arrived_at_stop"))


func _arrived_at_stop() -> void:
	_state = BusState.BOARDING_PASSENGERS
