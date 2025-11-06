extends Node2D

class_name GameController

@onready var camera: Camera2D = $Camera
@onready var map: Map = $Map
@onready var debug_layer: Node2D = $DebugLayer

var camera_bounds: Rect2
var camera_projection_offset := Vector2(2, 1.35)
var camera_speed := 500.0
var camera_zoom_bounds: Array[Vector2] = [Vector2(0.5, 0.5), Vector2(6, 6)]

var ui_manager: UIManager
var config_manager: ConfigManager
var game_manager: GameManager
var circle_helper: DebugCircleHelper

func _ready() -> void:
	game_manager = GDInjector.inject("GameManager") as GameManager
	config_manager = GDInjector.inject("ConfigManager") as ConfigManager
	ui_manager = GDInjector.inject("UIManager") as UIManager
	circle_helper = GDInjector.inject("DebugCircleHelper") as DebugCircleHelper

	game_manager.setup(self)

	config_manager.DebugToggles.ToggleChanged.connect(_on_debug_toggles_changed)

func get_map() -> Map:
	return map

func get_camera_bounds() -> Rect2:
	return camera_bounds

func initialize_game(world: WorldDefinition) -> void:
	ui_manager.show_ui_view("WorldLoadingProgressView")

	init_map(world)
	await get_tree().process_frame

	await load_network_grid(world.NetworkDefinition)

	ui_manager.hide_ui_view("WorldLoadingProgressView")
	ui_manager.show_ui_view("GameSpeedView")

func init_map(world: WorldDefinition) -> void:
	map.map_size = world.MapSize
	var rect_position = -map.map_size / 2
	camera_bounds = Rect2(rect_position, map.map_size)
	camera.set_camera_props(camera_bounds, camera_projection_offset, camera_zoom_bounds, camera_speed)
	camera.position = world.InitialMapPos
	camera.zoom = Vector2.ONE * world.InitialZoom

func load_network_grid(network_def: NetworkDefinition) -> void:
	var network_grid = map.get_drawing_layer("RoadGrid") as NetworkGrid

	await network_grid.load_network_definition(network_def)
	

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

		circle_helper.draw_debug_circle(camera.get_screen_center_position(), Color.BLUE, debug_layer, {"size": 10.0})


func _process(_delta):
	if not game_manager.is_game_initialized():
		return

	if Input.is_action_just_pressed("toggle_game_menu"):
		game_manager.toggle_game_menu()
		return
	
	if game_manager.is_game_menu_visible():
		return

	if Input.is_action_just_pressed("toggle_dev_tools"):
		ui_manager.toggle_ui_view("DebugTogglesView")
		ui_manager.toggle_ui_view("DebugIntersectionsView")
		return

	if Input.is_action_just_pressed("game_speed_0"):
		if game_manager.get_game_speed() != Enums.GameSpeed.PAUSE:
			game_manager.set_game_speed(Enums.GameSpeed.PAUSE)
		else:
			game_manager.set_game_speed(Enums.GameSpeed.LOW)
		return

	if Input.is_action_just_pressed("game_speed_1"):
		game_manager.set_game_speed(Enums.GameSpeed.LOW)
		return

	if Input.is_action_just_pressed("game_speed_2"):
		game_manager.set_game_speed(Enums.GameSpeed.MEDIUM)
		return

	if Input.is_action_just_pressed("game_speed_3"):
		game_manager.set_game_speed(Enums.GameSpeed.HIGH)
		return

	if Input.is_action_just_pressed("game_speed_4"):
		game_manager.set_game_speed(Enums.GameSpeed.TURBO)
		return

func _on_debug_toggles_changed(_name, _state) -> void:
	queue_redraw()
