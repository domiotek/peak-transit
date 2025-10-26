extends Node2D
class_name NetworkGrid

var NETWORK_NODE = preload("res://game-objects/network/net-node/network_node.tscn")
var NET_SEGMENT = preload("res://game-objects/network/net-segment/net_segment.tscn")

@onready var network_manager: NetworkManager = GDInjector.inject("NetworkManager") as NetworkManager
@onready var buildings_manager: BuildingsManager = GDInjector.inject("BuildingsManager") as BuildingsManager
@onready var path_finder: PathFinder = GDInjector.inject("PathFinder") as PathFinder
@onready var game_manager: GameManager = GDInjector.inject("GameManager") as GameManager

func load_network_definition(network_def: NetworkDefinition) -> void:

	for i in range(network_def.Nodes.size()):
		var node = network_def.Nodes[i]
		var road_node = _create_node(node)
		add_child(road_node)
		network_manager.register_node(road_node)

		game_manager.push_loading_progress("Creating network nodes...", i / float(network_def.Nodes.size()))
		await get_tree().process_frame


	for i in range(network_def.Segments.size()):
		var segment_info = network_def.Segments[i]
		var segment = _createSegment(segment_info)
		network_manager.register_segment(segment)
		add_child(segment)
		segment.update_visuals()

		game_manager.push_loading_progress("Creating network segments...", i / float(network_def.Segments.size()))
		await get_tree().process_frame

	var nodes = network_manager.get_nodes()
	for i in range(nodes.size()):
		nodes[i].update_visuals()

		game_manager.push_loading_progress("Updating network nodes...", i / float(nodes.size()))
		await get_tree().process_frame

	var segments = network_manager.get_segments()
	for i in range(segments.size()):
		segments[i].late_update_visuals()

		game_manager.push_loading_progress("Finalizing network segments...", i / float(segments.size()))
		await get_tree().process_frame

	for i in range(nodes.size()):
		nodes[i].late_update_visuals()
		game_manager.push_loading_progress("Finalizing network nodes...", i / float(nodes.size()))
		await get_tree().process_frame

	var buildings = buildings_manager.get_buildings()
	for i in range(buildings.size()):
		buildings[i].setup_connections()
		game_manager.push_loading_progress("Setting up building connections...", i / float(buildings.size()))
		await get_tree().process_frame

	game_manager.push_loading_progress("Building pathfinding graph...", 0.0)
	path_finder.BuildGraph(network_manager.get_nodes())


func _create_node(node_info: NetNode) -> RoadNode:
	var road_node = NETWORK_NODE.instantiate()
	road_node.id = node_info.Id
	road_node.position = node_info.Position
	road_node.definition = node_info

	return road_node


func _createSegment(segment_info: NetSegmentInfo):
	var node_A = network_manager.get_node(segment_info.Nodes[0])
	var node_B = network_manager.get_node(segment_info.Nodes[1])

	if not node_A or not node_B:
		push_error("Invalid segment setup: Start or target node not found.")
		return null

	var segment = NET_SEGMENT.instantiate()
	segment.setup(node_A, node_B, segment_info)

	for relation in segment_info.Relations:
		if node_A.id == relation.StartNodeId:
			segment.add_connection(node_A, node_B, relation)
		else:
			segment.add_connection(node_B, node_A, relation)

	return segment
