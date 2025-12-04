extends RefCounted

class_name BusAI

enum BusState {
	IDLE,
	RETURNING_TO_DEPOT,
	EN_ROUTE,
}

var _vehicle: Vehicle
var _vehicle_manager: VehicleManager
var _state: BusState = BusState.IDLE

var _origin_depot: Depot = null

var _is_entering_building: bool = false
var _has_trip: bool = true


func bind(vehicle: Vehicle) -> void:
	vehicle.driver.set_ai(self)
	vehicle.ai = self
	_vehicle = vehicle
	_vehicle_manager = GDInjector.inject("VehicleManager") as VehicleManager
	_state = BusState.EN_ROUTE


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
		_:
			return "Unknown"


func set_origin_depot(depot: Depot) -> void:
	_origin_depot = depot


func on_trip_finished(completed: bool, _trip_data: Dictionary) -> void:
	if not completed:
		_vehicle_manager.remove_vehicle(_vehicle.id)
		return
	_has_trip = false


func return_to_depot() -> void:
	if _state == BusState.RETURNING_TO_DEPOT:
		return

	if not _origin_depot:
		_vehicle_manager.remove_vehicle(_vehicle.id)
		return

	match _state:
		BusState.EN_ROUTE:
			var current_step = _vehicle.navigator.get_current_step()

			if current_step["type"] == Navigator.StepType.BUILDING:
				return

			var start_node_data = _get_start_node_of_location(current_step)
			var start_node = start_node_data[0]
			var start_endpoint = start_node_data[1]

			if start_node == -1:
				_vehicle_manager.remove_vehicle(_vehicle.id)
				return

			_vehicle.init_trip_to_building(start_node, _origin_depot, start_endpoint)
		_:
			pass

	_state = BusState.RETURNING_TO_DEPOT
	_is_entering_building = false


func process() -> void:
	match _state:
		BusState.RETURNING_TO_DEPOT:
			if _has_trip:
				return

			if not _is_entering_building:
				var path = _origin_depot.try_enter(_vehicle)
				if path:
					_is_entering_building = true
					_vehicle.navigator.set_custom_step(path, 30.0)
					_has_trip = true
				return

			_vehicle_manager.remove_vehicle(_vehicle.id)


func _get_start_node_of_location(step: Dictionary) -> Array:
	match step["type"]:
		Navigator.StepType.NODE:
			return [step["node"].id, step["to_endpoint"]]
		Navigator.StepType.SEGMENT:
			return [step["prev_node"], step["from_endpoint"]]
		_:
			return [-1, -1]
