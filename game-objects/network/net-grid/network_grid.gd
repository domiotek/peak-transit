extends Node2D

class_name NetworkGrid

var NetworkNodeScene = preload("res://game-objects/network/net-node/network_node.tscn")
var NetworkSegmentScene = preload("res://game-objects/network/net-segment/net_segment.tscn")

@onready var network_manager: NetworkManager = GDInjector.inject("NetworkManager") as NetworkManager
@onready var buildings_manager: BuildingsManager = GDInjector.inject("BuildingsManager") as BuildingsManager
@onready var path_finder: PathFinder = GDInjector.inject("PathFinder") as PathFinder
@onready var game_manager: GameManager = GDInjector.inject("GameManager") as GameManager


func load_network_definition(network_def: NetworkDefinition) -> void:
	for i in range(network_def.nodes.size()):
		var node = network_def.nodes[i]
		var road_node = _create_node(node, i)
		add_child(road_node)
		network_manager.register_node(road_node)

		game_manager.push_loading_progress("Creating network nodes...", i / float(network_def.nodes.size()))
		await get_tree().process_frame

	for i in range(network_def.segments.size()):
		var segment_info = network_def.segments[i]
		var segment = _create_segment(segment_info)
		network_manager.register_segment(segment)
		add_child(segment)
		segment.update_visuals()

		game_manager.push_loading_progress("Creating network segments...", i / float(network_def.segments.size()))
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
	await get_tree().process_frame


func _create_node(node_info: NetNodeInfo, id: int) -> RoadNode:
	var road_node = NetworkNodeScene.instantiate()
	road_node.id = id
	road_node.position = node_info.position
	road_node.definition = node_info

	return road_node


func _create_segment(segment_info: NetSegmentInfo):
	var node_a = network_manager.get_node(segment_info.nodes[0])
	var node_b = network_manager.get_node(segment_info.nodes[1])

	if not node_a or not node_b:
		push_error("Invalid segment setup: Start or target node not found.")
		return null

	var segment = NetworkSegmentScene.instantiate()
	segment.setup(node_a, node_b, segment_info)

	for i in range(segment_info.relations.size()):
		var relation = segment_info.relations[i]
		if i == 0:
			segment.add_connection(node_a, node_b, relation)
		else:
			segment.add_connection(node_b, node_a, relation)

	return segment
