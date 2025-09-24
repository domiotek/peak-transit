extends Node2D

class_name ArrowTrafficLight

@onready var light: Light = $ArrowShape/Light
@onready var arrow_shape: Sprite2D = $ArrowShape

var current_state: Enums.TrafficLightState

func _ready() -> void:
	set_state(Enums.TrafficLightState.RED)
	arrow_shape.flip_h = true

func set_state(state: Enums.TrafficLightState) -> void:
	current_state = state
	
	match current_state:
		Enums.TrafficLightState.GREEN:
			light.set_active(true)
		_:
			light.set_active(false)
