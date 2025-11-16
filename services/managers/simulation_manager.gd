extends RefCounted

class_name SimulationManager

var vehicle_manager: VehicleManager
var network_manager: NetworkManager
var game_manager: GameManager
var config_manager: ConfigManager

var simulation_running: bool = false

var end_node_ids: Array = []
var vehicles_count = 0
var max_vehicles = 4
var _visual_day_night_cycle_enabled = false

var game_controller: GameController

signal day_night_changed(is_day: bool)
signal desired_world_lights_state_changed(new_state: bool)


func inject_dependencies() -> void:
	vehicle_manager = GDInjector.inject("VehicleManager") as VehicleManager
	network_manager = GDInjector.inject("NetworkManager") as NetworkManager
	game_manager = GDInjector.inject("GameManager") as GameManager
	config_manager = GDInjector.inject("ConfigManager") as ConfigManager

	config_manager.DebugToggles.ToggleChanged.connect(_on_debug_toggles_changed)


func setup(_game_controller: GameController) -> void:
	game_controller = _game_controller
	game_controller.get_map().process_mode = Node.PROCESS_MODE_DISABLED

	game_manager.clock.day_night_changed.connect(Callable(self, "_on_day_night_cycle_changed"))
	game_controller.get_map().world_desired_lights_state_change.connect(Callable(self, "_on_desired_world_lights_state_changed"))


func start_simulation() -> void:
	end_node_ids = network_manager.get_end_nodes().map(func(node): return node.id)

	var map = game_controller.get_map()
	map.process_mode = Node.PROCESS_MODE_INHERIT

	_visual_day_night_cycle_enabled = config_manager.DebugToggles.UseDayNightCycle
	map.update_day_progress(game_manager.clock.get_day_progress_percentage() if _visual_day_night_cycle_enabled else 0.5)

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
		if _visual_day_night_cycle_enabled:
			game_controller.get_map().update_day_progress(game_manager.clock.get_day_progress_percentage())


func is_day() -> bool:
	return game_manager.clock.is_day()


func is_day_night_cycle_enabled() -> bool:
	return _visual_day_night_cycle_enabled


func get_desired_world_lights_state() -> bool:
	return _visual_day_night_cycle_enabled and game_controller.get_map().should_world_lights_be_on(game_manager.clock.get_day_progress_percentage())


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


func _on_debug_toggles_changed(toggle_name: String, value: bool) -> void:
	if toggle_name == "UseDayNightCycle":
		_visual_day_night_cycle_enabled = value
		game_controller.get_map().update_day_progress(game_manager.clock.get_day_progress_percentage() if _visual_day_night_cycle_enabled else 0.5)


func _on_day_night_cycle_changed(_is_day: bool) -> void:
	emit_signal("day_night_changed", _is_day)


func _on_desired_world_lights_state_changed(new_state: bool) -> void:
	emit_signal("desired_world_lights_state_changed", new_state)
