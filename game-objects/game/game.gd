extends Node2D

@onready var camera: Camera2D = $Camera
@onready var debug_layer: Node2D = $DebugLayer

var ui_manager: UIManager
var config_manager: ConfigManager
var game_manager: GameManager
var circle_helper: DebugCircleHelper

func _ready() -> void:
	game_manager = GDInjector.inject("GameManager") as GameManager
	config_manager = GDInjector.inject("ConfigManager") as ConfigManager
	ui_manager = GDInjector.inject("UIManager") as UIManager

	game_manager.initialize($Map, camera)

	config_manager.DebugToggles.ToggleChanged.connect(_on_debug_toggles_changed)

func _draw() -> void:
	for child in debug_layer.get_children():
		child.queue_free()

	if config_manager.DebugToggles.DrawCameraBounds:
		var camera_bounds = game_manager.get_camera_bounds()
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
