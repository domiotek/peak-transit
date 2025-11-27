class_name TransportHelper

static func validate_stop_definition(network_manager: NetworkManager, stop_def: StopDefinition) -> String:
	var validation_result = validate_segment_object_position(network_manager, stop_def.position)

	if validation_result.has("error"):
		return validation_result["error"] as String

	var target_relation: NetRelation = validation_result["relation"]
	var offset: float = validation_result["offset"] as float

	for existing_stop_struct in target_relation.get_stops().values():
		var existing_stop_offset = existing_stop_struct.offset

		if abs(existing_stop_offset - offset) < NetworkConstants.MIN_STOP_DISTANCE:
			return "Too close to existing stop"

	for building_struct in target_relation.get_buildings().values():
		var building_offset = building_struct.offset

		if abs(building_offset - offset) < NetworkConstants.MIN_STOP_BUILDING_CLEARANCE:
			return "Too close to existing building"

	return ""


static func validate_terminal_definition(network_manager: NetworkManager, terminal_def: TerminalDefinition) -> String:
	var validation_result = validate_segment_object_position(network_manager, terminal_def.position)

	if validation_result.has("error"):
		return validation_result["error"] as String

	var target_relation: NetRelation = validation_result["relation"]
	var offset: float = validation_result["offset"] as float

	for existing_stop_struct in target_relation.get_stops().values():
		var existing_stop_offset = existing_stop_struct.offset

		if abs(existing_stop_offset - offset) < NetworkConstants.MIN_STOP_DISTANCE:
			return "Too close to existing stop"

	for building_struct in target_relation.get_buildings().values():
		var building_offset = building_struct.offset

		if abs(building_offset - offset) < NetworkConstants.MIN_TERMINAL_BUILDING_CLEARANCE:
			return "Too close to existing building"

	return ""


static func validate_line_definition(transport_manager: TransportManager, network_manager: NetworkManager, line_def: LineDefinition) -> String:
	if line_def.routes.size() != 2:
		return "Line must have exactly two routes"

	for route in line_def.routes:
		if route.size() < 2:
			return "Each route must have at least two steps"

		for step in route as Array[RouteStepDefinition]:
			var target_id = step.target_id

			match step.step_type:
				Enums.TransportRouteStepType.TERMINAL:
					var terminal_exists = transport_manager.terminal_exists(target_id)
					if not terminal_exists:
						return "Terminal ID not found in line '%s': %d" % [line_def.name, target_id]
				Enums.TransportRouteStepType.STOP:
					var stop_exists = transport_manager.stop_exists(target_id)
					if not stop_exists:
						return "Stop ID not found in line '%s': %d" % [line_def.name, target_id]
				Enums.TransportRouteStepType.WAYPOINT:
					var node = network_manager.get_node(target_id)
					if not node:
						return "Node ID not found in line '%s': %d" % [line_def.name, target_id]
				_:
					return "Unknown step type in line '%s'" % line_def.name

		if route[0].step_type != Enums.TransportRouteStepType.TERMINAL:
			return "First step of route must be a terminal in line '%s'" % line_def.name

		if route[route.size() - 1].step_type != Enums.TransportRouteStepType.TERMINAL:
			return "Last step of route must be a terminal in line '%s'" % line_def.name

	return ""


static func validate_segment_object_position(network_manager: NetworkManager, pos_def: SegmentPosDefinition) -> Dictionary:
	if pos_def.segment.size() != 2:
		return {
			"error": "Invalid segment size",
		}

	var node_a = network_manager.get_node(pos_def.segment[0])
	var node_b = network_manager.get_node(pos_def.segment[1])

	if not node_a or not node_b:
		return {
			"error": "Segment nodes not found in network",
		}

	var target_segment = network_manager.get_segment_between_nodes(node_a.id, node_b.id)

	if not target_segment:
		return {
			"error": "Nodes are not connected by a segment",
		}

	var target_relation: NetRelation = target_segment.get_relation_with_starting_node(node_a.id)

	if not target_relation:
		return {
			"error": "No relation found starting from the specified node",
		}

	if target_relation.relation_info.lanes.size() == 0:
		return {
			"error": "No lanes found in the target relation",
		}

	var target_lane_id = target_relation.get_rightmost_lane_id()

	var lane = target_segment.get_lane(target_lane_id)

	if not lane:
		return {
			"error": "Target lane not found in segment",
		}

	var lane_length = lane.get_length()

	var offset = pos_def.offset

	if offset < 0.0 or offset > lane_length:
		return {
			"error": "Offset out of bounds for lane length",
		}

	return {
		"segment": target_segment,
		"relation": target_relation,
		"lane": lane,
		"offset": offset,
	}


static func resolve_starting_node_from_line_step(transport_manager: TransportManager, step_def: RouteStepDefinition) -> Array:
	if step_def.step_type != Enums.TransportRouteStepType.TERMINAL:
		push_error("Starting node can only be resolved from terminal step.")
		return []

	var terminal = transport_manager.get_terminal(step_def.target_id)
	if terminal:
		var out_connections = terminal.get_out_connections()

		var combinations = []
		for out_conn in out_connections:
			var out_endpoint = out_conn["lane"].get_endpoint_by_type(true)

			combinations.append(
				{
					"from_node": out_endpoint.NodeId,
					"from_endpoint": out_endpoint.Id,
				},
			)
		return combinations

	return []


static func resolve_ending_node_from_line_step(step_def: RouteStepDefinition) -> Array:
	var network_manager: NetworkManager = GDInjector.inject("NetworkManager") as NetworkManager
	var transport_manager: TransportManager = GDInjector.inject("TransportManager") as TransportManager

	match step_def.step_type:
		Enums.TransportRouteStepType.TERMINAL:
			var terminal = transport_manager.get_terminal(step_def.target_id)
			if terminal:
				var in_connections = terminal.get_in_connections()

				var combinations = []
				for in_conn in in_connections:
					var in_endpoint = in_conn["lane"].get_endpoint_by_type(false)

					combinations.append(
						{
							"to_node": in_endpoint.NodeId,
							"to_endpoint": in_endpoint.Id,
						},
					)

				return combinations
		Enums.TransportRouteStepType.STOP:
			var stop = transport_manager.get_stop(step_def.target_id)
			if stop:
				var incoming_node_id = stop.get_outgoing_node_id()
				var lane = stop.get_lane()

				return [
					{
						"to_node": incoming_node_id,
						"to_endpoint": lane.get_endpoint_by_type(false).Id,
					},
				]
		Enums.TransportRouteStepType.WAYPOINT:
			var node = network_manager.get_node(step_def.target_id)

			var combinations = []

			for endpoint_id in node.incoming_endpoints:
				combinations.append(
					{
						"to_node": node.id,
						"to_endpoint": endpoint_id,
					},
				)

			return combinations

	return []


static func resolve_route_step_data(step_def: RouteStepDefinition, length: float) -> RouteStep:
	var network_manager: NetworkManager = GDInjector.inject("NetworkManager") as NetworkManager
	var transport_manager: TransportManager = GDInjector.inject("TransportManager") as TransportManager

	match step_def.step_type:
		Enums.TransportRouteStepType.TERMINAL:
			var terminal = transport_manager.get_terminal(step_def.target_id)
			if terminal:
				return RouteStep.new(
					step_def.step_type,
					terminal.get_terminal_name(),
					step_def.target_id,
					length,
					estimate_travel_time(length),
				)
		Enums.TransportRouteStepType.STOP:
			var stop = transport_manager.get_stop(step_def.target_id)
			if stop:
				return RouteStep.new(
					step_def.step_type,
					stop.get_stop_name(),
					step_def.target_id,
					length,
					estimate_travel_time(length),
				)
		Enums.TransportRouteStepType.WAYPOINT:
			var node = network_manager.get_node(step_def.target_id)
			if node:
				return RouteStep.new(
					step_def.step_type,
					"Node %d" % node.id,
					step_def.target_id,
					length,
					estimate_travel_time(length),
				)

	return null


static func estimate_travel_time(length: float, average_speed: float = SimulationConstants.AVERAGE_BUS_SPEED) -> float:
	if average_speed <= 0.0:
		return 0.0

	length = length * SimulationConstants.SIMULATION_WORLD_TO_GAME_UNITS_RATIO

	return length / average_speed * SimulationConstants.SIMULATION_REAL_SECONDS_PER_IN_GAME_MINUTE


static func draw_route(
		route_curves: Array,
		layer: Node2D,
		color_hex: Color,
		line_helper: LineHelper,
) -> void:
	for curve in route_curves as Array[Curve2D]:
		line_helper.convert_curve_global_to_local(curve, layer)

		var line2d = Line2D.new()
		line2d.width = 2
		line2d.default_color = color_hex

		var curve_length = curve.get_baked_length()
		if curve_length > 0:
			var sample_distance = 5.0
			var num_samples = int(curve_length / sample_distance) + 1

			for i in range(num_samples):
				var offset: float = 0.0
				if num_samples > 1:
					offset = (i * curve_length) / (num_samples - 1)
				var point = curve.sample_baked(offset)
				line2d.add_point(point)
		else:
			for i in range(curve.get_point_count()):
				line2d.add_point(curve.get_point_position(i))

		layer.add_child(line2d)

		var triangle_distance = NetworkConstants.PATH_DIRECTION_INDICATORS_OFFSET
		var triangle_size = NetworkConstants.PATH_DIRECTION_INDICATORS_SIZE
		var num_triangles = int(curve_length / triangle_distance)

		for i in range(1, num_triangles + 1):
			var offset = i * triangle_distance
			var position = curve.sample_baked(offset)
			var tangent = curve.sample_baked_with_rotation(offset).y

			var triangle = Polygon2D.new()
			var half_size = triangle_size / 2.0
			triangle.polygon = PackedVector2Array(
				[
					Vector2(0, -half_size),
					Vector2(half_size, half_size),
					Vector2(-half_size, half_size),
				],
			)
			triangle.color = color_hex.lerp(Color.WHITE, 0.3)
			triangle.position = position
			triangle.rotation = tangent.angle()

			layer.add_child(triangle)


static func draw_route_step_points(
		route_def: Array[RouteStepDefinition],
		layer: Node2D,
		color: Color,
		waypoints_to_curve_map: Dictionary,
		transport_manager: TransportManager,
) -> void:
	var stop_mark_scene = load("res://game-objects/stop-mark/stop_mark.tscn") as PackedScene
	var light_scene = load("res://game-objects/light/light.tscn") as PackedScene

	for step_idx in range(route_def.size()):
		var step = route_def[step_idx] as RouteStepDefinition

		match step.step_type:
			Enums.TransportRouteStepType.TERMINAL:
				pass # No visual for terminal steps yet
			Enums.TransportRouteStepType.STOP:
				var stop = transport_manager.get_stop(step.target_id)
				if stop:
					var stop_position = stop.get_global_position()
					var curve = stop.get_lane().get_curve()
					var curve_point = curve.get_closest_point(stop_position)

					var mark = stop_mark_scene.instantiate() as StopMark
					mark.position = curve_point
					mark.setup(color)
					layer.add_child(mark)
			Enums.TransportRouteStepType.WAYPOINT:
				var step_curve: Curve2D = waypoints_to_curve_map.get(step_idx, null)

				if step_curve:
					var curve_point = step_curve.sample_baked(step_curve.get_baked_length() / 2.0)
					var mark = light_scene.instantiate() as Light
					mark.position = curve_point
					mark.radius = 3.0
					mark.inactive_color = color.lerp(Color.WHITE, 0.7)
					mark.redraw()
					layer.add_child(mark)


static func get_container_layer_for_route(map: Map, line_id: int, route_idx: int) -> Node2D:
	var lines_layer = map.get_drawing_layer("LinesRoutesLayer") as Node2D
	if not lines_layer:
		return null

	var line_wrapper_name = "LineRoute_%d" % line_id

	var wrapper = lines_layer.find_child(line_wrapper_name, false, false) as Node2D

	if not wrapper:
		wrapper = Node2D.new()
		wrapper.name = line_wrapper_name
		lines_layer.add_child(wrapper)

	var route_layer = wrapper.find_child("%d" % route_idx, false, false) as Node2D

	if not route_layer:
		route_layer = Node2D.new()
		route_layer.name = "%d" % route_idx
		wrapper.add_child(route_layer)

	return route_layer
