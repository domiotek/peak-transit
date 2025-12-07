extends RefCounted

class_name BusAI

enum BusState {
	IDLE,
	CONFUSED,
	RETURNING_TO_DEPOT,
	EN_ROUTE,
	TRANSFERING_TO_TERMINAL,
}

var _vehicle: Vehicle
var _vehicle_manager: VehicleManager
var _transport_manager: TransportManager
var _state: BusState = BusState.IDLE
var _is_at_depot: bool = true
var _is_at_terminal: bool = false

var _origin_depot: Depot = null
var _current_terminal: Terminal = null
var _target_terminal: Terminal = null
var _brigade: Brigade = null

var _is_leaving_building: bool = false
var _is_entering_building: bool = false
var _has_trip: bool = true


func bind(vehicle: Vehicle) -> void:
	vehicle.driver.set_ai(self)
	vehicle.ai = self
	_vehicle = vehicle
	_vehicle_manager = GDInjector.inject("VehicleManager") as VehicleManager
	_transport_manager = GDInjector.inject("TransportManager") as TransportManager


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
		BusState.EN_ROUTE:
			return "En Route"
		BusState.TRANSFERING_TO_TERMINAL:
			return "Transfering to Terminal"
		BusState.CONFUSED:
			return "Confused"
		_:
			return "Unknown"


func set_origin_depot(depot: Depot) -> void:
	_origin_depot = depot


func on_trip_finished(completed: bool, _trip_data: Dictionary) -> void:
	if not completed:
		_remove_vehicle()
		return
	_has_trip = false

	if not _is_at_depot and not _is_at_terminal:
		_is_entering_building = true


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
		BusState.EN_ROUTE:
			_drive_to_depot()
		_:
			if _is_at_terminal:
				_is_leaving_building = true
			else:
				_drive_to_depot()

	_state = BusState.RETURNING_TO_DEPOT


func drive_to_terminal(id: int) -> void:
	var terminal_building = _transport_manager.get_terminal(id)
	if not terminal_building:
		return

	_target_terminal = terminal_building

	_is_entering_building = false
	_is_leaving_building = _is_at_depot or (_is_at_terminal and _target_terminal != _current_terminal)

	if not _is_leaving_building:
		_drive_to_terminal()

	_state = BusState.TRANSFERING_TO_TERMINAL


func get_current_terminal() -> Terminal:
	return _current_terminal


func process() -> void:
	if _state == BusState.IDLE or _state == BusState.CONFUSED:
		return

	match _state:
		BusState.RETURNING_TO_DEPOT:
			if _has_trip:
				return

			if _is_leaving_building:
				if _is_at_terminal:
					var result = _current_terminal.leave_terminal(_vehicle.id)

					match result["error"]:
						null:
							_vehicle.navigator.set_custom_step(result["path"], SimulationConstants.MAX_INSIDE_BUILDING_SPEED)
							_has_trip = true
							return
						TerminalTrackState.TrackSearchError.ALREADY_ON_TARGET:
							_drive_to_depot()
							_current_terminal.notify_vehicle_left_terminal(_vehicle.id)
							_current_terminal = null
							_is_at_terminal = false
							_is_leaving_building = false
							_has_trip = true
							return
						TerminalTrackState.TrackSearchError.TRACK_IN_USE:
							# Wait and try again next frame
							return

			if _is_entering_building:
				var path = _origin_depot.try_enter(_vehicle)
				if path:
					_vehicle.navigator.set_custom_step(path, SimulationConstants.MAX_INSIDE_BUILDING_SPEED)
					_has_trip = true
					_is_at_depot = true
					_is_entering_building = false
					return

			_remove_vehicle()
			return
		BusState.TRANSFERING_TO_TERMINAL:
			if _has_trip:
				return

			if _is_leaving_building:
				if _is_at_terminal:
					var result = _current_terminal.leave_terminal(_vehicle.id)

					match result["error"]:
						null:
							_vehicle.navigator.set_custom_step(result["path"], SimulationConstants.MAX_INSIDE_BUILDING_SPEED)
							_has_trip = true
							return
						TerminalTrackState.TrackSearchError.ALREADY_ON_TARGET:
							_drive_to_terminal()
							_current_terminal.notify_vehicle_left_terminal(_vehicle.id)
							_current_terminal = null
							_is_at_terminal = false
							_is_leaving_building = false
							_has_trip = true
							return

				if _is_at_depot:
					_drive_to_terminal()
					_is_at_depot = false
					_is_leaving_building = false
					_has_trip = true
					return

			if _is_entering_building:
				var path = _target_terminal.try_enter(_vehicle.id)
				if path:
					_vehicle.navigator.set_custom_step(path, SimulationConstants.MAX_INSIDE_BUILDING_SPEED)
					_has_trip = true
					_is_at_terminal = true
					_current_terminal = _target_terminal
					_is_entering_building = false
					return

			if _is_at_terminal:
				var result
				if _current_terminal != _target_terminal:
					_is_leaving_building = true

				if _brigade != null:
					var peron_index = _current_terminal.get_peron_for_line(_brigade.line_id)
					result = _current_terminal.navigate_to_peron(_vehicle.id, peron_index)
				else:
					result = _current_terminal.wait_at_terminal(_vehicle.id)

				match result["error"]:
					null:
						_vehicle.navigator.set_custom_step(result["path"], SimulationConstants.MAX_INSIDE_BUILDING_SPEED)
						_has_trip = true
						return
					TerminalTrackState.TrackSearchError.ALREADY_ON_TARGET:
						_state = BusState.IDLE
						return
					TerminalTrackState.TrackSearchError.NO_FREE_WAIT_TRACK, TerminalTrackState.TrackSearchError.TRACK_IN_USE:
						# Wait and try again next frame
						return

	_state = BusState.CONFUSED


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
	_vehicle.init_trip(source_building, _target_terminal)


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
