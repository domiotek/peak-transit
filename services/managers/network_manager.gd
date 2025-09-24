class_name NetworkManager

var nodes: Dictionary[int, RoadNode] = {}
var segments: Dictionary[int, NetSegment] = {}

var lane_endpoints: Dictionary[int, NetLaneEndpoint] = {}

var end_nodes: Array = []

var uiGrid: NetworkGrid


func register_node(node: RoadNode):
	nodes[node.id] = node
	
func setup_network(grid: NetworkGrid):
	uiGrid = grid
	var netdef = GDInjector.inject("NetworkDefinition") as NetworkDefinition
	var path_finder = GDInjector.inject("PathFinder") as PathFinder

	for segment in netdef.Segments:
		_setupSegment(segment)

	for node in nodes.values():
		node.update_visuals()


	for segment in segments.values():
		segment.late_update_visuals()

	for node in nodes.values():
		node.late_update_visuals()

	end_nodes = nodes.values().filter(func(node): return node.connected_segments.size() == 1)

	path_finder.BuildGraph(nodes.values())

func get_nodes() -> Array:
	return nodes.values()

func get_node_connected_segments(node_id: int) -> Array:
	var connected_segments = []
	for segment in segments.values():
		if segment.nodes.find_custom(func(node): return node.id == node_id) != -1:
			connected_segments.append(segment)
	return connected_segments

func get_node_intersection_polygon(node_id: int) -> PackedVector2Array:
	var node = nodes[node_id]
	return node.get_intersection_polygon() if node else PackedVector2Array()

func _setupSegment(segment_info: NetSegmentInfo):
	var node_A = nodes[segment_info.Nodes[0]]
	var node_B = nodes[segment_info.Nodes[1]]

	if not node_A or not node_B:
		push_error("Invalid segment setup: Start or target node not found.")
		return null

	var segment_scene = load("res://game-objects/network/net-segment/net_segment.tscn")
	var segment = segment_scene.instantiate()
	
	var new_segment_id = segments.size()
	segment.setup(new_segment_id, node_A, node_B, segment_info)
	segments[new_segment_id] = segment
	uiGrid.add_child(segment)

	for relation in segment_info.Relations:

		if node_A.id == relation.StartNodeId:
			segment.add_connection(node_A, node_B, relation)
		else:
			segment.add_connection(node_B, node_A, relation)

	segment.update_visuals()

func add_lane_endpoint(lane_id: int, pos: Vector2, segment: NetSegment, node: RoadNode, is_outgoing: bool, lane_number: int, is_at_path_start: bool) -> int:
	var endpoint = NetLaneEndpoint.new()

	var next_id = lane_endpoints.size()

	endpoint.Id = next_id
	endpoint.Position = pos
	endpoint.SegmentId = segment.id
	endpoint.NodeId = node.id
	endpoint.LaneId = lane_id
	endpoint.LaneNumber = lane_number
	endpoint.SetIsOutgoing(is_outgoing)
	endpoint.SetIsAtPathStart(is_at_path_start)

	lane_endpoints[next_id] = endpoint

	if is_outgoing:
		node.outgoing_endpoints.append(next_id)
	else:
		node.incoming_endpoints.append(next_id)

	segment.endpoints.append(next_id)

	return next_id


func get_lane_endpoint(endpoint_id: int) -> NetLaneEndpoint:
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
	return end_nodes
