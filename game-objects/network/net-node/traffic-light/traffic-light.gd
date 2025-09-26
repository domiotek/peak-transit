extends Node2D

class_name TrafficLight

var YELLOW_LIGHT_DURATION = 1.0

var ARROW_ICON = preload("res://assets/ui_icons/traffic_light_arrow.png")
	
enum MaskOrientation {
	TOP,
	LEFT,
	RIGHT,
}

@onready var red_light: Light = $RedLightMask/RedLight
@onready var yellow_light: Light = $YellowLightMask/YellowLight
@onready var green_light: Light = $GreenLightMask/GreenLight
@onready var timer: Timer = $Timer

var current_state: Enums.TrafficLightState = Enums.TrafficLightState.INITIAL

func _ready() -> void:
	set_state(Enums.TrafficLightState.RED)
	timer.connect("timeout", Callable(self, "_on_Timer_timeout"))

func show_mask(orientation: MaskOrientation) -> void:
	$RedLightMask.texture = ARROW_ICON
	_set_orientation($RedLightMask, orientation)
	$YellowLightMask.texture = ARROW_ICON
	_set_orientation($YellowLightMask, orientation)
	$GreenLightMask.texture = ARROW_ICON
	_set_orientation($GreenLightMask, orientation)

func hide_mask() -> void:
	$RedLightMask.texture = null
	$YellowLightMask.texture = null
	$GreenLightMask.texture = null

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

func _set_orientation(light: Sprite2D, orientation: MaskOrientation) -> void:
	match orientation:
		MaskOrientation.TOP:
			light.rotation_degrees = 90
			light.flip_h = false
		MaskOrientation.LEFT:
			light.rotation_degrees = 0
			light.flip_h = false
		MaskOrientation.RIGHT:
			light.rotation_degrees = 0
			light.flip_h = true
