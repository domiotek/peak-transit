extends Node

var nodes: Dictionary[int, RoadNode] = {}
var segments: Dictionary[int, NetSegment] = {}

var uiGrid: NetworkGrid

func register_node(node: RoadNode):
	nodes[node.id] = node
	
func setup_network(grid: NetworkGrid):
	uiGrid = grid
	var netdef = get_node("/root/NetworkDefinition")

	for segment in netdef.Segments:
		_setupSegment(segment)

	for node in nodes.values():
		node.update_visuals()


	for segment in segments.values():
		segment.late_update_visuals()

	for node in nodes.values():
		node.late_update_visuals()


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

	var segment_scene = load("res://scenes/net_segment.tscn")
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
