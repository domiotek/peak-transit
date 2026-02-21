extends Node2D

class_name BaseGameController

@onready var camera: Camera2D = $Camera
@onready var map: Map = $Map
@onready var debug_layer: Node2D = $DebugLayer
@onready var rl_mode_tag: Label = $UI/RLModeTag

var camera_bounds: Rect2
var camera_projection_offset := Vector2(2, 1.35)
var camera_speed := 500.0
var camera_zoom_bounds: Array[Vector2] = [Vector2(0.5, 0.5), Vector2(6, 6)]

var ui_manager: UIManager
var config_manager: ConfigManager
var game_manager: GameManager
var simulation_manager: SimulationManager
var circle_helper: DebugCircleHelper
var world_manager: WorldManager

var _world_definition: WorldDefinition


func _ready() -> void:
	game_manager = GDInjector.inject("GameManager") as GameManager
	simulation_manager = GDInjector.inject("SimulationManager") as SimulationManager
	config_manager = GDInjector.inject("ConfigManager") as ConfigManager
	ui_manager = GDInjector.inject("UIManager") as UIManager
	circle_helper = GDInjector.inject("DebugCircleHelper") as DebugCircleHelper
	world_manager = GDInjector.inject("WorldManager") as WorldManager

	game_manager.setup(self)

	config_manager.DebugToggles.ToggleChanged.connect(_on_debug_toggles_changed)
	game_manager.rl_mode_toggled.connect(_show_rl_tag)


func get_mode() -> Enums.GameMode:
	return Enums.GameMode.UNSPECIFIED


func get_map() -> Map:
	return map


func get_camera() -> Camera:
	return camera


func get_camera_bounds() -> Rect2:
	return camera_bounds


func get_camera_zoom_bounds() -> Array[Vector2]:
	return camera_zoom_bounds


func get_max_game_speed() -> Enums.GameSpeed:
	return Enums.GameSpeed.TURBO


func get_world_definition() -> WorldDefinition:
	return _world_definition


func initialize_game(world_file_path: String) -> bool:
	ui_manager.show_ui_view("WorldLoadingProgressView")

	var world = _on_load_world(world_file_path)
	if not world:
		ui_manager.hide_ui_view("WorldLoadingProgressView")
		return false

	_world_definition = world

	init_map(world)
	await get_tree().process_frame

	await _on_initialize_game(world)

	ui_manager.hide_ui_view("WorldLoadingProgressView")
	_after_initialize_game()
	return true


func init_map(world: WorldDefinition) -> void:
	map.map_size = world.map.size
	var rect_position = -map.map_size / 2
	camera_bounds = Rect2(rect_position, map.map_size)
	camera.set_camera_props(camera_bounds, camera_projection_offset, camera_zoom_bounds, camera_speed)
	camera.position = world.map.initial_pos
	camera.zoom = Vector2.ONE * world.map.initial_zoom


func get_game_menu_buttons() -> Array[GameMenuButton]:
	return []


func _draw() -> void:
	for child in debug_layer.get_children():
		child.queue_free()

	if config_manager.DebugToggles.DrawCameraBounds:
		var line = Line2D.new()
		line.default_color = Color.RED
		line.width = 2.0
		line.closed = true
		line.add_point(camera_bounds.position)
		line.add_point(camera_bounds.position + Vector2(camera_bounds.size.x, 0))
		line.add_point(camera_bounds.position + camera_bounds.size)
		line.add_point(camera_bounds.position + Vector2(0, camera_bounds.size.y))
		debug_layer.add_child(line)

		circle_helper.draw_debug_circle(camera.get_screen_center_position(), Color.BLUE, debug_layer, { "size": 10.0 })


func _process(delta):
	if not game_manager.is_game_initialized():
		return

	simulation_manager.step_simulation(delta)

	if Input.is_action_just_pressed("toggle_game_menu") and not game_manager.is_rl_mode():
		game_manager.toggle_game_menu()
		return

	if game_manager.is_game_menu_visible():
		return

	if Input.is_action_just_pressed("toggle_dev_tools"):
		ui_manager.toggle_ui_view("DebugTogglesView")

		if ui_manager.has_ui_view("DebugIntersectionsView"):
			ui_manager.toggle_ui_view("DebugIntersectionsView")
		return

	_on_input_check()


func _on_debug_toggles_changed(_name, _state) -> void:
	queue_redraw()


func _on_load_world(file_path: String) -> WorldDefinition:
	return _load_world_from_file_path(file_path)


func _on_initialize_game(_world: WorldDefinition) -> void:
	await get_tree().process_frame


func _after_initialize_game() -> void:
	pass


func _on_input_check() -> void:
	pass


func _load_world_from_file_path(file_path: String) -> WorldDefinition:
	print("Loading world from file: %s" % file_path)

	var world_def = world_manager.LoadSerializedWorldDefinition(file_path)

	if not world_def['definition']:
		push_error("Failed to load world definition from file: %s" % file_path)
		ui_manager.show_ui_view(
			MessageBoxView.VIEW_NAME,
			{
				"title": "Error during world load",
				"message": "Failed to parse world definition from file: %s\n\nAdditional info: %s" % [
					file_path,
					world_def['parsingError'] if world_def.has('parsingError') else "None",
				],
			},
		)

		return

	return WorldDefinition.deserialize(world_def.definition)


func _show_rl_tag(state: bool) -> void:
	rl_mode_tag.visible = state
