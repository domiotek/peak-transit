class_name NetworkManager

var _node_ids: IDManager = IDManager.new()
var _segment_ids: IDManager = IDManager.new()
var _endpoint_ids: IDManager = IDManager.new()

var nodes: Dictionary[int, RoadNode] = { }
var segments: Dictionary[int, NetSegment] = { }

# Stores segment refs by 'nodeAId-nodeBId' string keys for quick lookup
var _n2n_segment_map: Dictionary[String, int] = { }

var lane_endpoints: Dictionary[int, Dictionary] = { }

var end_nodes: Variant = null

var line_helper: LineHelper = GDInjector.inject("LineHelper") as LineHelper
var segment_helper: SegmentHelper = GDInjector.inject("SegmentHelper") as SegmentHelper


func register_node(node: RoadNode):
	nodes[node.id] = node


func unregister_node(node: RoadNode) -> void:
	nodes.erase(node.id)
	_node_ids.release_id(node.id)


func get_next_node_id() -> int:
	return _node_ids.occupy_next_id()


func get_nodes() -> Array:
	return nodes.values()


func register_segment(segment: NetSegment) -> NetSegment:
	var new_segment_id = _segment_ids.occupy_next_id()
	segment.id = new_segment_id
	segments[new_segment_id] = segment

	var ids = [segment.nodes[0].id, segment.nodes[1].id]
	ids.sort()
	var n2n_key = "%d-%d" % [ids[0], ids[1]]
	_n2n_segment_map[n2n_key] = new_segment_id

	return segment


func unregister_segment(segment: NetSegment) -> void:
	if not segments.has(segment.id):
		return

	segments.erase(segment.id)
	_segment_ids.release_id(segment.id)

	var ids = [segment.nodes[0].id, segment.nodes[1].id]
	ids.sort()
	var n2n_key = "%d-%d" % [ids[0], ids[1]]
	if _n2n_segment_map.has(n2n_key):
		_n2n_segment_map.erase(n2n_key)

	for endpoint_id in segment.endpoints:
		lane_endpoints.erase(endpoint_id)
		_endpoint_ids.release_id(endpoint_id)


func get_segments() -> Array:
	return segments.values()


func get_node_connected_segments(node_id: int) -> Array:
	var connected_segments = []
	for segment in segments.values():
		if segment.nodes.find_custom(func(node): return node.id == node_id) != -1:
			connected_segments.append(segment)
	return connected_segments


func get_node_intersection_polygon(node_id: int) -> PackedVector2Array:
	var node = nodes[node_id]
	return node.get_intersection_polygon() if node else PackedVector2Array()


func add_lane_endpoint(lane_id: int, pos: Vector2, segment: NetSegment, node: RoadNode, is_outgoing: bool, lane_number: int, is_at_path_start: bool) -> int:
	var endpoint = {
		"Id": _endpoint_ids.occupy_next_id(),
		"Position": pos,
		"SegmentId": segment.id,
		"NodeId": node.id,
		"LaneId": lane_id,
		"LaneNumber": lane_number,
		"IsOutgoing": is_outgoing,
		"IsAtPathStart": is_at_path_start,
		"Connections": [],
		"ConnectionsExt": { },
	}

	lane_endpoints[endpoint.Id] = endpoint

	if is_outgoing:
		node.outgoing_endpoints.append(endpoint.Id)
	else:
		node.incoming_endpoints.append(endpoint.Id)

	segment.endpoints.append(endpoint.Id)

	return endpoint.Id


func get_lane_endpoint(endpoint_id: int) -> Variant:
	if lane_endpoints.has(endpoint_id):
		return lane_endpoints[endpoint_id]
	push_error("Lane endpoint with ID %d not found." % endpoint_id)
	return null


func unregister_lane_endpoint(endpoint_id: int) -> void:
	if not lane_endpoints.has(endpoint_id):
		return

	var endpoint = lane_endpoints[endpoint_id]
	var node = nodes[endpoint.NodeId]
	var segment = segments[endpoint.SegmentId]

	node.remove_endpoint_bind(endpoint_id)
	segment.remove_endpoint_bind(endpoint_id)

	lane_endpoints.erase(endpoint_id)
	_endpoint_ids.release_id(endpoint_id)


func get_opposite_lane_endpoint(endpoint_id: int) -> Variant:
	var endpoint = get_lane_endpoint(endpoint_id)
	var segment = get_segment(endpoint.SegmentId)
	var lane = segment.get_lane(endpoint.LaneId) as NetLane

	var opposite_endpoint = lane.get_endpoint_by_type(not endpoint.IsOutgoing)
	if opposite_endpoint:
		return opposite_endpoint

	push_error("Opposite lane endpoint not found for endpoint ID %d." % endpoint_id)
	return null


func get_node_endpoints(node_id: int) -> Array:
	var node = nodes[node_id]
	if not node:
		push_error("Node with ID %d not found." % node_id)
		return []

	var endpoints = []
	for endpoint_id in node.incoming_endpoints + node.outgoing_endpoints:
		var endpoint = get_lane_endpoint(endpoint_id)
		if endpoint:
			endpoints.append(endpoint)

	return endpoints


func get_node(node_id: int) -> RoadNode:
	if nodes.has(node_id):
		return nodes[node_id]

	push_error("Node with ID %d not found." % node_id)
	return null


func get_segment(segment_id: int) -> NetSegment:
	if segments.has(segment_id):
		return segments[segment_id]

	push_error("Segment with ID %d not found." % segment_id)
	return null


func get_segment_between_nodes(node_a_id: int, node_b_id: int) -> NetSegment:
	var ids = [node_a_id, node_b_id]
	ids.sort()
	var n2n_key = "%d-%d" % [ids[0], ids[1]]

	if _n2n_segment_map.has(n2n_key):
		var segment_id = _n2n_segment_map[n2n_key]
		return get_segment(segment_id)
	return null


func get_end_nodes() -> Array:
	if end_nodes == null:
		end_nodes = nodes.values().filter(func(node): return node.connected_segments.size() == 1)

	return end_nodes


func get_curves_of_path(path: Array, starting_building: BaseBuilding = null, ending_building: BaseBuilding = null) -> Array:
	var curves: Array = []

	var first_building_connection: Dictionary

	if starting_building != null:
		first_building_connection = starting_building.get_out_connection_from_in_endpoint(path[0].ViaEndpointId)
		curves.append(line_helper.convert_curve_local_to_global(first_building_connection["path"].curve, starting_building))

	for step_idx in range(path.size()):
		var step = path[step_idx]
		var other_endpoint = get_opposite_lane_endpoint(step.ViaEndpointId)
		var lane = get_segment(other_endpoint.SegmentId).get_lane(other_endpoint.LaneId) as NetLane
		curves.append(lane.trail.curve)

		if step_idx < path.size() - 1:
			var node = get_node(step.ToNodeId)
			var next_step = path[step_idx + 1]

			var node_path = node.get_connection_path(other_endpoint.Id, next_step.ViaEndpointId)
			curves.append(line_helper.convert_curve_local_to_global(node_path.curve, node))

	if ending_building != null:
		var last_building_connection: Dictionary

		last_building_connection = ending_building.get_in_connection(path[path.size() - 1].ViaEndpointId)
		curves.append(line_helper.convert_curve_local_to_global(last_building_connection["path"].curve, ending_building))

		curves[curves.size() - 2] = segment_helper.trim_curve_to_building_connection(curves[curves.size() - 2], last_building_connection["lane_point"], false)

	if starting_building != null:
		curves[1] = segment_helper.trim_curve_to_building_connection(curves[1], first_building_connection["lane_point"], true)

	return curves


func clear_state() -> void:
	nodes.clear()
	segments.clear()
	lane_endpoints.clear()
	end_nodes = null
	_n2n_segment_map.clear()
	_node_ids.reset()
	_segment_ids.reset()
	_endpoint_ids.reset()
