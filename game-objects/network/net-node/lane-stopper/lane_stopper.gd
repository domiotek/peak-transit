extends Area2D

class_name LaneStopper

var YELLOW_LIGHT_DURATION = 1.0


@onready var indicator = $DebugLayer
@onready var shape = $Shape
@onready var config_manager = GDInjector.inject("ConfigManager") as ConfigManager
@onready var network_manager = GDInjector.inject("NetworkManager") as NetworkManager

var endpoint: NetLaneEndpoint
var traffic_lights: Dictionary

var active: bool = false

func _ready() -> void:
	config_manager.DebugToggles.ToggleChanged.connect(_on_debug_toggles_changed)
	_on_debug_toggles_changed("", false)


func set_active(_active: bool) -> void:
	active = _active
	self.monitorable = _active
	shape.set_deferred("disabled", not _active)
	_toggle_debug_visuals()

func set_active_with_light(_active: bool, directions: Array) -> void:
	var left_signaler = traffic_lights.get(Enums.Direction.LEFT, null)
	var right_signaler = traffic_lights.get(Enums.Direction.RIGHT, null)
	var default_signaler = traffic_lights.get(Enums.Direction.ALL_DIRECTIONS, null)


	var light = default_signaler
	var other_lights = [left_signaler, right_signaler]

	var has_left = directions.has(Enums.Direction.LEFT)
	var has_right = directions.has(Enums.Direction.RIGHT)

	if has_left and left_signaler:
		light = left_signaler
		other_lights.erase(left_signaler)
		other_lights.append(default_signaler)
	elif has_right and right_signaler and directions.size() == 1:
		light = right_signaler
		other_lights.erase(right_signaler)
		other_lights.append(default_signaler)

	if light:
		light.set_state(Enums.TrafficLightState.RED if _active else Enums.TrafficLightState.GREEN)

		for other_light in other_lights:
			if other_light:
				other_light.set_state(Enums.TrafficLightState.RED)

	set_active(_active)

func is_active() -> bool:
	return active

func get_lane() -> NetLane:
	return network_manager.get_segment(endpoint.SegmentId).get_lane(endpoint.LaneId)

func _toggle_debug_visuals() -> void:
	indicator.color = Color(1, 0, 0, 0.5) if active else Color(0, 1, 0, 0.5)

func _on_debug_toggles_changed(_id: String, _state: bool) -> void:
	if config_manager.DebugToggles.DrawIntersectionStoppers:
		indicator.visible = true
	else:
		indicator.visible = false
