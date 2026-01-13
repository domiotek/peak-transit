extends RefCounted

class_name GameManager

var challenge_game_mode_scene: PackedScene = load("res://game-objects/game-modes/challenge-mode/challenge_mode.tscn")
var map_editor_game_mode_scene: PackedScene = load("res://game-objects/game-modes/map-editor-mode/map_editor_mode.tscn")

enum SelectionType {
	NONE,
	VEHICLE,
	NODE,
	STOPPER,
	SPAWNER_BUILDING,
	TERMINAL,
	TRANSPORT_STOP,
	DEPOT,
}

var selected_object: Object = null
var selection_type: SelectionType = SelectionType.NONE
var selection_popup_id: Variant = null
var debug_selection: bool = false

var ui_manager: UIManager
var config_manager: ConfigManager
var line_helper: LineHelper
var simulation_manager: SimulationManager
var vehicle_manager: VehicleManager
var network_manager: NetworkManager
var buildings_manager: BuildingsManager
var pathing_manager: PathingManager
var world_manager: WorldManager
var transport_manager: TransportManager

var _game_controller: BaseGameController
var _game_mode: Enums.GameMode

var world_definition: WorldDefinition

var game_speed: Enums.GameSpeed = Enums.GameSpeed.PAUSE
var initialized: bool = false
var game_menu_visible: bool = false
var clock = ClockManager.new()

signal game_controller_registration(controller: BaseGameController)
signal game_speed_changed(new_speed: Enums.GameSpeed)
signal world_loading_progress(action: String, progress: float)


func setup(game_controller: BaseGameController) -> void:
	_game_controller = game_controller

	ui_manager = GDInjector.inject("UIManager") as UIManager
	simulation_manager = GDInjector.inject("SimulationManager") as SimulationManager
	vehicle_manager = GDInjector.inject("VehicleManager") as VehicleManager
	line_helper = GDInjector.inject("LineHelper") as LineHelper
	network_manager = GDInjector.inject("NetworkManager") as NetworkManager
	buildings_manager = GDInjector.inject("BuildingsManager") as BuildingsManager
	pathing_manager = GDInjector.inject("PathingManager") as PathingManager
	world_manager = GDInjector.inject("WorldManager") as WorldManager
	transport_manager = GDInjector.inject("TransportManager") as TransportManager

	simulation_manager.setup(_game_controller)


func get_camera_bounds() -> Rect2:
	return _game_controller.get_camera_bounds()


func initialize_game(mode: Enums.GameMode, world_file_path: String = "") -> void:
	if initialized:
		return

	_game_controller = _create_game_controller(mode)

	if not _game_controller:
		push_error("Failed to create game controller for mode: %s" % str(mode))
		return

	clock.reset()

	ui_manager.hide_main_menu()
	set_game_speed(Enums.GameSpeed.PAUSE)

	initialized = await _game_controller.initialize_game(world_file_path)

	if not initialized:
		push_error("Failed to initialize game controller")
		dispose_game()
		return

	world_definition = _game_controller.get_world_definition()


func dispose_game() -> void:
	initialized = false
	simulation_manager.stop_simulation()

	ui_manager.hide_all_ui_views()
	ui_manager.reset_ui_views()

	var map = _game_controller.get_map()
	map.clear_layers()
	_game_controller.queue_free()

	hide_game_menu()
	clear_state()
	ui_manager.show_main_menu()


func is_game_initialized() -> bool:
	return initialized


func show_game_menu() -> void:
	ui_manager.show_ui_view("GameMenuView")
	game_menu_visible = true
	set_game_speed(Enums.GameSpeed.PAUSE)


func hide_game_menu() -> void:
	ui_manager.hide_ui_view("GameMenuView")
	game_menu_visible = false


func toggle_game_menu() -> void:
	if game_menu_visible:
		hide_game_menu()
	else:
		show_game_menu()


func is_game_menu_visible() -> bool:
	return game_menu_visible


func push_loading_progress(action: String, progress: float) -> void:
	world_loading_progress.emit(action, progress)


func get_game_mode() -> Enums.GameMode:
	return _game_mode


func get_game_controller() -> BaseGameController:
	return _game_controller


func get_map() -> Map:
	return _game_controller.get_map()


func wait_frame() -> void:
	await get_map().get_tree().process_frame


func set_game_speed(speed: Enums.GameSpeed) -> void:
	var max_speed = _game_controller.get_max_game_speed()

	if speed > max_speed:
		speed = max_speed

	game_speed = speed

	match game_speed:
		Enums.GameSpeed.PAUSE:
			Engine.time_scale = 0.0
		Enums.GameSpeed.LOW:
			Engine.time_scale = 1.0
		Enums.GameSpeed.MEDIUM:
			Engine.time_scale = 5.0
		Enums.GameSpeed.HIGH:
			Engine.time_scale = 10.0
			Engine.physics_ticks_per_second = 120
		Enums.GameSpeed.TURBO:
			Engine.time_scale = 20.0
			Engine.physics_ticks_per_second = 180

	game_speed_changed.emit(game_speed)


func get_game_speed() -> Enums.GameSpeed:
	return game_speed


func set_selection(object: Object, type: SelectionType) -> void:
	if selection_type != type:
		if selection_popup_id:
			ui_manager.hide_ui_view(selection_popup_id)
			selection_popup_id = null

	selection_type = type
	selected_object = object

	match type:
		SelectionType.NONE:
			selected_object = null
		SelectionType.VEHICLE:
			selection_popup_id = "VehiclePopupView"
		SelectionType.SPAWNER_BUILDING:
			selection_popup_id = "SpawnerBuildingPopupView"
		SelectionType.DEPOT:
			selection_popup_id = DepotPopupView.VIEW_NAME
		SelectionType.TRANSPORT_STOP:
			selection_popup_id = StopPopupView.VIEW_NAME
		SelectionType.NODE, SelectionType.STOPPER, SelectionType.TERMINAL:
			pass
		_:
			push_error("Unknown selection type: %s" % str(type))
			selection_type = SelectionType.NONE
			selected_object = null

	if selection_popup_id:
		ui_manager.show_ui_view(selection_popup_id)


func clear_selection() -> void:
	set_selection(null, SelectionType.NONE)


func get_selection() -> Dictionary:
	return {
		"object": selected_object,
		"type": selection_type,
	}


func get_selected_object() -> Object:
	return selected_object


func get_selection_type() -> SelectionType:
	return selection_type


func is_debug_pick_enabled() -> bool:
	return debug_selection


func try_hit_debug_pick(object: Object) -> bool:
	if not debug_selection:
		return false

	if selection_type == SelectionType.VEHICLE and selected_object == (object as Vehicle):
		debug_selection = false
		return true

	if selection_type == SelectionType.NODE and selected_object == (object as RoadNode):
		debug_selection = false
		return true

	if selection_type == SelectionType.STOPPER and selected_object == (object as LaneStopper):
		debug_selection = false
		return true

	if selection_type == SelectionType.SPAWNER_BUILDING and selected_object == (object as SpawnerBuilding):
		debug_selection = false
		return true

	return false


func jump_to_selection() -> void:
	if not selected_object:
		return

	var global_position: Vector2

	match selection_type:
		SelectionType.VEHICLE:
			var vehicle = selected_object as Vehicle
			global_position = vehicle.global_position
		SelectionType.NODE:
			var node = selected_object as RoadNode
			global_position = node.position
		SelectionType.STOPPER:
			var stopper = selected_object as LaneStopper
			global_position = stopper.global_position
		SelectionType.SPAWNER_BUILDING:
			var spawner = selected_object as SpawnerBuilding
			global_position = spawner.global_position
		SelectionType.TRANSPORT_STOP:
			var stop = selected_object as StopSelection
			global_position = stop.get_anchor().global_position
		SelectionType.TERMINAL:
			var terminal = selected_object as StopSelection
			global_position = terminal.get_anchor().global_position
		SelectionType.DEPOT:
			var depot = selected_object as Depot
			global_position = depot.global_position
		_:
			return

	_game_controller.get_camera().set_camera_position(global_position)


func clear_state() -> void:
	selected_object = null
	selection_type = SelectionType.NONE
	selection_popup_id = null
	debug_selection = false

	pathing_manager.clear_state()
	vehicle_manager.clear_state()
	network_manager.clear_state()
	buildings_manager.clear_state()
	transport_manager.clear_state()


func _create_game_controller(mode: Enums.GameMode) -> BaseGameController:
	var controller: BaseGameController

	match mode:
		Enums.GameMode.CHALLENGE:
			controller = challenge_game_mode_scene.instantiate() as ChallengeGameController
		Enums.GameMode.MAP_EDITOR:
			controller = map_editor_game_mode_scene.instantiate() as MapEditorGameController
		_:
			push_error("Unknown game mode type: %s" % str(mode))
			return null

	game_controller_registration.emit(controller)

	return controller
