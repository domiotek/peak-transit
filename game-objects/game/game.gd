extends Node2D

var camera_bounds: Rect2
@export var camera_projection_offset := Vector2(2, 1.35)
@export var camera_speed := 500.0
@export var camera_zoom_bounds: Array[Vector2] = [Vector2(0.5, 0.5), Vector2(6, 6)]
@export var map_size := Vector2(5000, 5000)

@onready var camera: Camera2D = $Camera

func _ready() -> void:
	$Map.map_size = map_size
	var rect_position = -map_size / 2
	camera_bounds = Rect2(rect_position, map_size)
	camera.set_camera_props(camera_bounds, camera_projection_offset, camera_zoom_bounds, camera_speed)

	
func _draw() -> void:
	var config_manager = GDInjector.inject("ConfigManager") as ConfigManager
	if config_manager.DrawCameraBounds:
		draw_rect(camera_bounds, Color.RED,false, 2, true)
		draw_circle(camera.get_screen_center_position(), 10, Color.BLUE, true, -1, true)
