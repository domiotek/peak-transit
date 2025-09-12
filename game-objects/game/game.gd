extends Node2D

var camera_bounds: Rect2
@export var camera_projection_offset := Vector2(2, 1.35)
@export var camera_speed := 500.0
@export var camera_zoom_bounds: Array[Vector2] = [Vector2(0.5, 0.5), Vector2(6, 6)]
@export var map_size := Vector2(5000, 5000)
@export var initial_map_pos = Vector2(150, 900)

@onready var camera: Camera2D = $Camera
@onready var debug_layer: Node2D = $DebugLayer

var ui_manager: UIManager
var config_manager: ConfigManager
var circle_helper: DebugCircleHelper

func _ready() -> void:
	ui_manager = GDInjector.inject("UIManager") as UIManager
	config_manager = GDInjector.inject("ConfigManager") as ConfigManager
	circle_helper = GDInjector.inject("DebugCircleHelper") as DebugCircleHelper

	$Map.map_size = map_size
	var rect_position = -map_size / 2
	camera_bounds = Rect2(rect_position, map_size)
	camera.set_camera_props(camera_bounds, camera_projection_offset, camera_zoom_bounds, camera_speed)
	camera.position = initial_map_pos

	var simulation_manager = GDInjector.inject("SimulationManager") as SimulationManager
	var vehicle_manager = GDInjector.inject("VehicleManager") as VehicleManager

	vehicle_manager.set_vehicles_layer($Map.get_drawing_layer("VehiclesLayer"))

	simulation_manager.start_simulation()

	config_manager.DebugToggles.ToggleChanged.connect(_on_debug_toggles_changed)

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
	if Input.is_action_just_pressed("toggle_dev_tools"):
		ui_manager.toggle_ui_view("DebugTogglesView")

func _on_debug_toggles_changed(_name, _state) -> void:
	queue_redraw()
