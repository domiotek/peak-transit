extends RefCounted

class_name VehicleManager

var CarScene = preload("res://game-objects/vehicles/car/car.tscn")
var BusScene = preload("res://game-objects/vehicles/bus/bus.tscn")
var ArticulatedBusScene = preload("res://game-objects/vehicles/articulated-bus/articulated_bus.tscn")
var _vehicle_scenes: Array[PackedScene]

enum VehicleType {
	CAR,
	BUS,
	ARTICULATED_BUS,
}

enum VehicleCategory {
	PRIVATE,
	PUBLIC_TRANSPORT,
}

var game_manager: GameManager

var vehicles_layer: Node2D

var vehicles: Dictionary[int, Vehicle] = { }
var _vehicles_by_type: Dictionary[int, Dictionary] = { }
var _vehicle_spawn_budget: int = SimulationConstants.VEHICLE_FRAME_SPAWN_BUDGET

var freed_ids_pool: Array[int] = []
var next_fresh_id: int = 0

signal vehicle_created(vehicle: Vehicle)
signal vehicle_destroyed(vehicle_id: int, vehicle_type: VehicleType)


func _init() -> void:
	_vehicle_scenes = [CarScene, BusScene, ArticulatedBusScene]
	_vehicles_by_type[VehicleType.CAR] = { }
	_vehicles_by_type[VehicleType.BUS] = { }
	_vehicles_by_type[VehicleType.ARTICULATED_BUS] = { }


func inject_dependencies() -> void:
	var simulation_manager = GDInjector.inject("SimulationManager") as SimulationManager
	simulation_manager.desired_world_lights_state_changed.connect(_on_desired_world_lights_state_changed)


func set_vehicles_layer(layer: Node2D) -> void:
	vehicles_layer = layer

	game_manager = GDInjector.inject("GameManager") as GameManager


func create_vehicle(vehicle_type: VehicleType) -> Vehicle:
	if not vehicles_layer:
		push_error("Vehicles layer is not set. Cannot create vehicle.")
		return null

	if vehicle_type == VehicleType.CAR and _vehicle_spawn_budget <= 0:
		return null

	if vehicle_type < 0 or vehicle_type >= _vehicle_scenes.size():
		push_error("Unknown vehicle type: %d" % vehicle_type)
		return null

	var vehicle_scene = _vehicle_scenes[vehicle_type] as PackedScene
	var vehicle = vehicle_scene.instantiate() as Vehicle
	if not vehicle:
		push_error("Failed to instantiate vehicle scene for type: %d" % vehicle_type)
		return null

	vehicle.id = _generate_vehicle_id()
	vehicle.type = vehicle_type

	vehicles_layer.add_child(vehicle)



	vehicles[vehicle.id] = vehicle
	var type_bucket = _vehicles_by_type.get(vehicle_type, null) as Dictionary
	if type_bucket != null:
		type_bucket[vehicle.id] = vehicle
	vehicle_created.emit(vehicle)
	_vehicle_spawn_budget -= 1
	return vehicle


func get_vehicle(vehicle_id: int) -> Vehicle:
	if vehicles.has(vehicle_id):
		return vehicles[vehicle_id]

	push_error("Vehicle with ID %d not found." % vehicle_id)
	return null


func vehicle_exists(vehicle_id: int) -> bool:
	return vehicles.has(vehicle_id)


func remove_vehicle(vehicle_id: int) -> void:
	var vehicle := vehicles.get(vehicle_id) as Vehicle

	if not vehicle:
		push_error("Vehicle with ID %d not found." % vehicle_id)
		return

	var selection := game_manager.get_selection()

	if selection.type == GameManager.SelectionType.VEHICLE and selection.object == vehicle:
		game_manager.clear_selection()

	vehicles.erase(vehicle_id)
	_despawn_vehicle(vehicle)


func vehicles_count() -> int:
	return vehicles.size()


func get_vehicles_by_types(vehicle_types: Array[VehicleType]) -> Array[Vehicle]:
	var result: Array[Vehicle] = []
	var used_types: Dictionary = { }

	for vehicle_type in vehicle_types:
		if used_types.has(vehicle_type):
			continue
		used_types[vehicle_type] = true

		var type_bucket = _vehicles_by_type.get(vehicle_type, null) as Dictionary
		if type_bucket == null:
			continue

		for vehicle in type_bucket.values():
			result.append(vehicle)

	return result


func get_vehicles() -> Array[Vehicle]:
	return vehicles.values()


func get_vehicle_from_area(area: Area2D) -> Vehicle:
	if not area:
		return null

	if area.has_meta("vehicle_ref"):
		var vehicle_ref = area.get_meta("vehicle_ref") as Vehicle
		if is_instance_valid(vehicle_ref):
			return vehicle_ref

	var first_parent = area.get_parent()

	if first_parent is Vehicle:
		return first_parent as Vehicle

	if first_parent.get_parent() is Vehicle:
		return first_parent.get_parent() as Vehicle
	return null


func clear_all_vehicles() -> void:
	if vehicles.size() == 0:
		return

	var vehicles_to_remove: Array[Vehicle] = vehicles.values()
	vehicles.clear()

	for vehicle in vehicles_to_remove:
		if is_instance_valid(vehicle):
			_despawn_vehicle(vehicle)


func reset_vehicle_spawn_budget() -> void:
	_vehicle_spawn_budget = SimulationConstants.VEHICLE_FRAME_SPAWN_BUDGET


func clear_state() -> void:
	vehicles.clear()
	for bucket in _vehicles_by_type.values():
		(bucket as Dictionary).clear()

	freed_ids_pool.clear()
	next_fresh_id = 0
	vehicles_layer = null
	_vehicle_spawn_budget = SimulationConstants.VEHICLE_FRAME_SPAWN_BUDGET


func _generate_vehicle_id() -> int:
	if freed_ids_pool.size() > 0:
		return freed_ids_pool.pop_back()

	next_fresh_id += 1
	return next_fresh_id - 1


func _despawn_vehicle(vehicle: Vehicle) -> void:
	var vehicle_id := vehicle.id
	var type_bucket = _vehicles_by_type.get(vehicle.type, null) as Dictionary
	if type_bucket != null:
		type_bucket.erase(vehicle_id)

	vehicle.queue_free()
	freed_ids_pool.append(vehicle_id)
	vehicle_destroyed.emit(vehicle_id, vehicle.type)


func _on_desired_world_lights_state_changed(new_state: bool) -> void:
	for vehicle in vehicles.values():
		vehicle.driver.set_headlights_enabled(new_state)
