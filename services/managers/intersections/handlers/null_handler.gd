extends RefCounted

class_name NullIntersectionHandler

var CLASS_NAME = "NullIntersection"

var CONFLICT_ZONE_OFFSET = 50.0
var SPACE_AHEAD_REQUIRED = 50.0

var network_manager: NetworkManager
var game_manager: GameManager

var stoppers: Array = []
var node: RoadNode


func setup(_node: RoadNode, new_stoppers: Array) -> void:
	network_manager = GDInjector.inject("NetworkManager") as NetworkManager
	game_manager = GDInjector.inject("GameManager") as GameManager
	stoppers = new_stoppers
	node = _node

	for stopper in new_stoppers:
		stopper.set_active(false)

func process_tick(_delta: float) -> void:
	for stopper in stoppers:
		var stopper_activated = process_stopper(stopper)
		stopper.set_active(stopper_activated)

func process_stopper(stopper: LaneStopper) -> bool:
	if game_manager.try_hit_debug_pick(stopper):
		print("Debug pick triggered for stopper at endpoint ID %d" % stopper.endpoint.Id)
		breakpoint

	var lane = stopper.get_lane()
	var approaching_vehicle = lane.get_first_vehicle()

	if approaching_vehicle:
		var current_step = approaching_vehicle.navigator.get_current_step()

		var step_type = current_step["type"]
		if step_type == Navigator.StepType.NODE or step_type == Navigator.StepType.BUILDING:
			return false
		
		var next_node = current_step["next_node"]

		var from_endpoint_id = next_node.get("from", null)
		var to_endpoint_id = next_node.get("to", null)

		if to_endpoint_id == null:
			return false

		var from_endpoint = network_manager.get_lane_endpoint(from_endpoint_id)
		var to_endpoint = network_manager.get_lane_endpoint(to_endpoint_id)

		var other_endpoints = node.get_source_endpoints(to_endpoint_id)
		var target_endpoint = network_manager.get_lane_endpoint(to_endpoint_id)
		var target_lane = network_manager.get_segment(target_endpoint["SegmentId"]).get_lane(target_endpoint["LaneId"])

		if from_endpoint["LaneNumber"] != to_endpoint["LaneNumber"]:
			if _handle_changing_lane(approaching_vehicle, from_endpoint, to_endpoint, other_endpoints, target_lane):
				approaching_vehicle.navigator.reroute()
				return true
			
		else:
			return _handle_straight_lane(from_endpoint, to_endpoint, other_endpoints)

	return false

func _handle_changing_lane(target_vehicle: Vehicle, from_endpoint: NetLaneEndpoint, to_endpoint: NetLaneEndpoint, other_endpoints: Array, target_lane: NetLane) -> bool:
	var crossing_vehicles = node.intersection_manager.get_vehicles_crossing(from_endpoint.Id, to_endpoint.Id)

	if crossing_vehicles.size() > 0:
		return true


	for other_endpoint_id in other_endpoints:
		if other_endpoint_id == from_endpoint.Id:
			continue

		var other_endpoint = network_manager.get_lane_endpoint(other_endpoint_id)
		var other_lane = network_manager.get_segment(other_endpoint["SegmentId"]).get_lane(other_endpoint["LaneId"])

		crossing_vehicles = node.intersection_manager.get_vehicles_crossing(other_endpoint_id, to_endpoint.Id)

		if crossing_vehicles.size() > 0:
			return true

		var other_vehicle = other_lane.get_first_vehicle()
		

		if other_vehicle:
			var distance_left = other_vehicle.navigator.get_distance_left()
			var is_driving_to_the_same_endpoint = _get_next_endpoint(other_vehicle) == to_endpoint.Id

			if is_driving_to_the_same_endpoint and (distance_left < CONFLICT_ZONE_OFFSET or other_vehicle.driver.state == Driver.VehicleState.BLOCKED):
				var space_ahead = target_lane.get_remaining_space()

				if space_ahead < SPACE_AHEAD_REQUIRED or target_vehicle.id < other_vehicle.id:
					return true


	return false

func _handle_straight_lane(from_endpoint: NetLaneEndpoint, to_endpoint: NetLaneEndpoint, other_endpoints: Array) -> bool:
	for other_endpoint_id in other_endpoints:
		if other_endpoint_id == from_endpoint.Id:
			continue

		var crossing_vehicle = node.intersection_manager.get_vehicles_crossing(other_endpoint_id, to_endpoint.Id)

		if crossing_vehicle.size() > 0:
			return true

	return false


func _get_next_endpoint(vehicle: Vehicle) -> int:
	var current_step = vehicle.navigator.get_current_step()

	if current_step["type"] == Navigator.StepType.SEGMENT:
		var next_node = current_step["next_node"]
		var to_endpoint_id = next_node.get("to", null)

		if to_endpoint_id != null:
			return to_endpoint_id

		return -1

	if current_step["type"] == Navigator.StepType.BUILDING:
		return -1


	return current_step["to_endpoint"]
