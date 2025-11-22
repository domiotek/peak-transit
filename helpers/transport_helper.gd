class_name TransportHelper

static func validate_stop_definition(network_manager: NetworkManager, stop_def: StopDefinition) -> String:
	var validation_result = validate_segment_object_position(network_manager, stop_def.position)

	if validation_result.has("error"):
		return validation_result["error"] as String

	var target_relation: NetRelation = validation_result["relation"]
	var offset: float = validation_result["offset"] as float

	for existing_stop_struct in target_relation.get_stops().values():
		var existing_stop_offset = existing_stop_struct.offset

		if abs(existing_stop_offset - offset) < NetworkConstants.MIN_STOP_DISTANCE:
			return "Too close to existing stop"

	for building_struct in target_relation.get_buildings().values():
		var building_offset = building_struct.offset

		if abs(building_offset - offset) < NetworkConstants.MIN_STOP_BUILDING_CLEARANCE:
			return "Too close to existing building"

	return ""


static func validate_terminal_definition(network_manager: NetworkManager, terminal_def: TerminalDefinition) -> String:
	var validation_result = validate_segment_object_position(network_manager, terminal_def.position)

	if validation_result.has("error"):
		return validation_result["error"] as String

	var target_relation: NetRelation = validation_result["relation"]
	var offset: float = validation_result["offset"] as float

	for existing_stop_struct in target_relation.get_stops().values():
		var existing_stop_offset = existing_stop_struct.offset

		if abs(existing_stop_offset - offset) < NetworkConstants.MIN_STOP_DISTANCE:
			return "Too close to existing stop"

	for building_struct in target_relation.get_buildings().values():
		var building_offset = building_struct.offset

		if abs(building_offset - offset) < NetworkConstants.MIN_TERMINAL_BUILDING_CLEARANCE:
			return "Too close to existing building"

	return ""


static func validate_line_definition(transport_manager: TransportManager, network_manager: NetworkManager, line_def: LineDefinition) -> String:
	if line_def.routes.size() != 2:
		return "Line must have exactly two routes"

	for route in line_def.routes:
		if route.size() < 2:
			return "Each route must have at least two steps"

		for step in route as Array[RouteStepDefinition]:
			var target_id = step.target_id

			match step.step_type:
				Enums.TransportRouteStepType.TERMINAL:
					var terminal_exists = transport_manager.terminal_exists(target_id)
					if not terminal_exists:
						return "Terminal ID not found in line '%s': %d" % [line_def.name, target_id]
				Enums.TransportRouteStepType.STOP:
					var stop_exists = transport_manager.stop_exists(target_id)
					if not stop_exists:
						return "Stop ID not found in line '%s': %d" % [line_def.name, target_id]
				Enums.TransportRouteStepType.WAYPOINT:
					var node = network_manager.get_node(target_id)
					if not node:
						return "Node ID not found in line '%s': %d" % [line_def.name, target_id]
				_:
					return "Unknown step type in line '%s'" % line_def.name

	return ""


static func validate_segment_object_position(network_manager: NetworkManager, pos_def: SegmentPosDefinition) -> Dictionary:
	if pos_def.segment.size() != 2:
		return {
			"error": "Invalid segment size",
		}

	var node_a = network_manager.get_node(pos_def.segment[0])
	var node_b = network_manager.get_node(pos_def.segment[1])

	if not node_a or not node_b:
		return {
			"error": "Segment nodes not found in network",
		}

	var target_segment = network_manager.get_segment_between_nodes(node_a.id, node_b.id)

	if not target_segment:
		return {
			"error": "Nodes are not connected by a segment",
		}

	var target_relation: NetRelation = target_segment.get_relation_with_starting_node(node_a.id)

	if not target_relation:
		return {
			"error": "No relation found starting from the specified node",
		}

	if target_relation.relation_info.lanes.size() == 0:
		return {
			"error": "No lanes found in the target relation",
		}

	var target_lane_id = target_relation.get_rightmost_lane_id()

	var lane = target_segment.get_lane(target_lane_id)

	if not lane:
		return {
			"error": "Target lane not found in segment",
		}

	var lane_length = lane.get_length()

	var offset = pos_def.offset

	if offset < 0.0 or offset > lane_length:
		return {
			"error": "Offset out of bounds for lane length",
		}

	return {
		"segment": target_segment,
		"relation": target_relation,
		"lane": lane,
		"offset": offset,
	}
