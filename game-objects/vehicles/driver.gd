extends RefCounted

class_name Driver

enum VehicleState {
	ACCELERATING,
	BRAKING,
	CRUISING,
	IDLE,
	BLOCKED
}

var CASTERS_CHECK_ORDER = ["close", "left", "right", "medium", "long"]
var MAX_BLOCK_TIME = 5.0

var line_helper: LineHelper
var vehicle_manager: VehicleManager


var ai = null
var navigator = null
var owner: Vehicle = null

var current_speed: float = 0.0
var target_speed: float = 0.0
var current_brake_force: float = 0.0

var no_caster_allowance_time: float = 0.0
var just_enabled_casters: bool = false
var casters_state: bool = false

var constants: Dictionary = {}

var state: VehicleState = VehicleState.IDLE


var brake_light_nodes: Array = []
var casters: Dictionary = {}
var blockade_observer: Area2D
var time_blocked: float = 0.0

signal caster_state_changed(caster_id: String, is_colliding: bool)
signal state_changed(new_state: VehicleState)


func set_ai(used_ai) -> void:
	ai = used_ai
	constants = ai.get_constants()
	current_brake_force = constants["DEFAULT_BRAKING"]

	line_helper = GDInjector.inject("LineHelper") as LineHelper
	vehicle_manager = GDInjector.inject("VehicleManager") as VehicleManager

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

func get_max_allowed_speed() -> float:
	var current_step = navigator.get_current_step()
	if current_step and current_step.has("max_speed") and current_step["max_speed"] != INF:
		return current_step["max_speed"]

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

func grant_no_caster_allowance(time_seconds: float) -> void:
	no_caster_allowance_time = time_seconds
	_set_casters_enabled(false)

func get_time_blocked() -> float:
	return time_blocked

func tick_speed(delta: float) -> float:
	target_speed = get_max_allowed_speed()

	_apply_slowdown_intersection()
	_apply_slowdown_building()
	
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

func check_blockade_cleared(delta: float) -> bool:
	var colliders = get_blocking_objects()

	if just_enabled_casters:
		return false

	var unblocked = false

	if state != VehicleState.BLOCKED:
		return true

	var current_step = navigator.get_current_step()

	if current_step["type"] == Navigator.StepType.NODE and current_step["is_intersection"] and time_blocked >= MAX_BLOCK_TIME:
		unblocked = true
		no_caster_allowance_time = 1.0

	var is_entering_building = current_step["type"] == Navigator.StepType.BUILDING and current_step["is_entering"]

	if not unblocked and colliders.size() > 0:
		for collider in colliders:
			var other_vehicle = vehicle_manager.get_vehicle_from_area(collider)

			if other_vehicle:
				if is_entering_building and _check_if_is_leaving_target_building(other_vehicle):
					unblocked = true
					no_caster_allowance_time = 1.0
					break

				var their_colliders = other_vehicle.driver.get_blocking_objects()

				for their_collider in their_colliders:
					var their_colliding_vehicle = vehicle_manager.get_vehicle_from_area(their_collider)

					if not their_colliding_vehicle:
						continue
				
					if their_colliding_vehicle == self.owner:
						unblocked = true
						no_caster_allowance_time = 1.0
						break

			var lane_stopper = collider as LaneStopper
			if lane_stopper && lane_stopper.is_active() && current_step["type"] == Navigator.StepType.NODE:
				unblocked = true

			var building_stopper = collider as BuildingStopper
			if building_stopper && is_entering_building:
				unblocked = true

			if unblocked:
				break
	else:
		unblocked = true

	if unblocked:
		blockade_observer.monitoring = false
		if no_caster_allowance_time == 0.0:
			_set_casters_enabled(true)
		state = VehicleState.IDLE

		_try_to_reroute(time_blocked)

		time_blocked = 0.0
	else:
		time_blocked += delta

	return unblocked

func _apply_slowdown_intersection() -> void:
	
	var current_step = navigator.get_current_step()

	if not current_step or current_step.type == Navigator.StepType.NODE or current_step["next_node"] == null:
		return

	var distance_to_node = current_step["length"] - current_step["progress"]
	var approaching_intersection = current_step["next_node"].approaching_intersection

	if approaching_intersection and distance_to_node < constants["INTERSECTION_SLOWDOWN_THRESHOLD"]:
		target_speed = constants["INTERSECTION_SLOWDOWN"]

func _apply_slowdown_building() -> void:
	var current_step = navigator.get_current_step()

	if not current_step or current_step.type != Navigator.StepType.BUILDING:
		return

	if current_step["is_entering"]:
		target_speed = constants["BUILDING_ENTRY_SPEED"]
		


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
	
	if casters[caster_id].get_collider() == null:
		return false

	var check_if_my_blockade = func (collider: LaneStopper) -> bool:
		var my_endpoint_id: int
		match current_step["type"]:
			Navigator.StepType.SEGMENT:
				my_endpoint_id = current_step["next_node"]["from"]
			Navigator.StepType.NODE:
				my_endpoint_id = current_step["from_endpoint"]

		return collider.endpoint.Id == my_endpoint_id

	var is_on_the_same_road_side = func(other_step: Dictionary) -> bool:
		var connection_details = current_step["node"].get_connection_details(current_step["from_endpoint"], current_step["to_endpoint"])

		match other_step["type"]:
			Navigator.StepType.SEGMENT:
				if connection_details["destination_segment"].id != other_step["segment_id"]:
					return false
					
				return connection_details["destination_lane"].id == other_step["lane_id"]
			Navigator.StepType.NODE:
				var other_start_segment = other_step["node"].get_connection_details(other_step["from_endpoint"], other_step["to_endpoint"])["source_segment"]
				return connection_details["source_segment"] == other_start_segment
			_:
				return true

	match caster_id:
		"close", "medium", "long":
			if casters[caster_id].is_colliding():
					
				var laneStopper = casters[caster_id].get_collider() as LaneStopper
				if laneStopper:
					return check_if_my_blockade.call(laneStopper)

				var other_vehicle = vehicle_manager.get_vehicle_from_area(casters[caster_id].get_collider())
				if other_vehicle:
					var other_vehicle_current_step = other_vehicle.navigator.get_current_step()
						
					if current_step["type"] == Navigator.StepType.NODE:
						if current_step["is_intersection"]:
							if other_vehicle_current_step["type"] == Navigator.StepType.SEGMENT:
								return false
						elif not is_on_the_same_road_side.call(other_vehicle_current_step):
							return false
						

					if current_step["type"] == Navigator.StepType.BUILDING and other_vehicle_current_step["type"] == Navigator.StepType.BUILDING:
						if _check_if_is_leaving_target_building(other_vehicle):
							return false

				var buildingStopper = casters[caster_id].get_collider() as BuildingStopper
				if buildingStopper:
					if current_step['type'] != Navigator.StepType.BUILDING or not current_step["is_leaving"]:
						return false

				return true

			return false
		"left", "right":
			if casters[caster_id].is_colliding() and current_step["type"] == Navigator.StepType.NODE and current_step["is_intersection"]:
				var caster = casters[caster_id]

				var collider = caster.get_collider()
				if collider:
					var other_vehicle = vehicle_manager.get_vehicle_from_area(collider)
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
			current_brake_force = constants["MEDIUM_BRAKING"]
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
	if enabled and not casters_state:
		just_enabled_casters = true

	casters_state = enabled

	for caster in casters.values():
		caster.set_enabled(enabled)

func _on_blockade_area_exited(_area: Area2D) -> void:
	_set_casters_enabled(true)
	blockade_observer.set_deferred("monitoring",false)
	if state == VehicleState.BLOCKED:
		state = VehicleState.IDLE
		time_blocked = 0.0

func _try_to_reroute(time_spent_blocked: float) -> void:
	var current_step = navigator.get_current_step()
	if time_spent_blocked < constants.REROUTE_THRESHOLD or current_step["type"] == Navigator.StepType.NODE:
		return

	if randf() < constants.REROUTE_CHANCE:
		navigator.reroute()

func _check_if_is_leaving_target_building(other_vehicle: Vehicle) -> bool:
	var other_step = other_vehicle.navigator.get_current_step()
	if other_step["type"] != Navigator.StepType.BUILDING:
		return false

	var vehicle_building = other_step["target_building"]
	var my_building = navigator.get_current_step()["target_building"]
	if my_building == vehicle_building:
		if vehicle_building.vehicle_leaving == other_vehicle:
			return true

	return false
