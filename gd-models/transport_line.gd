class_name TransportLine

var id: int
var display_number: int
var color_hex: Color

var _line_def: LineDefinition
signal pathfinder_resolved()
var _pathfinder_result: Variant
var _traced_paths: Array = []
var _start_node_to_path_map: Dictionary = { }
var _route_curves: Dictionary = { }
var _waypoint_to_curve_map: Dictionary = { }
var _step_def_to_path_map: Dictionary = { }

var game_manager: GameManager = GDInjector.inject("GameManager") as GameManager
var network_manager: NetworkManager = GDInjector.inject("NetworkManager") as NetworkManager
var path_manager: PathingManager = GDInjector.inject("PathingManager") as PathingManager
var transport_manager: TransportManager = GDInjector.inject("TransportManager") as TransportManager
var line_helper: LineHelper = GDInjector.inject("LineHelper") as LineHelper


func setup(new_id: int, line_def: LineDefinition) -> void:
	id = new_id
	display_number = line_def.display_number if line_def.display_number >= 0 else new_id
	color_hex = Color(line_def.color_hex)
	_line_def = line_def


func trace_routes() -> bool:
	for route_def in _line_def.routes:
		var path = []
		var start_out_options = TransportHelper.resolve_starting_node_from_line_step(transport_manager, route_def[0])

		var last_step = null

		_step_def_to_path_map[0] = 0

		for i in range(route_def.size()):
			var step_def = route_def[i]

			if step_def == route_def[0]:
				continue

			var next_dest_options = TransportHelper.resolve_ending_node_from_line_step(step_def)

			var combinations = []
			for out_opt in start_out_options:
				for next_opt in next_dest_options:
					combinations.append(
						{
							"from_node": out_opt["from_node"],
							"from_endpoint": out_opt["from_endpoint"],
							"to_node": next_opt["to_node"],
							"to_endpoint": next_opt["to_endpoint"],
						},
					)

			path_manager.find_path_with_multiple_options(combinations, Callable(self, "_on_pathfinder_result"), VehicleManager.VehicleCategory.PUBLIC_TRANSPORT)
			await self.pathfinder_resolved

			if _pathfinder_result == null:
				push_error("Failed to trace path for route step in line ID %d" % id)
				return false

			last_step = _pathfinder_result.Path.pop_back()

			path += _pathfinder_result.Path

			_step_def_to_path_map[i] = path.size()

			start_out_options = [
				{
					"from_node": last_step["FromNodeId"],
					"from_endpoint": last_step["ViaEndpointId"],
				},
			]

		path.append(last_step)
		_step_def_to_path_map[route_def.size() - 1] = path.size() - 1

		_traced_paths.append(path)
		_start_node_to_path_map[path[0]["FromNodeId"]] = _traced_paths.size() - 1
		var waypoint_to_curve_map = _get_waypoints_to_curve_map(route_def, path)
		_waypoint_to_curve_map[_traced_paths.size() - 1] = waypoint_to_curve_map

	return true


func get_traced_path(route_idx: int) -> Array:
	return _traced_paths[route_idx]


func get_route_curves(route_idx: int) -> Array:
	if _route_curves.has(route_idx):
		return _route_curves[route_idx]

	var path = get_traced_path(route_idx)

	var target_route_def = get_route_definition(route_idx) as Array[RouteStepDefinition]
	var starting_terminal = transport_manager.get_terminal(target_route_def[0].target_id)
	var ending_terminal = transport_manager.get_terminal(target_route_def[target_route_def.size() - 1].target_id)

	var route_curves = network_manager.get_curves_of_path(path, starting_terminal, ending_terminal)
	_route_curves[route_idx] = route_curves

	return route_curves


func get_route_definition(route_idx: int) -> Array[RouteStepDefinition]:
	if _line_def.routes.size() > route_idx:
		return _line_def.routes[route_idx]

	push_error("No route definition for route index %d in line ID %d" % [route_idx, id])
	return []


func get_waypoint_to_curve_map(route_idx: int) -> Dictionary:
	return _waypoint_to_curve_map.get(route_idx, { })


func _on_pathfinder_result(path: Variant) -> void:
	_pathfinder_result = path
	emit_signal("pathfinder_resolved", path)


func _get_container_layer_for_route(route_id: int) -> Node2D:
	var lines_layer = game_manager.get_map().get_drawing_layer("LinesRoutesLayer") as Node2D
	if not lines_layer:
		return null

	var line_wrapper_name = "LineRoute_%d" % route_id

	var wrapper = lines_layer.find_child(line_wrapper_name) as Node2D

	if not wrapper:
		wrapper = Node2D.new()
		wrapper.name = line_wrapper_name
		lines_layer.add_child(wrapper)

	var route_layer = wrapper.find_child("%d" % route_id) as Node2D

	if not route_layer:
		route_layer = Node2D.new()
		route_layer.name = "%d" % route_id
		wrapper.add_child(route_layer)

	return route_layer


func _get_waypoints_to_curve_map(steps: Array, path: Array) -> Dictionary:
	var result: Dictionary = { }

	for i in range(steps.size()):
		var step = steps[i] as RouteStepDefinition

		if step.step_type != Enums.TransportRouteStepType.WAYPOINT:
			continue

		var path_idx = _step_def_to_path_map[i]
		var path_step = path[path_idx]

		var other_endpoint = network_manager.get_opposite_lane_endpoint(path_step.ViaEndpointId)
		var node = network_manager.get_node(path_step.ToNodeId)
		var next_step = path[path_idx + 1]

		var node_path = node.get_connection_path(other_endpoint.Id, next_step.ViaEndpointId)
		var global_curve = line_helper.convert_curve_local_to_global(node_path.curve, node)
		result[i] = global_curve

	return result
