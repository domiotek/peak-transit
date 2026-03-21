extends RefCounted

class_name NullIntersectionHandler

const CLASS_NAME = "NullIntersection"

const CONFLICT_ZONE_OFFSET = 50.0
const SPACE_AHEAD_REQUIRED = 50.0
const MERGE_ZIPPER_DISTANCE_MARGIN = 12.0
const AGGRESSIVE_LANE_SWITCH_MERGE = true
const AGGRESSIVE_MERGE_MIN_RESERVED_SPACE = 0.0
const AGGRESSIVE_IGNORE_COMPETITOR_CROSSING = true
const AGGRESSIVE_ALLOW_UNRESERVED_ENTRY = true
const AGGRESSIVE_UNRESERVED_BLOCKED_TIME = 0.15
const STUCK_PRIORITY_TRIGGER_TIME = 0.0
const STUCK_PRIORITY_HOLD_TIME = 20.0
const STUCK_PRIORITY_NEAR_DISTANCE = 120.0

var network_manager: NetworkManager
var game_manager: GameManager

var stoppers: Array = []
var node: RoadNode
var _stuck_priority_source_by_target: Dictionary[int, int] = { }
var _stuck_priority_ttl_by_target: Dictionary[int, float] = { }


func setup(_node: RoadNode, new_stoppers: Array) -> void:
	network_manager = GDInjector.inject("NetworkManager") as NetworkManager
	game_manager = GDInjector.inject("GameManager") as GameManager
	stoppers = new_stoppers
	node = _node

	for stopper in new_stoppers:
		stopper.set_active(false)

	_stuck_priority_source_by_target.clear()
	_stuck_priority_ttl_by_target.clear()


func dispose() -> void:
	_stuck_priority_source_by_target.clear()
	_stuck_priority_ttl_by_target.clear()


func process_tick(delta: float) -> void:
	_tick_stuck_priorities(delta)

	for stopper in stoppers:
		var stopper_activated = process_stopper(stopper)
		stopper.set_active(stopper_activated)


func process_stopper(stopper: LaneStopper) -> bool:
	if game_manager.try_hit_debug_pick(stopper):
		print("Debug pick triggered for stopper at endpoint ID %d" % stopper.endpoint.Id)
		breakpoint

	var lane := stopper.get_lane()
	var approaching_vehicle := lane.get_first_vehicle()

	if approaching_vehicle:
		var current_step := approaching_vehicle.navigator.get_current_step()
		if not approaching_vehicle.navigator.has_trip():
			return false

		if not current_step is SegmentNavigationStep:
			return false

		var next_node := (current_step as SegmentNavigationStep).next_node

		var from_endpoint_id := next_node.from
		var to_endpoint_id := next_node.to

		if to_endpoint_id == -1:
			return false

		var from_endpoint = network_manager.get_lane_endpoint(from_endpoint_id)
		var to_endpoint = network_manager.get_lane_endpoint(to_endpoint_id)

		var other_endpoints := node.get_source_endpoints(to_endpoint_id)
		var target_endpoint = network_manager.get_lane_endpoint(to_endpoint_id)
		var target_lane := network_manager.get_segment(target_endpoint["SegmentId"]).get_lane(target_endpoint["LaneId"])

		if from_endpoint["LaneNumber"] != to_endpoint["LaneNumber"]:
			if _handle_changing_lane(approaching_vehicle, from_endpoint, to_endpoint, other_endpoints, target_lane):
				approaching_vehicle.navigator.reroute()
				return true

		else:
			return _handle_straight_lane(from_endpoint, to_endpoint, other_endpoints)

	return false

func reset_state() -> void:
	_stuck_priority_source_by_target.clear()
	_stuck_priority_ttl_by_target.clear()


func _handle_changing_lane(
		target_vehicle: Vehicle,
		from_endpoint: Dictionary,
		to_endpoint: Dictionary,
		other_endpoints: Array,
		target_lane: NetLane,
) -> bool:
	if node.intersection_manager.has_vehicles_crossing(from_endpoint.Id, to_endpoint.Id):
		return true

	var priority_source = _stuck_priority_source_by_target.get(to_endpoint.Id, -1)
	var priority_ttl = _stuck_priority_ttl_by_target.get(to_endpoint.Id, 0.0)
	var has_active_priority = priority_source != -1 and priority_ttl > 0.0
	if has_active_priority and priority_source != from_endpoint.Id:
		return true

	var target_distance_left = target_vehicle.navigator.get_step_distance_left()
	var has_competition = false

	for other_endpoint_id in other_endpoints:
		if other_endpoint_id == from_endpoint.Id:
			continue

		var other_endpoint = network_manager.get_lane_endpoint(other_endpoint_id)
		var other_lane = network_manager.get_segment(other_endpoint["SegmentId"]).get_lane(other_endpoint["LaneId"])

		if node.intersection_manager.has_vehicles_crossing(other_endpoint_id, to_endpoint.Id) and not AGGRESSIVE_IGNORE_COMPETITOR_CROSSING:
			return true

		var other_vehicle = other_lane.get_first_vehicle()

		if other_vehicle:
			var distance_left = other_vehicle.navigator.get_step_distance_left()
			var is_driving_to_the_same_endpoint = _get_next_endpoint(other_vehicle) == to_endpoint.Id
			if is_driving_to_the_same_endpoint and (distance_left < CONFLICT_ZONE_OFFSET or other_vehicle.driver.state == Driver.VehicleState.BLOCKED):
				has_competition = true

				var space_ahead = target_lane.get_remaining_space()

				if not AGGRESSIVE_LANE_SWITCH_MERGE and space_ahead < SPACE_AHEAD_REQUIRED:
					return true

				# If no stuck-priority phase is active, use basic zipper rule.
				if not AGGRESSIVE_LANE_SWITCH_MERGE and not has_active_priority and target_distance_left > distance_left + MERGE_ZIPPER_DISTANCE_MARGIN:
					return true

	if has_competition and not has_active_priority:
		if target_vehicle.driver.get_time_blocked() >= STUCK_PRIORITY_TRIGGER_TIME:
			_activate_stuck_priority(to_endpoint.Id, from_endpoint.Id)
			has_active_priority = true

	var required_reserved_space = (
		AGGRESSIVE_MERGE_MIN_RESERVED_SPACE
		if AGGRESSIVE_LANE_SWITCH_MERGE
		else SPACE_AHEAD_REQUIRED
	)

	if not node.intersection_manager.try_reserve_target_lane_space(to_endpoint.Id, required_reserved_space):
		if not AGGRESSIVE_ALLOW_UNRESERVED_ENTRY:
			return true

		# Allow blocked switchers to force entry when reservation is saturated.
		if target_vehicle.driver.get_time_blocked() < AGGRESSIVE_UNRESERVED_BLOCKED_TIME:
			return true

	if has_active_priority and priority_source == from_endpoint.Id:
		_stuck_priority_ttl_by_target[to_endpoint.Id] = STUCK_PRIORITY_HOLD_TIME

	return false


func _tick_stuck_priorities(delta: float) -> void:
	for target_endpoint_id in _stuck_priority_ttl_by_target.keys():
		var ttl = _stuck_priority_ttl_by_target[target_endpoint_id] - delta
		if ttl <= 0.0:
			_stuck_priority_ttl_by_target.erase(target_endpoint_id)
			_stuck_priority_source_by_target.erase(target_endpoint_id)
			continue

		if not _has_nearby_merge_contender(target_endpoint_id):
			_stuck_priority_ttl_by_target.erase(target_endpoint_id)
			_stuck_priority_source_by_target.erase(target_endpoint_id)
			continue

		_stuck_priority_ttl_by_target[target_endpoint_id] = ttl


func _activate_stuck_priority(target_endpoint_id: int, source_endpoint_id: int) -> void:
	_stuck_priority_source_by_target[target_endpoint_id] = source_endpoint_id
	_stuck_priority_ttl_by_target[target_endpoint_id] = STUCK_PRIORITY_HOLD_TIME


func _has_nearby_merge_contender(target_endpoint_id: int) -> bool:
	for stopper in stoppers:
		var lane = stopper.get_lane()
		var vehicle = lane.get_first_vehicle()
		if not vehicle:
			continue

		if not vehicle.navigator.has_trip():
			continue

		var current_step = vehicle.navigator.get_current_step()
		if not current_step is SegmentNavigationStep:
			continue

		var next_node = (current_step as SegmentNavigationStep).next_node
		if next_node.to != target_endpoint_id:
			continue

		var from_endpoint = network_manager.get_lane_endpoint(next_node.from)
		var to_endpoint = network_manager.get_lane_endpoint(next_node.to)
		if from_endpoint["LaneNumber"] == to_endpoint["LaneNumber"]:
			continue

		if vehicle.navigator.get_step_distance_left() <= STUCK_PRIORITY_NEAR_DISTANCE:
			return true

	return false


func _handle_straight_lane(from_endpoint: Dictionary, to_endpoint: Dictionary, other_endpoints: Array) -> bool:
	for other_endpoint_id in other_endpoints:
		if other_endpoint_id == from_endpoint.Id:
			continue

		if node.intersection_manager.has_vehicles_crossing(other_endpoint_id, to_endpoint.Id):
			return true

	return false


func _get_next_endpoint(vehicle: Vehicle) -> int:
	var current_step := vehicle.navigator.get_current_step()

	if current_step is SegmentNavigationStep:
		var next_node: NextNodeInfo = current_step.next_node

		if next_node.to != -1:
			return next_node.to

		return -1

	if current_step is BuildingNavigationStep:
		return -1

	return current_step.to_endpoint
