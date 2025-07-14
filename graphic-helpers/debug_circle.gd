class_name DebugCircleHelper


class DebugCircle extends Node2D:
	var radius: float = 10.0
	var color: Color = Color.RED
	
	func _draw():
		draw_circle(Vector2.ZERO, radius, color)

func _draw_debug_circle(point: Vector2, color: Color, layer: Node2D) -> void:
	var circle = DebugCircle.new()
	circle.z_index = 15
	circle.radius = 6.0
	circle.color = color
	circle.position = point
	
	layer.add_child(circle)