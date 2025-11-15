extends Node2D

class_name Map

var map_size: Vector2
var day_night_cycle_enabled: bool
var are_lights_on: bool

@onready var day_night_anim_player: AnimationPlayer = $DayNightCycle

signal lights_state_change(new_state: bool)


func _ready() -> void:
	day_night_anim_player.play("day_night_cycle")
	day_night_anim_player.pause()
	day_night_cycle_enabled = false


func _draw():
	if map_size == null:
		return

	var rect_position = -map_size / 2
	var rect = Rect2(rect_position, map_size)

	draw_rect(rect, Color.WHITE_SMOKE, true)


func get_drawing_layer(layer_name: String) -> Node2D:
	var layer = $Layers.get_node(layer_name) as Node2D

	if layer == null:
		push_error("Map layer with name %s not found." % layer_name)
		return null

	return layer


func clear_drawing_layer(layer_name: String) -> void:
	var layer = get_drawing_layer(layer_name)
	if layer == null:
		return

	for child in layer.get_children():
		child.queue_free()


func enable_day_night_cycle(enable: bool, day_progression: float = 0.0) -> void:
	update_day_progress(day_progression if enable else 0.5)
	day_night_cycle_enabled = enable


func update_day_progress(day_progression: float) -> void:
	if not day_night_cycle_enabled:
		return

	day_night_anim_player.seek(day_progression * day_night_anim_player.current_animation_length, true)

	_check_lights_state(day_progression)


func _check_lights_state(day_progression: float) -> void:
	if day_progression >= SimulationConstants.SIMULATION_LIGTHTS_ON_THRESHOLD and not are_lights_on:
		are_lights_on = true
		emit_signal("lights_state_change", are_lights_on)
	elif day_progression < SimulationConstants.SIMULATION_LIGTHTS_OFF_THRESHOLD and are_lights_on:
		are_lights_on = false
		emit_signal("lights_state_change", are_lights_on)
