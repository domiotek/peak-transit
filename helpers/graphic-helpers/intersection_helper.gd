extends RefCounted

class_name IntersectionHelper

var network_manager: NetworkManager

var CONFLICT_ZONE_OFFSET = 50.0

func inject_dependencies() -> void:
	network_manager = GDInjector.inject("NetworkManager") as NetworkManager


func block_if_not_enough_space_in_lane_ahead(node: RoadNode, stopper: LaneStopper, next_endpoint: int) -> bool:
	var endpoint = network_manager.get_lane_endpoint(next_endpoint)
	var lane = network_manager.get_segment(endpoint.SegmentId).get_lane(endpoint.LaneId)

	var available_space = lane.get_remaining_space()

	var last_vehicle = lane.get_last_vehicle()
	var vehicle_state = last_vehicle.driver.get_state() if last_vehicle else null
	var is_another_vehicle_already_on_intersection = false

	if available_space < CONFLICT_ZONE_OFFSET * 2:
		is_another_vehicle_already_on_intersection = node.get_vehicles_crossing(stopper.endpoint.Id, next_endpoint).size() > 0
		

	return is_another_vehicle_already_on_intersection || (available_space < 25.0 && last_vehicle.driver.get_target_speed() != last_vehicle.driver.get_maximum_speed()) ||  available_space < 50.0 && (vehicle_state == Driver.VehicleState.BRAKING || vehicle_state == Driver.VehicleState.BLOCKED)