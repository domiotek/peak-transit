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

	for segment in network_manager.get_segments():
		var segment_def = segment.get_definition()
		network_definition.segments.append(segment_def)

	for node in network_manager.get_nodes():
		var node_def = node.get_definition()
		network_definition.nodes.append(node_def)

	return network_definition


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

	return transport_definition
