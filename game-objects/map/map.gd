extends Node2D

class_name Map

var map_size: Vector2
var are_lights_on: bool

@onready var day_night_anim_player: AnimationPlayer = $DayNightCycle

signal world_desired_lights_state_change(new_state: bool)


func _ready() -> void:
	day_night_anim_player.play("day_night_cycle")
	day_night_anim_player.pause()


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


func clear_layers() -> void:
	for layer in $Layers.get_children():
		for child in layer.get_children():
			child.queue_free()


func update_day_progress(day_progression: float) -> void:
	day_night_anim_player.seek(day_progression * day_night_anim_player.current_animation_length, true)

	_update_world_lights_state(day_progression)


func should_world_lights_be_on(day_progression: float) -> bool:
	if day_progression >= SimulationConstants.SIMULATION_LIGHTS_ON_THRESHOLD or day_progression < SimulationConstants.SIMULATION_LIGHTS_OFF_THRESHOLD:
		return true

	if day_progression >= SimulationConstants.SIMULATION_LIGHTS_OFF_THRESHOLD:
		return false

	return false


func _update_world_lights_state(day_progression: float) -> void:
	var desired_state = should_world_lights_be_on(day_progression)
	var actual_state = are_lights_on

	if desired_state == actual_state:
		return

	if desired_state:
		are_lights_on = true
		emit_signal("world_desired_lights_state_change", are_lights_on)
	else:
		are_lights_on = false
		emit_signal("world_desired_lights_state_change", are_lights_on)
