extends Node2D

class_name TrafficLight

@onready var red_light: Light = $RedLight
@onready var yellow_light: Light = $YellowLight
@onready var green_light: Light = $GreenLight

enum LightState {
	RED,
	YELLOW,
	GREEN
}

var current_state: LightState


func _ready() -> void:
	set_state(LightState.RED)

func set_state(state: LightState) -> void:
	current_state = state
	
	match current_state:
		LightState.RED:
			red_light.set_active(true)
			yellow_light.set_active(false)
			green_light.set_active(false)
		LightState.YELLOW:
			red_light.set_active(false)
			yellow_light.set_active(true)
			green_light.set_active(false)
		LightState.GREEN:
			red_light.set_active(false)
			yellow_light.set_active(false)
			green_light.set_active(true)
