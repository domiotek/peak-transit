extends RefCounted

class_name SimulationManager

var vehicle_manager: VehicleManager
var network_manager: NetworkManager
var game_manager: GameManager

var simulation_running: bool = false

var end_node_ids: Array = []
var vehicles_count = 0
var max_vehicles = 4


var game_controller: GameController

func _init() -> void:
	vehicle_manager = GDInjector.inject("VehicleManager") as VehicleManager
	network_manager = GDInjector.inject("NetworkManager") as NetworkManager
	game_manager = GDInjector.inject("GameManager") as GameManager

func setup(_game_controller: GameController) -> void:
	game_controller = _game_controller
	game_controller.get_map().process_mode = Node.PROCESS_MODE_DISABLED

func start_simulation() -> void:
	end_node_ids = network_manager.get_end_nodes().map(func(node): return node.id)
	game_controller.get_map().process_mode = Node.PROCESS_MODE_INHERIT
	print("Simulation started")

	simulation_running = true

	for i in max_vehicles:
		_spawn_bus()

func stop_simulation() -> void:
	simulation_running = false
	game_controller.get_map().process_mode = Node.PROCESS_MODE_DISABLED
	print("Simulation stopped")

func is_simulation_running() -> bool:
	return simulation_running

func step_simulation(delta: float) -> void:
	if simulation_running:
		game_manager.clock.advance_time(delta)


func _get_random_nodes() -> Array:
	var start_node_id = end_node_ids[randi() % end_node_ids.size()]
	var end_node_id = end_node_ids[randi() % end_node_ids.size()]

	while start_node_id == end_node_id:
		end_node_id = end_node_ids[randi() % end_node_ids.size()]

	return [start_node_id, end_node_id]

func _spawn_bus() -> void:
	if not simulation_running:
		return

	var bus = vehicle_manager.create_vehicle(VehicleManager.VEHICLE_TYPE.ARTICULATED_BUS if randf() < 0.5 else VehicleManager.VEHICLE_TYPE.BUS)
	var nodes = _get_random_nodes()

	await bus.get_tree().create_timer(bus.id).timeout

	bus.init_simple_trip(nodes[0], nodes[1])

	bus.connect("trip_completed", Callable(self, "_on_vehicle_trip_completed"))

func _on_vehicle_trip_completed(_id) -> void:
	if simulation_running:
		_spawn_bus()
