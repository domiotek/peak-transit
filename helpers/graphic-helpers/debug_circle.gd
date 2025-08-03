class_name DebugCircleHelper


class DebugCircle extends Node2D:
	var radius: float = 10.0
	var color: Color = Color.RED
	
	func _draw():
		draw_circle(Vector2.ZERO, radius, color)

func draw_debug_circle(point: Vector2, color: Color, layer: Node2D, options: Dictionary) -> void:
	var circle = DebugCircle.new()
	circle.z_index = options.get("zIndex", 15)
	circle.radius = options.get("size", 10.0)
	circle.color = color
	circle.position = point

	if options.get("text", "") != "":
		var label = Label.new()
		label.z_index = options.get("zIndex", 15) + 1
		label.text = options.get("text", "")
		label.position = point
		label.set("custom_colors/font_color", options.get("textColor", Color.WHITE))
		layer.add_child(label)

	
	layer.add_child(circle)
