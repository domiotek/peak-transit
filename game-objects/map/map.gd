extends Node2D

class_name Map

var map_size: Vector2

func _draw():
	if map_size == null:
		return
		
	var rect_position = -map_size / 2
	var rect = Rect2(rect_position, map_size)
	
	draw_rect(rect, Color.WHITE_SMOKE, true)



func get_drawing_layer(layer_name: String) -> Node2D:
	var layer = $Layers.get_node(layer_name) as Node2D

	if layer == null:
		push_error("Map layer with name %s not found." % layer_name)
		return null

	return layer
