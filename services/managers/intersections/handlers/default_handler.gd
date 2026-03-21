extends RefCounted

class_name DefaultIntersectionHandler

const CLASS_NAME = "DefaultIntersection"

const RIGHT_OF_WAY_SIGN = preload("res://assets/signs/right_of_way_sign.png")
const GIVE_WAY_SIGN = preload("res://assets/signs/give_way_sign.png")
const STOP_SIGN = preload("res://assets/signs/stop_sign.png")

var node: RoadNode
var stoppers: Array = []
var _render_boxes: Array = []

var connecting_curves: Dictionary = { }
var conflicting_paths: Dictionary = { }
var _stoppers_by_endpoint_id: Dictionary[int, LaneStopper] = { }
var _stoppers_by_segment_id: Dictionary[int, Array] = { }

var halted_vehicles: Dictionary = { }

var game_manager: GameManager
var network_manager: NetworkManager

const CONFLICT_ZONE_OFFSET = 50.0


func setup(_node: RoadNode, new_stoppers: Array) -> void:
	node = _node
	stoppers = new_stoppers

	network_manager = GDInjector.inject("NetworkManager") as NetworkManager
	game_manager = GDInjector.inject("GameManager") as GameManager

	_fill_curves()
	_stoppers_by_endpoint_id.clear()
	_stoppers_by_segment_id.clear()
	for stopper in new_stoppers:
		_stoppers_by_endpoint_id[stopper.endpoint.Id] = stopper

		if not _stoppers_by_segment_id.has(stopper.endpoint.SegmentId):
			_stoppers_by_segment_id[stopper.endpoint.SegmentId] = []
		_stoppers_by_segment_id[stopper.endpoint.SegmentId].append(stopper)

		stopper.set_active(false)
		conflicting_paths[stopper.endpoint.Id] = _get_conflicting_paths(stopper)

	connecting_curves.clear()

	_draw_priority_signs()


func dispose() -> void:
	for box in _render_boxes:
		box.queue_free()
	_render_boxes.clear()


func process_tick(delta: float) -> void:
	for stopper in stoppers:
		var stopper_activated = process_stopper(stopper, delta)
		stopper.set_active(stopper_activated)


func process_stopper(stopper: LaneStopper, delta: float) -> bool:
	if game_manager.try_hit_debug_pick(stopper):
		print("Debug pick triggered for stopper at endpoint ID %d" % stopper.endpoint.Id)
		breakpoint

	var lane = stopper.get_lane()
	var approaching_vehicle = lane.get_first_vehicle()

	if approaching_vehicle:
		var distance_left = approaching_vehicle.navigator.get_step_distance_left()
		var projected_advance = max(approaching_vehicle.driver.get_current_speed() * delta, 0.0)
		var activation_distance = CONFLICT_ZONE_OFFSET + projected_advance

		if distance_left >= activation_distance and approaching_vehicle.driver.state != Driver.VehicleState.BLOCKED:
			return false

		var priority = node.get_connection_priority(stopper.endpoint.Id)

		if priority == Enums.IntersectionPriority.STOP:
			var last_halted_vehicle_id = halted_vehicles.get(stopper.endpoint.Id, null)

			if approaching_vehicle.id == last_halted_vehicle_id || approaching_vehicle.driver.get_current_speed() == 0.0:
				halted_vehicles[stopper.endpoint.Id] = approaching_vehicle.id
				return false

			return true

		var current_step := approaching_vehicle.navigator.get_current_step() as NavigationStep

		var step_type = current_step.type
		if step_type == Navigator.StepType.NODE or step_type == Navigator.StepType.BUILDING:
			return false

		var next_endpoint = current_step.next_node.to

		if not next_endpoint or next_endpoint == -1:
			return false

		if _check_enough_space_in_lane_ahead(stopper, next_endpoint):
			return true

		if _check_conflicting_path(stopper, next_endpoint):
			return true

	return false


func _fill_curves() -> void:
	for stopper in stoppers:
		var dest_endpoints = node.get_destination_endpoints(stopper.endpoint.Id)

		var connections = { }
		for dest_id in dest_endpoints:
			var path = node.get_connection_path(stopper.endpoint.Id, dest_id)
			connections[dest_id] = path.curve

		connecting_curves[stopper.endpoint.Id] = connections


func _get_conflicting_paths(stopper: LaneStopper) -> Dictionary:
	var conflicting_per_connection: Dictionary = { }

	for my_dest_endpoint_id in connecting_curves[stopper.endpoint.Id]:
		var my_direction = node.get_connection_direction(stopper.endpoint.Id, my_dest_endpoint_id)
		var my_priority = node.get_connection_priority(stopper.endpoint.Id)

		var conflicting: Array = []

		for other_stopper in stoppers:
			if other_stopper == stopper or stopper.endpoint.SegmentId == other_stopper.endpoint.SegmentId:
				continue

			for other_dest_endpoint_id in connecting_curves[other_stopper.endpoint.Id]:
				var other_direction = node.get_connection_direction(other_stopper.endpoint.Id, other_dest_endpoint_id)
				var other_priority = node.get_connection_priority(other_stopper.endpoint.Id)

				if _filter_conflict(my_direction, other_direction, my_priority, other_priority):
					var reason = Enums.PathConflictType.NONE

					if node.are_connection_curves_crossing(stopper.endpoint.Id, my_dest_endpoint_id, other_stopper.endpoint.Id, other_dest_endpoint_id):
						reason = Enums.PathConflictType.LINE_CROSSING
					if my_dest_endpoint_id == other_dest_endpoint_id:
						reason = Enums.PathConflictType.SAME_ENDPOINT

					if reason != Enums.PathConflictType.NONE:
						conflicting.append({ "from": other_stopper.endpoint.Id, "to": other_dest_endpoint_id, "conflict_type": reason })

		conflicting_per_connection[my_dest_endpoint_id] = conflicting
	return conflicting_per_connection


func _filter_conflict(
		my_direction: Enums.Direction,
		other_direction: Enums.Direction,
		my_priority: Enums.IntersectionPriority,
		other_priority: Enums.IntersectionPriority,
) -> bool:
	var have_advantage := other_priority == Enums.IntersectionPriority.STOP or (
		my_priority == Enums.IntersectionPriority.PRIORITY and other_priority == Enums.IntersectionPriority.YIELD )

	if have_advantage:
		return false

	var they_have_advantage := my_priority == Enums.IntersectionPriority.STOP or (
		other_priority == Enums.IntersectionPriority.PRIORITY and my_priority == Enums.IntersectionPriority.YIELD )

	if they_have_advantage:
		return true

	match my_direction:
		Enums.Direction.FORWARD, Enums.Direction.BACKWARD:
			return false
		Enums.Direction.RIGHT:
			return other_direction == Enums.Direction.FORWARD
		Enums.Direction.LEFT:
			return other_direction == Enums.Direction.FORWARD or other_direction == Enums.Direction.RIGHT

	return false


func _check_enough_space_in_lane_ahead(_stopper: LaneStopper, next_endpoint: int) -> bool:
	var endpoint = network_manager.get_lane_endpoint(next_endpoint)
	var lane := network_manager.get_segment(endpoint.SegmentId).get_lane(endpoint.LaneId)

	var available_space := lane.get_remaining_space()

	var last_vehicle := lane.get_last_vehicle()
	var vehicle_state: Driver.VehicleState = last_vehicle.driver.get_state() if last_vehicle else Driver.VehicleState.IDLE
	var is_another_vehicle_already_on_intersection := false
	var has_insufficient_entry_space := available_space < CONFLICT_ZONE_OFFSET

	if available_space < CONFLICT_ZONE_OFFSET * 2:
		is_another_vehicle_already_on_intersection = node.intersection_manager.has_vehicles_crossing(_stopper.endpoint.Id, next_endpoint)

	var is_lane_jammed = last_vehicle != null and available_space < 25.0 and last_vehicle.driver.get_target_speed() != last_vehicle.driver.get_maximum_speed()
	var is_lane_blocked = last_vehicle != null and available_space < 50.0 and (
		vehicle_state == Driver.VehicleState.BRAKING or vehicle_state == Driver.VehicleState.BLOCKED
	)

	var should_block = has_insufficient_entry_space or is_another_vehicle_already_on_intersection or is_lane_jammed or is_lane_blocked

	if should_block:
		return true

	if not node.intersection_manager.try_reserve_target_lane_space(next_endpoint, CONFLICT_ZONE_OFFSET):
		return true

	return false


func _check_conflicting_path(stopper: LaneStopper, next_endpoint: int) -> bool:
	var stopper_conflicting_paths = conflicting_paths.get(stopper.endpoint.Id, { })

	if not stopper_conflicting_paths.has(next_endpoint):
		return false

	var _conflicting_paths = stopper_conflicting_paths[next_endpoint]

	for path in _conflicting_paths:
		var other_stopper: LaneStopper = _stoppers_by_endpoint_id.get(path.from, null)
		if not other_stopper:
			continue

		var other_lane = other_stopper.get_lane()

		var other_approaching_vehicle = other_lane.get_first_vehicle()

		if other_approaching_vehicle:
			var other_distance_left = other_approaching_vehicle.navigator.get_distance_left()
			var is_driving_to_the_same_endpoint: bool = other_approaching_vehicle.navigator.get_current_step().next_node.to == next_endpoint

			if other_distance_left < CONFLICT_ZONE_OFFSET and (
				path.conflict_type == Enums.PathConflictType.LINE_CROSSING or is_driving_to_the_same_endpoint ) and not other_stopper.is_active():
				return true

		var vehicle_already_in_intersection: bool = node.intersection_manager.has_vehicles_crossing(path.from, path.to)
		if vehicle_already_in_intersection:
			return true

	return false


func _draw_priority_signs() -> void:
	for segment in node.connected_segments:
		var segment_stoppers = _stoppers_by_segment_id.get(segment.id, [])
		var lane = segment_stoppers[0].get_lane() if segment_stoppers.size() > 0 else null

		var lanes_count = segment.get_relation_of_lane(lane.id).get_lane_count() if lane else 0
		var right_most_lane_number = lanes_count - 1

		var right_most_stopper: LaneStopper = null
		for segment_stopper in segment_stoppers:
			if segment_stopper.endpoint.LaneNumber == right_most_lane_number:
				right_most_stopper = segment_stopper
				break

		if not right_most_stopper:
			continue

		var box = _get_road_side_position_box(right_most_stopper)

		var priority = node.get_connection_priority(right_most_stopper.endpoint.Id)

		var sign_obj = Sprite2D.new()
		sign_obj.scale = Vector2(0.2, 0.2)

		match priority:
			Enums.IntersectionPriority.PRIORITY:
				sign_obj.texture = RIGHT_OF_WAY_SIGN
			Enums.IntersectionPriority.YIELD:
				sign_obj.texture = GIVE_WAY_SIGN
			Enums.IntersectionPriority.STOP:
				sign_obj.texture = STOP_SIGN
			_:
				continue

		box.add_child(sign_obj)


func _get_road_side_position_box(ref_stopper: LaneStopper) -> Node2D:
	var box = Node2D.new()
	box.position = node.to_local(ref_stopper.endpoint.Position)
	box.rotation_degrees = ref_stopper.rotation_degrees + 90.0
	box.z_index = 1
	node.top_layer.add_child(box)
	_render_boxes.append(box)

	var offset = Vector2(NetworkConstants.LANE_WIDTH, 30).rotated(deg_to_rad(box.rotation_degrees))
	box.position += offset

	return box
