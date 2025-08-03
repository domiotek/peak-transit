extends Node2D

var map_size: Vector2

func _draw():
	if map_size == null:
		return
		
	var rect_position = -map_size / 2
	var rect = Rect2(rect_position, map_size)
	
	draw_rect(rect, Color.WHITE_SMOKE, true)
