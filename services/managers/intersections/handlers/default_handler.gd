extends RefCounted

class_name DefaultIntersectionHandler

var CLASS_NAME = "DefaultIntersection"

var node: RoadNode
var stoppers: Array = []


var connecting_curves: Dictionary = {}
var conflicting_paths: Dictionary = {}


var network_manager: NetworkManager
var line_helper: LineHelper


var CONFLICT_ZONE_OFFSET = 50.0


func setup(_node: RoadNode, new_stoppers: Array) -> void:
	node = _node
	stoppers = new_stoppers

	network_manager = GDInjector.inject("NetworkManager") as NetworkManager
	line_helper = GDInjector.inject("LineHelper") as LineHelper

	_fill_curves()
	for stopper in new_stoppers:
		stopper.set_active(false)
		conflicting_paths[stopper.endpoint.Id] = _get_conflicting_paths(stopper)

	connecting_curves.clear()

func process_tick(_delta: float) -> void:
	
	for stopper in stoppers:
		var lane = stopper.get_lane()
		var stopper_activated = false

		var approaching_vehicle = lane.get_first_vehicle()

		if approaching_vehicle:
			var distance_left = approaching_vehicle.navigator.get_distance_left()

			if distance_left >= CONFLICT_ZONE_OFFSET and approaching_vehicle.driver.state != Driver.VehicleState.BLOCKED:
				continue

			var next_endpoint = approaching_vehicle.navigator.get_current_step()["next_node"]["to"]

			if _check_enough_space_in_lane_ahead(stopper, next_endpoint):
				stopper_activated = true

			if not stopper_activated and _check_conflicting_path(stopper, next_endpoint):
				stopper_activated = true

		stopper.set_active(stopper_activated)


func _fill_curves() -> void:
	for stopper in stoppers:
		var dest_endpoints = node.get_destination_endpoints(stopper.endpoint.Id)

		var connections = {}
		for dest_id in dest_endpoints:
			var path = node.get_connection_path(stopper.endpoint.Id, dest_id)
			connections[dest_id] = path.curve

		connecting_curves[stopper.endpoint.Id] = connections
		

func _get_conflicting_paths(stopper: LaneStopper) -> Dictionary:
	var conflicting_per_connection: Dictionary = {}

	for my_dest_endpoint_id in connecting_curves[stopper.endpoint.Id]:
		var my_curve = node.get_connection_path(stopper.endpoint.Id, my_dest_endpoint_id).curve
		var my_direction = node.get_connection_direction(stopper.endpoint.Id, my_dest_endpoint_id)
		var my_priority = node.get_connection_priority(stopper.endpoint.Id)

		var conflicting: Array = []

		for other_stopper in stoppers:
			if other_stopper == stopper or stopper.endpoint.SegmentId == other_stopper.endpoint.SegmentId:
				continue

			for other_dest_endpoint_id in connecting_curves[other_stopper.endpoint.Id]:
				var other_curve = node.get_connection_path(other_stopper.endpoint.Id, other_dest_endpoint_id).curve
				var other_direction = node.get_connection_direction(other_stopper.endpoint.Id, other_dest_endpoint_id)
				var other_priority = node.get_connection_priority(other_stopper.endpoint.Id)

				if _filter_conflict(my_direction, other_direction, my_priority, other_priority):
					var reason = Enums.PathConflictType.NONE

					if line_helper.curves_intersect(my_curve, other_curve, 10):
						reason = Enums.PathConflictType.LINE_CROSSING
					if my_dest_endpoint_id == other_dest_endpoint_id:
						reason = Enums.PathConflictType.SAME_ENDPOINT

					if reason != Enums.PathConflictType.NONE:
						conflicting.append({ "from": other_stopper.endpoint.Id, "to": other_dest_endpoint_id, "conflict_type": reason })

		conflicting_per_connection[my_dest_endpoint_id] = conflicting
	return conflicting_per_connection


func _filter_conflict(my_direction: Enums.Direction, other_direction: Enums.Direction, my_priority: Enums.IntersectionPriority, other_priority: Enums.IntersectionPriority) -> bool:
	var have_advantage = my_priority == Enums.IntersectionPriority.PRIORITY and other_priority == Enums.IntersectionPriority.YIELD

	if have_advantage:
		return false

	var they_have_advantage = other_priority == Enums.IntersectionPriority.PRIORITY and my_priority == Enums.IntersectionPriority.YIELD

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
	var lane = network_manager.get_segment(endpoint.SegmentId).get_lane(endpoint.LaneId)

	var available_space = lane.get_remaining_space()

	var last_vehicle = lane.get_last_vehicle()
	var vehicle_state = last_vehicle.driver.get_state() if last_vehicle else null
	var is_another_vehicle_already_on_intersection = false

	if available_space < CONFLICT_ZONE_OFFSET * 2:
		is_another_vehicle_already_on_intersection = node.get_vehicles_crossing(_stopper.endpoint.Id, next_endpoint).size() > 0
		

	return is_another_vehicle_already_on_intersection || (available_space < 25.0 && last_vehicle.driver.get_target_speed() != last_vehicle.driver.get_maximum_speed()) ||  available_space < 50.0 && (vehicle_state == Driver.VehicleState.BRAKING || vehicle_state == Driver.VehicleState.BLOCKED)


func _check_conflicting_path(stopper: LaneStopper, next_endpoint: int) -> bool:
	var _conflicting_paths = conflicting_paths.get(stopper.endpoint.Id, {})[next_endpoint]

	for path in _conflicting_paths:
		var other_stopper = stoppers.filter(func (s): return s.endpoint.Id == path.from)[0]

		var other_lane = other_stopper.get_lane()

		var other_approaching_vehicle = other_lane.get_first_vehicle()

		if other_approaching_vehicle:
			var other_distance_left = other_approaching_vehicle.navigator.get_distance_left()
			var is_driving_to_the_same_endpoint = other_approaching_vehicle.navigator.get_current_step()["next_node"]["to"] == next_endpoint

			if other_distance_left < CONFLICT_ZONE_OFFSET and (path.conflict_type == Enums.PathConflictType.LINE_CROSSING or is_driving_to_the_same_endpoint) and not other_stopper.is_active():
				return true

		var vehicle_already_in_intersection = node.get_vehicles_crossing(path.from, path.to).size() > 0
		if vehicle_already_in_intersection:
			return true
				
	return false
