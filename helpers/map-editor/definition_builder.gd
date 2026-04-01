class_name DefinitionBuilder

var network_manager: NetworkManager = GDInjector.inject("NetworkManager") as NetworkManager
var buildings_manager: BuildingsManager = GDInjector.inject("BuildingsManager") as BuildingsManager
var transport_manager: TransportManager = GDInjector.inject("TransportManager") as TransportManager
var game_manager: GameManager = GDInjector.inject("GameManager") as GameManager


func collect_world_definition() -> WorldDefinition:
	var world_definition = WorldDefinition.new()
	var game = game_manager.get_game_controller()

	if (game as MapEditorGameController) == null:
		push_error("DefinitionBuilder.collect_world_definition called outside of MapEditorGameController context.")
		return world_definition

	var world_details = game.get_world_details()

	world_definition.name = world_details["name"]
	world_definition.description = world_details["description"]
	world_definition.created_at = world_details["created_at"]
	world_definition.file_path = world_details["file_path"]
	world_definition.map = _collect_map_definition(world_details)
	world_definition.network = _collect_network_definition()
	world_definition.transport = _collect_transport_definition()

	return world_definition


func _collect_map_definition(world_data: Dictionary) -> MapDefinition:
	var map_definition = MapDefinition.new()

	map_definition.size = world_data["map_size"]
	map_definition.initial_pos = world_data["camera_initial_pos"]
	map_definition.initial_zoom = world_data["camera_initial_zoom"]

	return map_definition


func _collect_network_definition() -> NetworkDefinition:
	var network_definition = NetworkDefinition.new()
	_sanitize_stale_node_priority_references_before_save()

	for segment in network_manager.get_segments():
		var segment_def = segment.get_definition()
		network_definition.segments.append(segment_def)

	for node in network_manager.get_nodes():
		var node_def = node.get_definition()
		network_definition.nodes.append(node_def)

	return network_definition


func _sanitize_stale_node_priority_references_before_save() -> void:
	var total_removed_priority_refs := 0
	var total_removed_stop_refs := 0

	for node in network_manager.get_nodes():
		var connected_destination_node_ids: Dictionary = { }
		for segment in network_manager.get_node_connected_segments(node.id):
			connected_destination_node_ids[segment.get_other_node_id(node.id)] = true

		var removed_priority_node_ids: Array[int] = []
		for destination_node_id in node.definition.priority_segments.duplicate():
			if not connected_destination_node_ids.has(destination_node_id):
				removed_priority_node_ids.append(destination_node_id)
				node.definition.priority_segments.erase(destination_node_id)

		var removed_stop_node_ids: Array[int] = []
		for destination_node_id in node.definition.stop_segments.duplicate():
			if not connected_destination_node_ids.has(destination_node_id):
				removed_stop_node_ids.append(destination_node_id)
				node.definition.stop_segments.erase(destination_node_id)

		total_removed_priority_refs += removed_priority_node_ids.size()
		total_removed_stop_refs += removed_stop_node_ids.size()

		if removed_priority_node_ids.size() > 0 or removed_stop_node_ids.size() > 0:
			print(
				"[DefinitionBuilder] Save sanitation for node %d: removed stale PRIORITY refs %s, STOP refs %s" % [
					node.id,
					str(removed_priority_node_ids),
					str(removed_stop_node_ids),
				],
			)

	if total_removed_priority_refs > 0 or total_removed_stop_refs > 0:
		print(
			"[DefinitionBuilder] Save sanitation summary: removed %d stale PRIORITY refs and %d stale STOP refs." % [
				total_removed_priority_refs,
				total_removed_stop_refs,
			],
		)


func _collect_transport_definition() -> TransportDefinition:
	var transport_definition = TransportDefinition.new()

	for preset in transport_manager.get_demand_presets():
		transport_definition.demand_presets.append(preset)

	for depot in transport_manager.get_depots():
		var depot_def = depot.get_definition()
		transport_definition.depots.append(depot_def)

	for terminal in transport_manager.get_terminals():
		var terminal_def = terminal.get_definition()
		transport_definition.terminals.append(terminal_def)

	for stop in transport_manager.get_stops():
		var stop_def = stop.get_definition()
		transport_definition.stops.append(stop_def)

	for line in transport_manager.get_lines():
		var line_def = line.get_definition()
		transport_definition.lines.append(line_def)

	return transport_definition
