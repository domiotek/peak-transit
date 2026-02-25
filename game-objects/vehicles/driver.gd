extends RefCounted

class_name Driver

enum VehicleState {
	ACCELERATING,
	BRAKING,
	CRUISING,
	IDLE,
	BLOCKED,
}

const CASTERS_CHECK_ORDER: Array[CasterCollection.CasterID] = [
	CasterCollection.CasterID.CLOSE,
	CasterCollection.CasterID.LEFT,
	CasterCollection.CasterID.RIGHT,
	CasterCollection.CasterID.MEDIUM,
	CasterCollection.CasterID.LONG,
]
const BLOCKING_CASTERS: Array[CasterCollection.CasterID] = [
	CasterCollection.CasterID.CLOSE,
	CasterCollection.CasterID.LEFT,
	CasterCollection.CasterID.RIGHT,
]
const MAX_BLOCK_TIME = 5.0

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
var _ignore_blockades: bool = false

var constants: Dictionary = { }

var state: VehicleState = VehicleState.IDLE

var beam_light_nodes: Array[Headlight] = []
var brake_light_nodes: Array[Light] = []
var left_blinker_nodes: Array[Light] = []
var right_blinker_nodes: Array[Light] = []
var _all_blinker_nodes: Array[Light] = []
var casters: CasterCollection
var blockade_observer: Area2D
var time_blocked: float = 0.0

var _headlights_state = false
var _headlights_state_change_ticks_counter: float = 0

var _hazardous_lights_enabled: bool = false
var _blinkers_state: Enums.BlinkersState = Enums.BlinkersState.OFF
var _blinkers_state_change_ticks_counter: float = 0.0

var _stop_at_distance: float = 0.0
var _slow_down_threshold: float = 0.0
var _stop_at_callback: Callable
var _colliding_casters: Dictionary[CasterCollection.CasterID, bool] = {
	CasterCollection.CasterID.CLOSE: false,
	CasterCollection.CasterID.MEDIUM: false,
	CasterCollection.CasterID.LONG: false,
	CasterCollection.CasterID.LEFT: false,
	CasterCollection.CasterID.RIGHT: false,
}

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


func set_lights(beam_nodes: Array, brake_nodes: Array, _left_blinker_nodes: Array, _right_blinker_nodes: Array) -> void:
	beam_light_nodes = beam_nodes
	brake_light_nodes = brake_nodes
	left_blinker_nodes = _left_blinker_nodes
	right_blinker_nodes = _right_blinker_nodes
	_all_blinker_nodes.clear()
	_all_blinker_nodes.append_array(left_blinker_nodes)
	_all_blinker_nodes.append_array(right_blinker_nodes)


func set_casters(used_casters: CasterCollection) -> void:
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
	return _get_max_allowed_speed_for_step(navigator.get_current_step() as NavigationStep)


func get_state() -> VehicleState:
	return state


func get_blocking_objects() -> Array:
	if not blockade_observer.monitoring:
		return []

	var overlapping_areas := blockade_observer.get_overlapping_areas()
	if overlapping_areas.size() > 0:
		return overlapping_areas

	_set_casters_enabled(true)

	var colliders = []
	for caster_id in casters.keys():
		if caster_id not in BLOCKING_CASTERS:
			continue

		var caster := casters.get_by_id(caster_id) as RayCast2D
		if caster.is_colliding():
			var collider = caster.get_collider()
			if collider:
				colliders.append(collider)

	return colliders


func emergency_stop() -> void:
	target_speed = 0.0
	current_speed = current_speed * constants["EMERGENCY_STOP_SPEED_MODIFIER"]
	current_brake_force = constants["EMERGENCY_BRAKING"]


func stop_after_distance(distance: float, callback: Callable) -> void:
	_stop_at_distance = distance

	var max_speed = get_max_allowed_speed()

	var braking_distance = (max_speed * max_speed) / (2.0 * constants["DEFAULT_BRAKING"])
	_slow_down_threshold = distance - braking_distance
	if _slow_down_threshold < 0.0:
		_slow_down_threshold = distance

	_stop_at_callback = callback


func resume_driving() -> void:
	_stop_at_distance = 0.0
	_slow_down_threshold = 0.0
	_stop_at_callback = Callable()


func grant_no_caster_allowance(time_seconds: float) -> void:
	no_caster_allowance_time = time_seconds
	_set_casters_enabled(false)
	_on_blockade_area_exited(null)


func disable_casters() -> void:
	_ignore_blockades = true


func enable_casters() -> void:
	_ignore_blockades = false


func get_time_blocked() -> float:
	return time_blocked


func set_headlights_enabled(enabled: bool, set_instant: bool) -> void:
	if not set_instant:
		var rand_time = randi() % SimulationConstants.VEHICLE_HEADLIGHTS_STATE_CHANGE_TICKS_VARIANCE + 1
		_headlights_state_change_ticks_counter = rand_time
		return

	_headlights_state = enabled
	for beam_light in beam_light_nodes:
		beam_light.set_enabled(enabled)


func set_hazardous_lights_enabled(enabled: bool) -> void:
	_hazardous_lights_enabled = enabled


func set_blinkers_state(new_state: Enums.BlinkersState) -> void:
	_blinkers_state = new_state


func set_idle() -> void:
	current_speed = 0.0
	target_speed = 0.0
	current_brake_force = constants["DEFAULT_BRAKING"]
	_update_state(VehicleState.IDLE)


func tick_speed(delta: float, current_distance: float) -> float:
	var current_step := navigator.get_current_step() as NavigationStep
	target_speed = _get_max_allowed_speed_for_step(current_step)

	_handle_approaching_intersection(current_step)
	_handle_building_step(current_step)
	_apply_slowdown_to_distance(current_distance)

	if no_caster_allowance_time > 0.0:
		no_caster_allowance_time -= delta
		if no_caster_allowance_time <= 0.0:
			no_caster_allowance_time = 0.0
			_set_casters_enabled(true)
	else:
		_check_for_obstacles(current_step)

	_update_speed(delta)

	if current_speed == 0 and target_speed == 0:
		_update_state(VehicleState.BLOCKED if ai.can_drive() else VehicleState.IDLE)
	else:
		_on_blockade_area_exited(null)

	return current_speed


func tick_lights(delta: float) -> void:
	if _headlights_state_change_ticks_counter > 0:
		_headlights_state_change_ticks_counter -= delta
		if _headlights_state_change_ticks_counter <= 0:
			set_headlights_enabled(not _headlights_state, true)

	_handle_blinkers_state(delta)


func check_blockade_cleared(delta: float) -> bool:
	if _ignore_blockades:
		return true

	if state != VehicleState.BLOCKED:
		return true

	if just_enabled_casters:
		return false

	var unblocked := false

	var current_step := navigator.get_current_step() as NavigationStep
	var colliders := get_blocking_objects()

	if current_step.type == Navigator.StepType.NODE and current_step.is_intersection and time_blocked >= MAX_BLOCK_TIME:
		unblocked = true
		no_caster_allowance_time = 1.0

	var is_entering_building: bool = current_step.type == Navigator.StepType.BUILDING and current_step.is_entering
	var is_leaving_building: bool = current_step.type == Navigator.StepType.BUILDING and current_step.is_leaving

	if not unblocked and colliders.size() > 0:
		for collider in colliders:
			var other_vehicle := vehicle_manager.get_vehicle_from_area(collider)

			if other_vehicle:
				if is_entering_building and _check_if_is_leaving_target_building(other_vehicle, current_step as BuildingNavigationStep):
					unblocked = true
					no_caster_allowance_time = 1.0
					break

				var their_colliders := other_vehicle.driver.get_blocking_objects()

				for their_collider in their_colliders:
					var their_colliding_vehicle := vehicle_manager.get_vehicle_from_area(their_collider)

					if not their_colliding_vehicle:
						continue

					if their_colliding_vehicle == self.owner:
						unblocked = true
						no_caster_allowance_time = 1.0
						break

			var lane_stopper := collider as LaneStopper
			if lane_stopper && lane_stopper.is_active() && current_step.type == Navigator.StepType.NODE:
				unblocked = true

			var building_stopper := collider as BuildingStopper
			if building_stopper && not is_leaving_building:
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


func _handle_approaching_intersection(current_step: NavigationStep) -> void:
	if not current_step or current_step.type != Navigator.StepType.SEGMENT or current_step.next_node == null:
		return

	var distance_to_node := current_step.length - current_step.progress
	var approaching_intersection: bool = current_step.next_node.is_intersection

	if approaching_intersection and distance_to_node < constants["INTERSECTION_SLOWDOWN_THRESHOLD"]:
		var direction: Enums.Direction = current_step.next_node.direction

		match direction:
			Enums.Direction.LEFT:
				target_speed = constants["INTERSECTION_SLOWDOWN"]
				set_blinkers_state(Enums.BlinkersState.LEFT)
				return
			Enums.Direction.RIGHT:
				target_speed = constants["INTERSECTION_SLOWDOWN"]
				set_blinkers_state(Enums.BlinkersState.RIGHT)
				return

	set_blinkers_state(Enums.BlinkersState.OFF)


func _handle_building_step(current_step: NavigationStep) -> void:
	if not current_step or current_step.type != Navigator.StepType.BUILDING:
		return

	var is_opposite_relation: bool = current_step.connection.is_opposite_relation
	var is_entering: bool = current_step.is_entering

	if is_entering:
		target_speed = constants["BUILDING_ENTRY_SPEED"]

	set_blinkers_state(Enums.BlinkersState.LEFT if is_opposite_relation else Enums.BlinkersState.RIGHT)


func _apply_slowdown_to_distance(current_distance: float) -> void:
	if _stop_at_distance <= 0.0:
		return

	var distance_remaining = _stop_at_distance - current_distance

	if distance_remaining <= 0.0:
		target_speed = 0.0
		if _stop_at_callback:
			_stop_at_callback.call_deferred()
			_stop_at_callback = Callable()
	elif distance_remaining <= _slow_down_threshold:
		var max_speed = get_max_allowed_speed()
		var required_speed = sqrt(2.0 * constants["DEFAULT_BRAKING"] * distance_remaining)
		target_speed = min(required_speed, max_speed)


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
	if state == vehicle_state:
		return

	state = vehicle_state

	match state:
		VehicleState.ACCELERATING, VehicleState.CRUISING:
			for light in brake_light_nodes:
				light.set_active(false)
		VehicleState.BRAKING:
			for light in brake_light_nodes:
				light.set_active(true)
		VehicleState.BLOCKED:
			_set_casters_enabled(false)
			blockade_observer.monitoring = true

	state_changed.emit(state)


func _check_for_obstacles(current_step: NavigationStep) -> void:
	if _ignore_blockades:
		return

	var colliding_casters = _get_colliding_casters(current_step)

	for caster_id in CASTERS_CHECK_ORDER:
		if colliding_casters[caster_id]:
			_apply_caster_colliding(caster_id, colliding_casters)
			return

	if target_speed == 0:
		current_brake_force = constants["DEFAULT_BRAKING"]


func _get_colliding_casters(current_step: NavigationStep) -> Dictionary[CasterCollection.CasterID, bool]:
	_colliding_casters[CasterCollection.CasterID.CLOSE] = false
	_colliding_casters[CasterCollection.CasterID.MEDIUM] = false
	_colliding_casters[CasterCollection.CasterID.LONG] = false
	_colliding_casters[CasterCollection.CasterID.LEFT] = false
	_colliding_casters[CasterCollection.CasterID.RIGHT] = false

	if not current_step:
		return _colliding_casters

	var casters_to_check = casters.get_in_check_order()

	if current_step.type == Navigator.StepType.NODE and current_step.is_intersection:
		for idx in range(0, 2):
			var caster = casters_to_check[idx]
			if not caster.is_colliding():
				continue
			var collider := caster.get_collider()

			if not collider:
				continue

			var other_vehicle: Vehicle = vehicle_manager.get_vehicle_from_area(collider)
			var other_vehicle_current_step := other_vehicle.navigator.get_current_step() as NavigationStep if other_vehicle else null

			_colliding_casters[CASTERS_CHECK_ORDER[idx]] = _check_angled_caster(collider, current_step, other_vehicle, other_vehicle_current_step)

	for idx in range(2, casters_to_check.size()):
		var caster = casters_to_check[idx]
		if not caster.is_colliding():
			continue
		var collider = caster.get_collider()
		if not collider:
			continue

		var other_vehicle: Vehicle = vehicle_manager.get_vehicle_from_area(collider)
		var other_vehicle_current_step := other_vehicle.navigator.get_current_step() as NavigationStep if other_vehicle else null

		_colliding_casters[CASTERS_CHECK_ORDER[idx]] = _check_forward_caster(collider, current_step, other_vehicle, other_vehicle_current_step)

	return _colliding_casters


func _get_max_allowed_speed_for_step(current_step: NavigationStep) -> float:
	if current_step and current_step.max_speed != INF:
		return current_step.max_speed

	return constants["MAX_SPEED"] if ai.can_drive() else 0.0


func _check_forward_caster(target_collider: Object, current_step: NavigationStep, other_vehicle: Vehicle, other_vehicle_current_step: NavigationStep) -> bool:
	var my_endpoint_id: int = -1

	if current_step.type == Navigator.StepType.SEGMENT:
		my_endpoint_id = current_step.next_node.from
	elif current_step.type == Navigator.StepType.NODE:
		my_endpoint_id = current_step.from_endpoint

	var lane_stopper := target_collider as LaneStopper
	if lane_stopper:
		return lane_stopper.endpoint.Id == my_endpoint_id

	if other_vehicle:
		if current_step.type == Navigator.StepType.NODE:
			if current_step.is_intersection:
				if other_vehicle_current_step.type == Navigator.StepType.SEGMENT:
					return false
			else:
				var connection_details = current_step.node.get_connection_details(current_step.from_endpoint, current_step.to_endpoint)

				match other_vehicle_current_step.type:
					Navigator.StepType.SEGMENT:
						if connection_details["destination_segment"].id != other_vehicle_current_step.segment_id:
							return false

						return connection_details["destination_lane"].id == other_vehicle_current_step.lane_id
					Navigator.StepType.NODE:
						var other_start_segment = other_vehicle_current_step.node.get_connection_details(
							other_vehicle_current_step.from_endpoint,
							other_vehicle_current_step.to_endpoint,
						)["source_segment"]
						return connection_details["source_segment"] == other_start_segment
					_:
						return true

		if current_step.type == Navigator.StepType.BUILDING and other_vehicle_current_step.type == Navigator.StepType.BUILDING:
			if _check_if_is_leaving_target_building(other_vehicle, current_step as BuildingNavigationStep):
				return false

	var building_stopper := target_collider as BuildingStopper
	if building_stopper:
		if current_step.type != Navigator.StepType.BUILDING or not current_step.is_leaving:
			return false

	return true


func _check_angled_caster(target_collider: Object, current_step: NavigationStep, other_vehicle: Vehicle, other_vehicle_current_step: NavigationStep) -> bool:
	if other_vehicle and line_helper.curves_intersect(current_step.path, other_vehicle_current_step.path, 10):
		return true

	var blockade := target_collider as LaneStopper
	if blockade and blockade.endpoint.Id == current_step.from_endpoint:
		return true

	return false


func _apply_caster_colliding(caster_id: CasterCollection.CasterID, colliding_casters: Dictionary) -> void:
	match caster_id:
		CasterCollection.CasterID.CLOSE:
			target_speed = 0.0
			current_brake_force = (constants["CLOSE_BRAKING"]
				if current_speed < constants["CLOSE_BRAKING_LOW_SPEED_THRESHOLD"]
				else constants["EMERGENCY_BRAKING"] )
		CasterCollection.CasterID.MEDIUM:
			target_speed = max(constants["MEDIUM_CASTER_MIN_SPEED"], target_speed * constants["MEDIUM_CASTER_SPEED_MODIFIER"])
			current_brake_force = constants["MEDIUM_BRAKING"]
		CasterCollection.CasterID.LONG:
			target_speed = max(constants["LONG_CASTER_MIN_SPEED"], target_speed * constants["LONG_CASTER_SPEED_MODIFIER"])
			current_brake_force = constants["LIGHT_BRAKING"]
		CasterCollection.CasterID.LEFT, CasterCollection.CasterID.RIGHT:
			var any_forward_caster = (colliding_casters[CasterCollection.CasterID.CLOSE]
				or colliding_casters[CasterCollection.CasterID.MEDIUM]
				or colliding_casters[CasterCollection.CasterID.LONG] )

			target_speed = constants["TURN_CRAWL_SPEED"] if not any_forward_caster else 0
			current_brake_force = constants["EMERGENCY_BRAKING"]
		_:
			push_error("Unknown caster ID: %s" % caster_id)


func _set_casters_enabled(enabled: bool) -> void:
	if casters_state == enabled:
		return

	if enabled and not casters_state:
		just_enabled_casters = true

	casters_state = enabled

	casters.set_all_enabled(enabled)


func _on_blockade_area_exited(_area: Area2D) -> void:
	_set_casters_enabled(true)
	blockade_observer.set_deferred("monitoring", false)
	if state == VehicleState.BLOCKED:
		state = VehicleState.IDLE
		time_blocked = 0.0


func _try_to_reroute(time_spent_blocked: float) -> void:
	var current_step := navigator.get_current_step() as NavigationStep
	if time_spent_blocked < constants.REROUTE_THRESHOLD or current_step.type == Navigator.StepType.NODE:
		return

	if randf() < constants.REROUTE_CHANCE:
		navigator.reroute()


func _check_if_is_leaving_target_building(other_vehicle: Vehicle, my_step: BuildingNavigationStep = null) -> bool:
	var other_step := other_vehicle.navigator.get_current_step() as NavigationStep
	if other_step.type != Navigator.StepType.BUILDING:
		return false

	if my_step == null:
		my_step = navigator.get_current_step() as BuildingNavigationStep

	if my_step == null:
		return false

	var vehicle_building := other_step.target_building as BaseBuilding
	var my_building := my_step.target_building as BaseBuilding
	if my_building == vehicle_building:
		if vehicle_building.vehicle_leaving == other_vehicle:
			return true

	return false


func _handle_blinkers_state(delta: float) -> void:
	if delta <= 0.0:
		return

	if _blinkers_state == Enums.BlinkersState.OFF and not _hazardous_lights_enabled:
		_blinkers_state_change_ticks_counter = SimulationConstants.VEHICLE_BLINKERS_STATE_CHANGE_TICKS_OFFSET
		_toggle_blinkers_active(_all_blinker_nodes, false)
		return

	var target_blinkers: Array = _all_blinker_nodes if _hazardous_lights_enabled else []

	if not _hazardous_lights_enabled:
		match _blinkers_state:
			Enums.BlinkersState.LEFT:
				target_blinkers = left_blinker_nodes
			Enums.BlinkersState.RIGHT:
				target_blinkers = right_blinker_nodes

	_blinkers_state_change_ticks_counter -= delta
	if _blinkers_state_change_ticks_counter <= 0.0:
		_blinkers_state_change_ticks_counter = SimulationConstants.VEHICLE_BLINKERS_STATE_CHANGE_TICKS_OFFSET
		_toggle_blinkers_active(target_blinkers)


func _toggle_blinkers_active(target_blinkers: Array, force_state = null) -> void:
	var active = force_state if force_state != null else not target_blinkers[0].is_active if target_blinkers.size() > 0 else false

	for blinker in target_blinkers:
		blinker.set_active(active)
