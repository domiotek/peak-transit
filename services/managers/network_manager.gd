class_name NetworkManager

var nodes: Dictionary[int, RoadNode] = {}
var segments: Dictionary[int, NetSegment] = {}

var lane_endpoints: Dictionary[int, Dictionary] = {}

var end_nodes: Variant = null

func register_node(node: RoadNode):
	nodes[node.id] = node

func get_nodes() -> Array:
	return nodes.values()

func register_segment(segment: NetSegment) -> NetSegment:
	var new_segment_id = segments.size()
	segment.id = new_segment_id
	segments[new_segment_id] = segment
	return segment

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
		"Id": lane_endpoints.size(),
		"Position": pos,
		"SegmentId": segment.id,
		"NodeId": node.id,
		"LaneId": lane_id,
		"LaneNumber": lane_number,
		"IsOutgoing": is_outgoing,
		"IsAtPathStart": is_at_path_start,
		"Connections": []
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
	else:
		push_error("Lane endpoint with ID %d not found." % endpoint_id)
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
	else:
		push_error("Node with ID %d not found." % node_id)
		return null

func get_segment(segment_id: int) -> NetSegment:
	if segments.has(segment_id):
		return segments[segment_id]
	else:
		push_error("Segment with ID %d not found." % segment_id)
		return null

func get_end_nodes() -> Array:
	if end_nodes == null:
		end_nodes = nodes.values().filter(func(node): return node.connected_segments.size() == 1)

	return end_nodes

func clear_state() -> void:
	nodes.clear()
	segments.clear()
	lane_endpoints.clear()
	end_nodes = null
