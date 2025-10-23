extends RefCounted
class_name VehicleManager

var CAR = preload("res://game-objects/vehicles/car/car.tscn")

enum VEHICLE_TYPE {
	CAR
}

var game_manager: GameManager

var vehicles_layer: Node2D

var vehicles: Dictionary[int, Vehicle] = {}

var freed_ids_pool: Array[int] = []
var next_fresh_id: int = 0

signal vehicle_destroyed(vehicle_id: int)

func set_vehicles_layer(layer: Node2D) -> void:
	vehicles_layer = layer

	game_manager = GDInjector.inject("GameManager") as GameManager


func create_vehicle(vehicle_type: VEHICLE_TYPE) -> Vehicle:

	var vehicle: Vehicle

	match vehicle_type:
		VEHICLE_TYPE.CAR:
			vehicle = CAR.instantiate()
		_:
			push_error("Unknown vehicle type: %d" % vehicle_type)
			return null

	vehicle.id = _generate_vehicle_id()

	vehicles[vehicle.id] = vehicle
	vehicles_layer.add_child(vehicle)

	vehicle.connect("trip_abandoned", Callable(self, "_on_vehicle_cleanup"))
	vehicle.connect("trip_completed", Callable(self, "_on_vehicle_cleanup"))
	return vehicle


func get_vehicle(vehicle_id: int) -> Vehicle:
	if vehicles.has(vehicle_id):
		return vehicles[vehicle_id]
	else:
		push_error("Vehicle with ID %d not found." % vehicle_id)
		return null

func remove_vehicle(vehicle_id: int) -> void:
	if not vehicles.has(vehicle_id):
		push_error("Vehicle with ID %d not found." % vehicle_id)
		return

	var vehicle = vehicles[vehicle_id]

	emit_signal("vehicle_destroyed", vehicle_id)

	var selection = game_manager.get_selection()

	if selection.type == GameManager.SelectionType.VEHICLE and selection.object == vehicle:
		game_manager.clear_selection()

	vehicles.erase(vehicle_id)
	vehicle.queue_free()
	freed_ids_pool.append(vehicle_id)

func vehicles_count() -> int:
	return vehicles.size()

func _generate_vehicle_id() -> int:
	if freed_ids_pool.size() > 0:
		return freed_ids_pool.pop_back()
	else:
		next_fresh_id += 1
		return next_fresh_id - 1


func _on_vehicle_cleanup(vehicle_id: int) -> void:
	remove_vehicle(vehicle_id)
