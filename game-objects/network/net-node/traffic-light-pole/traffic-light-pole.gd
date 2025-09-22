extends Node2D

class_name TrafficLightPole


@onready var pole: Polygon2D = $Pole

var end_position: Vector2

func _ready() -> void:
	_create_pole(end_position)

func setup(end_pos: Vector2) -> void:
	end_position = end_pos


func _create_pole(end_pos: Vector2) -> void:
	end_pos = to_local(end_pos)

	var width = 3
	var rect_points = PackedVector2Array([
		Vector2(0, 0),
		Vector2(width, 0),
		Vector2(width + end_pos.x, end_pos.y),
		Vector2(end_pos.x, end_pos.y)
	])
	pole.polygon = rect_points
