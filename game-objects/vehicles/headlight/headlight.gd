extends Node2D

class_name Headlight

@onready var light: PointLight2D = $PointLight2D


func set_enabled(state: bool) -> void:
	light.enabled = state
