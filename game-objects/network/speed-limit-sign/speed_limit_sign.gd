extends Node2D

class_name SpeedLimitSign

var speed_limit_sign = preload("res://assets/signs/speed_limit_base_sign.png")
var no_speed_limit_sign = preload("res://assets/signs/no_speed_limit_sign.png")

@onready var label: Label = $Label
@onready var sprite: Sprite2D = $Sprite

var speed_limit: int = -1  # -1 indicates no speed limit

func _ready() -> void:
	label.text = str(speed_limit)

	if speed_limit < 0:
		sprite.texture = no_speed_limit_sign
		label.visible = false
	else:
		sprite.texture = speed_limit_sign
		label.visible = true


func set_speed_limit(new_speed_limit: int) -> void:
	if new_speed_limit < 0:
		new_speed_limit = -1
	speed_limit = new_speed_limit

func set_no_speed_limit() -> void:
	speed_limit = -1
