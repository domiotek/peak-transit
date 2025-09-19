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
var owner: Vehicle = null

var current_speed: float = 0.0
var target_speed: float = 0.0
var current_brake_force: float = 0.0

var no_caster_allowance_time: float = 0.0

var constants: Dictionary = {}

var state: VehicleState = VehicleState.IDLE


var brake_light_nodes: Array = []
var casters: Dictionary = {}
var blockade_observer: Area2D

signal caster_state_changed(caster_id: String, is_colliding: bool)
signal state_changed(new_state: VehicleState)


func set_ai(used_ai) -> void:
	ai = used_ai
	constants = ai.get_constants()
	current_brake_force = constants["DEFAULT_BRAKING"]

	line_helper = GDInjector.inject("LineHelper") as LineHelper

func set_navigator(used_navigator) -> void:
	navigator = used_navigator

func set_owner(vehicle: Vehicle) -> void:
	owner = vehicle

func set_brake_lights(nodes: Array) -> void:
	brake_light_nodes = nodes

func set_casters(used_casters: Dictionary) -> void:
	casters = used_casters

func set_blockade_observer(area: Area2D) -> void:
	blockade_observer = area
	
	area.connect("area_exited", Callable(self, "_on_blockade_area_exited"))

func get_current_speed() -> float:
	return current_speed

func get_target_speed() -> float:
	return target_speed

func get_maximum_speed() -> float:
	return constants["MAX_SPEED"]

func get_state() -> VehicleState:
	return state

func get_blocking_objects() -> Array:
	if not blockade_observer.monitoring:
		return []

	if blockade_observer.get_overlapping_areas().size() > 0:
		return blockade_observer.get_overlapping_areas()

	_set_casters_enabled(true)

	var colliders = []
	for caster in casters.values():
		if caster.is_colliding():
			var collider = caster.get_collider()
			if collider:
				colliders.append(collider)

	return colliders

func emergency_stop() -> void:
	target_speed = 0.0
	current_speed = current_speed * constants["EMERGENCY_STOP_SPEED_MODIFIER"]
	current_brake_force = constants["EMERGENCY_BRAKING"]

func tick_speed(delta: float) -> float:
	target_speed = constants["MAX_SPEED"]

	_apply_slowdown_intersection()
	if no_caster_allowance_time > 0.0:
		no_caster_allowance_time -= delta
		if no_caster_allowance_time <= 0.0:
			no_caster_allowance_time = 0.0
			_set_casters_enabled(true)
	else:
		_check_for_obstacles()
		
	_update_speed(delta)

	if current_speed == 0 and target_speed == 0:
		_update_state(VehicleState.BLOCKED)
	else:
		_on_blockade_area_exited(null)

	return current_speed

func check_blockade_cleared() -> bool:
	var colliders = get_blocking_objects()
	var unblocked = false

	if colliders.size() > 0:

		for collider in colliders:
			var other_vehicle = collider.get_parent() as Vehicle

			if other_vehicle:
				var their_colliders = other_vehicle.driver.get_blocking_objects()

				for their_collider in their_colliders:
					var their_colliding_vehicle = their_collider.get_parent() as Vehicle if their_collider else null

					if not their_colliding_vehicle:
						return false 	
				
					if their_colliding_vehicle == self.owner || colliders.has(self.owner.collision_area):
						unblocked = true
						no_caster_allowance_time = 5.0
						break
			if unblocked:
				break
	else:
		unblocked = true

	if unblocked:
		blockade_observer.monitoring = false
		if no_caster_allowance_time == 0.0:
			_set_casters_enabled(true)
		state = VehicleState.IDLE

	return unblocked

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

	state_changed.emit(state)


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

	var check_if_my_blockade = func (collider: LaneStopper) -> bool:
		var my_endpoint_id = current_step["next_node"]["from"] if current_step["type"] == Navigator.StepType.SEGMENT else current_step["from_endpoint"]
		return collider.endpoint.Id == my_endpoint_id

	match caster_id:
		"close", "medium", "long":
			if casters[caster_id].is_colliding():
				var laneStopper = casters[caster_id].get_collider() as LaneStopper
				if laneStopper:
					return check_if_my_blockade.call(laneStopper)

				return true

			return false
		"left", "right":
			if casters[caster_id].is_colliding() and current_step["type"] == Navigator.StepType.NODE and current_step["is_intersection"]:
				var caster = casters[caster_id]

				var collider = caster.get_collider()
				if collider:
					var other_vehicle = collider.get_parent() as Vehicle
					if other_vehicle and line_helper.curves_intersect(current_step["path"], other_vehicle.navigator.get_current_step()["path"], 10):
						return true

					var blockade = collider as LaneStopper
					if blockade and check_if_my_blockade.call(blockade):
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
