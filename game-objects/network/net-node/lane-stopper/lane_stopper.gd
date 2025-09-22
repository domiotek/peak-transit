extends Area2D

class_name LaneStopper


@onready var indicator = $DebugLayer
@onready var shape = $Shape
@onready var config_manager = GDInjector.inject("ConfigManager") as ConfigManager
@onready var network_manager = GDInjector.inject("NetworkManager") as NetworkManager

var endpoint: NetLaneEndpoint
var traffic_light: TrafficLight = null

var active: bool = false

func _ready() -> void:
	config_manager.DebugToggles.ToggleChanged.connect(_on_debug_toggles_changed)
	_on_debug_toggles_changed("", false)


func set_active(_active: bool) -> void:
	active = _active
	self.monitorable = _active
	shape.set_deferred("disabled", not _active)
	_toggle_debug_visuals()
	if traffic_light:
		traffic_light.set_state(TrafficLight.LightState.RED if _active else TrafficLight.LightState.GREEN)

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
