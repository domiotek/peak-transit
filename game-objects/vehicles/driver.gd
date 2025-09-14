extends RefCounted

class_name Driver

var navigator_module = load("res://game-objects/vehicles/navigator.gd")

enum VehicleState {
	ACCELERATING,
	BRAKING,
	CRUISING,
	IDLE,
	BLOCKED
}

var CASTERS_CHECK_ORDER = ["close", "left", "right", "medium", "long"]

var line_helper: LineHelper


var ai = null
var navigator = null

var current_speed: float = 0.0
var target_speed: float = 0.0
var current_brake_force: float = 0.0

var constants: Dictionary = {}

var state: VehicleState = VehicleState.IDLE


var brake_light_nodes: Array = []
var casters: Dictionary = {}
var blockade_observer: Area2D

signal caster_state_changed(caster_id: String, is_colliding: bool)


func set_ai(used_ai) -> void:
	ai = used_ai
	constants = ai.get_constants()
	current_brake_force = constants["DEFAULT_BRAKING"]

	line_helper = GDInjector.inject("LineHelper") as LineHelper

func set_navigator(used_navigator) -> void:
	navigator = used_navigator

func set_brake_lights(nodes: Array) -> void:
	brake_light_nodes = nodes

func set_casters(used_casters: Dictionary) -> void:
	casters = used_casters

func set_blockade_observer(area: Area2D) -> void:
	blockade_observer = area
	
	area.connect("area_exited", Callable(self, "_on_blockade_area_exited"))

func get_target_speed() -> float:
	return target_speed

func emergency_stop() -> void:
	target_speed = 0.0
	current_speed = current_speed * constants["EMERGENCY_STOP_SPEED_MODIFIER"]
	current_brake_force = constants["EMERGENCY_BRAKING"]

func tick_speed(delta: float) -> float:
	target_speed = constants["MAX_SPEED"]

	_apply_slowdown_intersection()
	_check_for_obstacles()
	_update_speed(delta)

	if current_speed == 0 and target_speed == 0 and state == VehicleState.BRAKING:
		_update_state(VehicleState.BLOCKED)
	else:
		_on_blockade_area_exited(null)

	return current_speed

func check_blockade_cleared() -> bool:
	if blockade_observer.get_overlapping_areas().size() > 0:
		return false

	blockade_observer.monitoring = false
	_set_casters_enabled(true)
	state = VehicleState.IDLE

	return true

func _apply_slowdown_intersection() -> void:
	
	var current_step = navigator.get_current_step()

	if not current_step or current_step.type == Navigator.StepType.NODE or current_step["next_node"] == null:
		return

	var distance_to_node = current_step["length"] - current_step["progress"]
	var approaching_intersection = current_step["next_node"].approaching_intersection

	if approaching_intersection and distance_to_node < constants["INTERSECTION_SLOWDOWN_THRESHOLD"]:
		target_speed = constants["INTERSECTION_SLOWDOWN"]


func _update_speed(delta: float) -> void:
	var speed_difference = target_speed - current_speed

	if abs(speed_difference) == 0:
		_update_state(VehicleState.CRUISING)
		return
	
	if speed_difference > 0:
		_update_state(VehicleState.ACCELERATING)
		current_speed += constants["ACCELERATION"] * delta
		current_speed = min(current_speed, target_speed)
	else:
		_update_state(VehicleState.BRAKING)
		current_speed -= current_brake_force * delta
		current_speed = max(current_speed, target_speed)
	
	current_speed = clamp(current_speed, 0.0, constants["MAX_SPEED"])



func _update_state(vehicle_state: VehicleState) -> void:
	state = vehicle_state

	var update_brake_lights = func(light_state: bool) -> void:
		for light in brake_light_nodes:
			light.set_active(light_state)

	match state:
		VehicleState.ACCELERATING, VehicleState.CRUISING:
			update_brake_lights.call(false)
		VehicleState.BRAKING:
			update_brake_lights.call(true)
		VehicleState.BLOCKED:
			_set_casters_enabled(false)
			blockade_observer.monitoring = true


func _check_for_obstacles() -> void:
	var colliding_casters = _get_colliding_casters()

	for caster_id in CASTERS_CHECK_ORDER:
		if colliding_casters[caster_id]:
			_apply_caster_colliding(caster_id, colliding_casters)
			return

	if target_speed == 0:
		current_brake_force = constants["DEFAULT_BRAKING"]


func _get_colliding_casters() -> Dictionary:
	var colliding = {}

	for caster_id in CASTERS_CHECK_ORDER:
		var caster_state = _check_caster_colliding(caster_id)
		colliding[caster_id] = caster_state
		emit_signal("caster_state_changed", caster_id, caster_state)

	return colliding

func _check_caster_colliding(caster_id: String) -> bool:
	var current_step = navigator.get_current_step()

	match caster_id:
		"close":
			return casters["close"].is_colliding()
		"medium":
			return casters["medium"].is_colliding()
		"long":
			return casters["long"].is_colliding()
		"left", "right":
			if casters[caster_id].is_colliding() and current_step["type"] == Navigator.StepType.NODE and current_step["is_intersection"]:
				var caster = casters[caster_id]

				var collider = caster.get_collider()
				if collider:
					var other_vehicle = collider.get_parent() as Vehicle
					if line_helper.curves_intersect(current_step["path"], other_vehicle.navigator.get_current_step()["path"], 10):
						return true

			return false

	push_error("Unknown caster ID: %s" % caster_id)
	return false

func _apply_caster_colliding(caster_id: String, colliding_casters: Dictionary) -> void:
	match caster_id:
		"close":
			target_speed = 0.0
			current_brake_force = constants["EMERGENCY_BRAKING"]
		"medium":
			target_speed = max(constants["MEDIUM_CASTER_MIN_SPEED"], target_speed * constants["MEDIUM_CASTER_SPEED_MODIFIER"])
			current_brake_force = constants["MEDIUM_BRAKING"]
		"long":
			target_speed = max(constants["LONG_CASTER_MIN_SPEED"], target_speed * constants["LONG_CASTER_SPEED_MODIFIER"])
			current_brake_force = constants["LIGHT_BRAKING"]
		"left", "right":
			var any_forward_caster = colliding_casters["close"] or colliding_casters["medium"] or colliding_casters["long"]
			target_speed = constants["TURN_CRAWL_SPEED"] if not any_forward_caster else 0
			current_brake_force = constants["EMERGENCY_BRAKING"]
		_:
			push_error("Unknown caster ID: %s" % caster_id)

func _set_casters_enabled(enabled: bool) -> void:
	for caster in casters.values():
		caster.set_enabled(enabled)

func _on_blockade_area_exited(_area: Area2D) -> void:
	_set_casters_enabled(true)
	blockade_observer.set_deferred("monitoring",false)
	state = VehicleState.IDLE
