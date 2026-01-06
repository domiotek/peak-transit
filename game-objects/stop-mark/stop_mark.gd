extends Node2D

class_name StopMark

@onready var outer: Light = $Outer
@onready var inner: Light = $Inner

var _color: Color


func _ready() -> void:
	outer.radius = 4.0
	outer.inactive_color = _color
	inner.radius = 3.0
	inner.inactive_color = _color.lerp(Color.WHITE, 0.9)
	outer.redraw()
	inner.redraw()


func setup(color: Color) -> void:
	_color = color
