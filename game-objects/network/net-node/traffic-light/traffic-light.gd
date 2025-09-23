extends Node2D

class_name TrafficLight

var YELLOW_LIGHT_DURATION = 1.0

@onready var red_light: Light = $RedLightMask/RedLight
@onready var yellow_light: Light = $YellowLightMask/YellowLight
@onready var green_light: Light = $GreenLightMask/GreenLight
@onready var timer: Timer = $Timer

var current_state: Enums.TrafficLightState = Enums.TrafficLightState.INITIAL

func _ready() -> void:
	set_state(Enums.TrafficLightState.RED)
	timer.connect("timeout", Callable(self, "_on_Timer_timeout"))

func set_mask(resourcePath: String, flip: bool = false) -> void:
	$RedLightMask.texture = load(resourcePath)
	$RedLightMask.flip_h = flip
	$YellowLightMask.texture = load(resourcePath)
	$YellowLightMask.flip_h = flip
	$GreenLightMask.texture = load(resourcePath)
	$GreenLightMask.flip_h = flip

func set_state(state: Enums.TrafficLightState) -> void:
	if current_state == state:
		return

	current_state = state

	timer.stop()
	timer.wait_time = YELLOW_LIGHT_DURATION
	timer.one_shot = true
	timer.start()

	match current_state:
		Enums.TrafficLightState.RED:
			red_light.set_active(false)
			yellow_light.set_active(true)
			green_light.set_active(false)

		Enums.TrafficLightState.GREEN:
			red_light.set_active(true)
			yellow_light.set_active(true)
			green_light.set_active(false)

	
func _on_Timer_timeout() -> void:
	match current_state:
		Enums.TrafficLightState.RED:
			red_light.set_active(true)
			yellow_light.set_active(false)
			green_light.set_active(false)
			
		Enums.TrafficLightState.GREEN:
			red_light.set_active(false)
			yellow_light.set_active(false)
			green_light.set_active(true)
