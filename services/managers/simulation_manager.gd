extends RefCounted

class_name SimulationManager

var vehicle_manager: VehicleManager
var network_manager: NetworkManager
var game_manager: GameManager
var config_manager: ConfigManager
var transport_manager: TransportManager

var simulation_running: bool = false

var _visual_day_night_cycle_enabled = false

var game_controller: GameController

signal day_night_changed(is_day: bool)
signal desired_world_lights_state_changed(new_state: bool)


func inject_dependencies() -> void:
	vehicle_manager = GDInjector.inject("VehicleManager") as VehicleManager
	network_manager = GDInjector.inject("NetworkManager") as NetworkManager
	game_manager = GDInjector.inject("GameManager") as GameManager
	config_manager = GDInjector.inject("ConfigManager") as ConfigManager
	transport_manager = GDInjector.inject("TransportManager") as TransportManager

	config_manager.DebugToggles.ToggleChanged.connect(_on_debug_toggles_changed)


func setup(_game_controller: GameController) -> void:
	game_controller = _game_controller
	game_controller.get_map().process_mode = Node.PROCESS_MODE_DISABLED

	game_manager.clock.day_night_changed.connect(Callable(self, "_on_day_night_cycle_changed"))
	game_controller.get_map().world_desired_lights_state_change.connect(Callable(self, "_on_desired_world_lights_state_changed"))


func start_simulation() -> void:
	var map = game_controller.get_map()
	map.process_mode = Node.PROCESS_MODE_INHERIT

	_visual_day_night_cycle_enabled = config_manager.DebugToggles.UseDayNightCycle
	map.update_day_progress(game_manager.clock.get_day_progress_percentage() if _visual_day_night_cycle_enabled else 0.5)

	print("Simulation started")

	simulation_running = true


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


func clock() -> ClockManager:
	return game_manager.clock


func is_day() -> bool:
	return game_manager.clock.is_day()


func is_day_night_cycle_enabled() -> bool:
	return _visual_day_night_cycle_enabled


func get_desired_world_lights_state() -> bool:
	return _visual_day_night_cycle_enabled and game_controller.get_map().should_world_lights_be_on(game_manager.clock.get_day_progress_percentage())


func _on_debug_toggles_changed(toggle_name: String, value: bool) -> void:
	if toggle_name == "UseDayNightCycle":
		_visual_day_night_cycle_enabled = value
		game_controller.get_map().update_day_progress(game_manager.clock.get_day_progress_percentage() if _visual_day_night_cycle_enabled else 0.5)


func _on_day_night_cycle_changed(_is_day: bool) -> void:
	emit_signal("day_night_changed", _is_day)


func _on_desired_world_lights_state_changed(new_state: bool) -> void:
	emit_signal("desired_world_lights_state_changed", new_state)
