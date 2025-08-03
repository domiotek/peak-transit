class_name NetworkManager

var nodes: Dictionary[int, RoadNode] = {}
var segments: Dictionary[int, NetSegment] = {}

var lane_endpoints: Dictionary[int, NetLaneEndpoint] = {}

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

	path_finder.BuildGraph(nodes.values())

	var callback = Callable(self, "retrieve_path")

	# Calculate time difference for pathfinding
	var start_time = Time.get_ticks_msec()
	path_finder.FindPath(5, 7, callback)
	var end_time = Time.get_ticks_msec()
	var time_taken = end_time - start_time
	print("Pathfinding took %d ms" % time_taken)

func retrieve_path(path: Variant): 
	if path.State == 1:
		print("Path found from 5 to 7:")
		
		for step in path.Path:
			var endpoint_id = ""

			if "ViaEndpointId" in step:
				endpoint_id = step.ViaEndpointId
			print("Step: ", step.FromNodeId," -> ", step.ToNodeId, " Via:", endpoint_id)
	else:
		print("Path not found. State:", path.State)


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

func add_lane_endpoint(lane_id: int, pos: Vector2, segment: NetSegment, node: RoadNode, is_outgoing: bool, lane_number: int) -> int:
	var endpoint = NetLaneEndpoint.new()

	var next_id = lane_endpoints.size()

	endpoint.Id = next_id
	endpoint.Position = pos
	endpoint.SegmentId = segment.id
	endpoint.NodeId = node.id
	endpoint.LaneId = lane_id
	endpoint.LaneNumber = lane_number
	endpoint.SetIsOutgoing(is_outgoing)

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

func get_segment(segment_id: int) -> NetSegment:
	if segments.has(segment_id):
		return segments[segment_id]
	else:
		push_error("Segment with ID %d not found." % segment_id)
		return null
