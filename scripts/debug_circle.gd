class DebugCircle extends Node2D:
	var radius: float = 10.0
	var color: Color = Color.RED
	var circle_position: Vector2 = Vector2.ZERO
	
	func _draw():
		draw_circle(circle_position, radius, color)