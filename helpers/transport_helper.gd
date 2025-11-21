class_name TransportHelper

static func validate_stop_definition(network_manager: NetworkManager, stop_def: StopDefinition) -> String:
	if stop_def.position.segment.size() != 2:
		return "Invalid segment size"

	var node_a = network_manager.get_node(stop_def.position.segment[0])
	var node_b = network_manager.get_node(stop_def.position.segment[1])

	if not node_a or not node_b:
		return "Segment nodes not found in network"

	var target_segment = network_manager.get_segment_between_nodes(node_a.id, node_b.id)

	if not target_segment:
		return "Nodes are not connected by a segment"

	var target_relation: NetRelation = target_segment.get_relation_with_starting_node(node_a.id)

	if not target_relation:
		return "No relation found starting from the specified node"

	if target_relation.relation_info.lanes.size() == 0:
		return "No lanes found in the target relation"

	var target_lane_id = target_relation.get_rightmost_lane_id()

	var lane = target_segment.get_lane(target_lane_id)

	if not lane:
		return "Target lane not found in segment"

	var lane_length = lane.get_length()

	var offset = stop_def.position.offset

	if offset < 0.0 or stop_def.position.offset > lane_length:
		return "Offset out of bounds for lane length"

	for existing_stop_struct in target_relation.get_stops().values():
		var existing_stop_offset = existing_stop_struct.offset

		if abs(existing_stop_offset - offset) < NetworkConstants.MIN_STOP_DISTANCE:
			return "Too close to existing stop"

	for building_struct in target_relation.get_buildings().values():
		var building_offset = building_struct.offset

		if abs(building_offset - offset) < NetworkConstants.MIN_STOP_BUILDING_CLEARANCE:
			return "Too close to existing building"

	return ""
