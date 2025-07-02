class_name DebugCircleHelper


class DebugCircle extends Node2D:
	var radius: float = 10.0
	var color: Color = Color.RED
	var circle_position: Vector2 = Vector2.ZERO
	
	func _draw():
		draw_circle(circle_position, radius, color)

func _draw_debug_circle(point: Vector2, color: Color, layer: Node2D) -> void:
	var circle = DebugCircle.new()
	circle.z_index = 5
	circle.radius = 6.0
	circle.color = color
	circle.position = point
	
	layer.add_child(circle)