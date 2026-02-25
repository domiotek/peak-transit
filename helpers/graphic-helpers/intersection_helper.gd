extends RefCounted

class_name IntersectionHelper

var network_manager: NetworkManager

var conflict_zone_offset = 50.0


func inject_dependencies() -> void:
	network_manager = GDInjector.inject("NetworkManager") as NetworkManager


func block_if_not_enough_space_in_lane_ahead(node: RoadNode, stopper: LaneStopper, next_endpoint: int) -> bool:
	var endpoint = network_manager.get_lane_endpoint(next_endpoint)
	var lane = network_manager.get_segment(endpoint.SegmentId).get_lane(endpoint.LaneId)

	var available_space = lane.get_remaining_space()

	var last_vehicle = lane.get_last_vehicle()
	var vehicle_state = last_vehicle.driver.get_state() if last_vehicle else Driver.VehicleState.IDLE
	var is_another_vehicle_already_on_intersection = false

	if available_space < conflict_zone_offset * 2:
		is_another_vehicle_already_on_intersection = node.intersection_manager.has_vehicles_crossing(stopper.endpoint.Id, next_endpoint)

	var is_lane_jammed = last_vehicle != null and available_space < 25.0 and last_vehicle.driver.get_target_speed() != last_vehicle.driver.get_maximum_speed()
	var is_lane_blocked = available_space < 50.0 and (vehicle_state == Driver.VehicleState.BRAKING or vehicle_state == Driver.VehicleState.BLOCKED)

	return is_another_vehicle_already_on_intersection or is_lane_jammed or is_lane_blocked
