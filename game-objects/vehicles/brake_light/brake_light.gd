extends Node2D

class_name BrakeLight

@export var inactive_color: Color = Color(0.2, 0, 0)
@export var active_color: Color = Color(1, 0, 0)
@export var radius: float = 1.0
@export var segments: int = 16

var is_active: bool = false
var polygon: Polygon2D

func _ready() -> void:
	polygon = Polygon2D.new()
	add_child(polygon)
	
	var points: PackedVector2Array = []
	for i in range(segments):
		var angle = i * 2.0 * PI / segments
		points.append(Vector2(cos(angle) * radius, sin(angle) * radius))
	
	polygon.polygon = points
	polygon.color = inactive_color

func set_active(active: bool) -> void:
	if is_active != active:
		is_active = active
		if polygon:
			polygon.color = active_color if is_active else inactive_color
