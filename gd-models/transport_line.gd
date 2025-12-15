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
var _route_steps: Dictionary = { }
var _terminals: Array = []
var _route_stops: Dictionary = { }

var _brigade_ids: Array = []

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
	for route_idx in range(_line_def.routes.size()):
		var route_def = _line_def.routes[route_idx] as Array[RouteStepDefinition]

		_route_steps[route_idx] = []
		_route_stops[route_idx] = []
		var path = []
		var route_curves = []
		var start_out_options = TransportHelper.resolve_starting_node_from_line_step(transport_manager, route_def[0])

		var last_step = null

		_step_def_to_path_map[0] = 0

		for i in range(route_def.size()):
			var step_def = route_def[i]

			if i == 0:
				var terminal = transport_manager.get_terminal(step_def.target_id)
				_terminals.append(terminal)

				_route_steps[route_idx].append(TransportHelper.resolve_route_step_data(step_def, 0.0))
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

			last_step = _pathfinder_result.Path[_pathfinder_result.Path.size() - 1]

			path += _pathfinder_result.Path.slice(0, _pathfinder_result.Path.size() - 1)

			_step_def_to_path_map[i] = path.size()

			var curves = _get_curves_of_step(route_def, i)
			route_curves.append_array(curves)

			_route_steps[route_idx].append(TransportHelper.resolve_route_step_data(step_def, line_helper.get_curves_total_length(curves)))

			start_out_options = [
				{
					"from_node": last_step["FromNodeId"],
					"from_endpoint": last_step["ViaEndpointId"],
				},
			]

			if step_def.step_type == Enums.TransportRouteStepType.STOP:
				var stop = transport_manager.get_stop(step_def.target_id)
				stop.register_line(self.id)

		path.append(last_step)
		_step_def_to_path_map[route_def.size() - 1] = path.size() - 1

		_traced_paths.append(path)
		_route_curves[route_idx] = route_curves
		_start_node_to_path_map[path[0]["FromNodeId"]] = _traced_paths.size() - 1
		var waypoint_to_curve_map = _get_waypoints_to_curve_map(route_def, path)
		_waypoint_to_curve_map[_traced_paths.size() - 1] = waypoint_to_curve_map

		var actual_idx = 0
		var accumulated_length: float = 0.0
		var accumulated_time: float = 0.0
		var total_length = 0.0
		for step_idx in range(_route_steps[route_idx].size()):
			var route_step = _route_steps[route_idx][step_idx] as RouteStep

			accumulated_length += route_step.length
			accumulated_time += route_step.time_for_step
			total_length += accumulated_length

			if route_step.step_type == Enums.TransportRouteStepType.WAYPOINT:
				continue

			actual_idx += 1
			_route_stops[route_idx].append(
				LineStop.new(
					self,
					actual_idx,
					route_step.step_type == Enums.TransportRouteStepType.TERMINAL,
					route_step.target_id,
					route_step.target_name,
					total_length,
					accumulated_length,
					accumulated_time,
					route_step.can_wait,
				),
			)

			accumulated_length = 0.0
			accumulated_time = 0.0

	for i in range(_terminals.size()):
		var terminal = _terminals[i]

		terminal.register_line(self.id)
		var in_curves = terminal.get_line_curves(self.id, false)
		var out_curves = terminal.get_line_curves(self.id, true)

		if i == 0:
			_route_curves[0] = out_curves + _route_curves[0]
			_route_curves[1] = _route_curves[1] + in_curves
		else:
			_route_curves[0] = _route_curves[0] + in_curves
			_route_curves[1] = out_curves + _route_curves[1]

	return true


func get_traced_path(route_idx: int) -> Array:
	return _traced_paths[route_idx]


func get_route_curves(route_idx: int) -> Array:
	if _route_curves.has(route_idx):
		return _route_curves[route_idx]

	push_error("No route curves for route index %d in line ID %d" % [route_idx, id])
	return []


func get_route_definition(route_idx: int) -> Array[RouteStepDefinition]:
	if _line_def.routes.size() > route_idx:
		return _line_def.routes[route_idx]

	push_error("No route definition for route index %d in line ID %d" % [route_idx, id])
	return []


func get_waypoint_to_curve_map(route_idx: int) -> Dictionary:
	return _waypoint_to_curve_map.get(route_idx, { })


func get_route_steps(route_idx: int) -> Array:
	return _route_steps.get(route_idx, [])


func get_route_stops(route_idx: int) -> Array:
	return _route_stops.get(route_idx, [])


func get_routes() -> Dictionary:
	return _route_steps


func get_route_path(route_idx: int) -> Array:
	return _traced_paths[route_idx]


func assign_brigades(ids: Array) -> void:
	_brigade_ids = ids


func get_brigade_count() -> int:
	return _brigade_ids.size()


func get_brigade_ids() -> Array:
	return _brigade_ids


func get_brigades() -> Array:
	var result: Array = []

	var full_brigades = transport_manager.brigades.get_all()

	for brigade_id in _brigade_ids:
		result.append(full_brigades[brigade_id])

	return result


func get_start_time() -> TimeOfDay:
	return _line_def.start_time


func get_end_time() -> TimeOfDay:
	return _line_def.end_time


func get_frequency_minutes() -> int:
	return _line_def.frequency_minutes


func get_min_layover_minutes() -> int:
	return _line_def.min_layover_minutes


func get_departure_terminal_of_route(route_idx: int) -> Terminal:
	if route_idx < 0 or route_idx >= _terminals.size():
		return null

	return _terminals[route_idx]


func get_arrival_terminal_of_route(route_idx: int) -> Terminal:
	var other_route_idx = (route_idx + 1) % _terminals.size()

	if other_route_idx < 0 or other_route_idx >= _terminals.size():
		return null

	return _terminals[other_route_idx]


func get_departures_at_terminal(terminal_id: int, after: TimeOfDay = null, limit: int = -1, sort: bool = true) -> Array:
	var route_idx = _terminals.find_custom(
		func(t) -> bool:
			return t.terminal_id == terminal_id
	)

	if route_idx == -1:
		push_error("Terminal ID %d not found in line ID %d" % [terminal_id, id])
		return []

	return _find_departure_times_with_step(route_idx, Enums.TransportRouteStepType.TERMINAL, terminal_id, after, limit, sort)


func get_departures_at_stop(stop_id: int, after: TimeOfDay = null, limit: int = -1, sort: bool = true) -> Array:
	var route_idx = _find_route_idx_of_stop(stop_id)

	if route_idx == -1:
		push_error("Stop ID %d not found in line ID %d" % [stop_id, id])
		return []

	return _find_departure_times_with_step(route_idx, Enums.TransportRouteStepType.STOP, stop_id, after, limit, sort)


func get_route_destination_name(route_idx: int) -> String:
	if route_idx < 0 or route_idx >= _terminals.size():
		return ""

	var other_route_idx = (route_idx + 1) % _terminals.size()

	var terminal = _terminals[other_route_idx]
	return terminal.get_terminal_name()


func _find_route_idx_of_stop(stop_id: int) -> int:
	for route_idx in _route_steps.keys():
		var steps = _route_steps[route_idx] as Array

		for step in steps:
			if step.step_type == Enums.TransportRouteStepType.STOP and step.target_id == stop_id:
				return route_idx

	return -1


func _find_departure_times_with_step(
		route_idx: int,
		step_type: Enums.TransportRouteStepType,
		target_id: int,
		after: TimeOfDay = null,
		limit: int = -1,
		sort: bool = true,
) -> Array:
	var step_idx = 0

	for idx in range(_route_steps[route_idx].size()):
		var step = _route_steps[route_idx][idx] as RouteStep

		if step.step_type == step_type and step.target_id == target_id:
			step_idx = idx
			break

	var brigades = get_brigades()
	var target_dep_times: Array = []

	for brigade in brigades as Array[Brigade]:
		var trips = brigade.get_schedule().trips

		var trips_taken = 0

		for trip_idx in range(trips.size()):
			var trip = trips[trip_idx] as Trip
			if trip.route_id != route_idx:
				continue

			var time = trip.stop_times[step_idx]

			if after != null and time.to_minutes() < after.to_minutes():
				continue

			if limit != -1 and trips_taken >= limit:
				break

			target_dep_times.append(
				{
					"line_id": id,
					"line_display_number": display_number,
					"line_color_hex": color_hex,
					"trip_idx": trip_idx,
					"direction": get_route_destination_name(route_idx),
					"brigade_id": brigade.id,
					"departure_time": time,
				},
			)
			trips_taken += 1

	if sort:
		target_dep_times.sort_custom(
			func(a: TimeOfDay, b: TimeOfDay) -> bool:
				return a.to_minutes() < b.to_minutes()
		)

	return target_dep_times


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


func _get_curves_of_step(steps: Array, step_idx: int) -> Array:
	var starting_building = null
	var ending_building = null
	var last_step_idx = steps.size() - 1

	var prev_step_def = steps[step_idx - 1]
	var step_def = steps[step_idx]

	match step_idx:
		1:
			starting_building = transport_manager.get_terminal(steps[0].target_id)
		last_step_idx:
			ending_building = transport_manager.get_terminal(steps[last_step_idx].target_id)

	var step_curves = network_manager.get_curves_of_path(_pathfinder_result.Path, starting_building, ending_building)

	match prev_step_def.step_type:
		Enums.TransportRouteStepType.WAYPOINT:
			step_curves = step_curves.slice(1, step_curves.size())
		Enums.TransportRouteStepType.STOP:
			var stop_curve = step_curves[0]
			var stop = transport_manager.get_stop(prev_step_def.target_id)
			var stop_position = stop.get_global_position()

			var curve_point = stop_curve.get_closest_point(stop_position)
			step_curves[0] = line_helper.trim_curve(stop_curve, curve_point, stop_curve.sample_baked(stop_curve.get_baked_length()))

	if step_def.step_type == Enums.TransportRouteStepType.STOP:
		var stop_curve = step_curves[step_curves.size() - 1]
		var stop = transport_manager.get_stop(step_def.target_id)
		var stop_position = stop.get_global_position()

		var curve_point = stop_curve.get_closest_point(stop_position)
		step_curves[step_curves.size() - 1] = line_helper.trim_curve(stop_curve, stop_curve.sample_baked(0), curve_point)

	return step_curves
