extends Node2D

class_name Light

@export var inactive_color: Color = Color(0, 0, 0)
@export var active_color: Color = Color(1, 1, 1)
@export var radius: float = 1.0
@export var segments: int = 16
@export var light_energy: float = 15.0
@export var ilumination_scale: float = 1.0

@onready var light = $PointLight2D

var is_active: bool = false
var illumination_enabled: bool = false
var polygon: Polygon2D


func _ready() -> void:
	polygon = Polygon2D.new()
	add_child(polygon)

	var points: PackedVector2Array = []
	for i in range(segments):
		var angle = i * 2.0 * PI / segments
		points.append(Vector2(cos(angle) * radius, sin(angle) * radius))

	polygon.polygon = points
	polygon.color = inactive_color
	light.energy = light_energy
	light.color = active_color
	light.texture_scale = ilumination_scale
	var simulation_manager = GDInjector.inject("SimulationManager")

	simulation_manager.desired_world_lights_state_changed.connect(Callable(self, "_on_desired_world_lights_state_changed"))
	illumination_enabled = simulation_manager.get_desired_world_lights_state()


func set_active(active: bool) -> void:
	if is_active != active:
		is_active = active
		if polygon:
			polygon.color = active_color if is_active else inactive_color

		if light:
			light.enabled = is_active and illumination_enabled


func _on_desired_world_lights_state_changed(new_state: bool) -> void:
	illumination_enabled = new_state

	if light:
		light.enabled = is_active and illumination_enabled
