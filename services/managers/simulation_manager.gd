extends RefCounted

class_name SimulationManager

var vehicle_manager: VehicleManager
var network_manager: NetworkManager

var end_node_ids: Array = []

var vehicles_count = 0
var max_vehicles = 300


func _init() -> void:
	vehicle_manager = GDInjector.inject("VehicleManager") as VehicleManager
	network_manager = GDInjector.inject("NetworkManager") as NetworkManager



func start_simulation() -> void:
	end_node_ids = network_manager.get_end_nodes().map(func(node): return node.id)
	print("Simulation started")

	for i in max_vehicles:
		_spawn_vehicle()


func _get_random_nodes() -> Array:
	var start_node_id = end_node_ids[randi() % end_node_ids.size()]
	var end_node_id = end_node_ids[randi() % end_node_ids.size()]

	while start_node_id == end_node_id:
		end_node_id = end_node_ids[randi() % end_node_ids.size()]

	return [start_node_id, end_node_id]

func _spawn_vehicle() -> void:
	var vehicle = vehicle_manager.create_vehicle()
	var nodes = _get_random_nodes()

	await vehicle.get_tree().create_timer(vehicle.id).timeout

	vehicle.init_trip(nodes[0], nodes[1])

	vehicle.connect("trip_completed", Callable(self, "_on_vehicle_trip_completed"))

func _on_vehicle_trip_completed(_id) -> void:
	_spawn_vehicle()
