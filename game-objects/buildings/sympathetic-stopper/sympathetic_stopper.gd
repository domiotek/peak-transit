extends Area2D

class_name SympatheticStopper


@onready var shape: CollisionShape2D = $CollisionShape
@onready var indicator: Polygon2D= $DebugShape

var active: bool = false

func _ready() -> void:
	set_active(active)
	_toggle_debug_visuals()

func set_active(_active: bool) -> void:
	active = _active
	self.monitorable = _active
	shape.set_deferred("disabled", not _active)
	_toggle_debug_visuals()

func _toggle_debug_visuals() -> void:
	indicator.color = Color(1, 0, 0, 0.5) if active else Color(0, 1, 0, 0.5)
