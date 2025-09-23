extends Node2D

class_name ArrowTrafficLight

@onready var light: Light = $ArrowShape/Light
@onready var arrow_shape: Sprite2D = $ArrowShape

enum LightState {
	RED,
	YELLOW_TO_RED,
	YELLOW_TO_GREEN,
	GREEN
}

var current_state: LightState

func _ready() -> void:
	set_state(LightState.RED)
	arrow_shape.flip_h = true

func set_state(state: LightState) -> void:
	current_state = state
	
	match current_state:
		LightState.GREEN:
			light.set_active(true)
		_:
			light.set_active(false)
