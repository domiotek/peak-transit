class_name TransportManager

const StopScene = preload("res://game-objects/stop/stop.tscn")
var TerminalScene = load("res://game-objects/buildings/terminal/terminal.tscn")
var DepotScene = load("res://game-objects/buildings/depot/depot.tscn")

var _network_manager: NetworkManager
var _game_manager: GameManager
var _line_helper: LineHelper
var _schedule_generator: ScheduleGenerator
var _buildings_manager: BuildingsManager

var _demand_presets: Array = []

var _stop_ids: IDManager = IDManager.new()
var _stops: Dictionary = { }

var _terminal_ids: IDManager = IDManager.new()
var _terminals: Dictionary = { }

var _depot_ids: IDManager = IDManager.new()
var _depots: Dictionary = { }

var _lines: Dictionary = { }
var _drawn_lines: Dictionary = { }

var brigades: BrigadeManager


func inject_dependencies() -> void:
	_network_manager = GDInjector.inject("NetworkManager") as NetworkManager
	_game_manager = GDInjector.inject("GameManager") as GameManager
	_line_helper = GDInjector.inject("LineHelper") as LineHelper
	_schedule_generator = GDInjector.inject("ScheduleGenerator") as ScheduleGenerator
	_buildings_manager = GDInjector.inject("BuildingsManager") as BuildingsManager
	brigades = BrigadeManager.new()


func register_demand_preset(preset_def: DemandPresetDefinition) -> bool:
	var validation_error = TransportHelper.validate_demand_preset_definition(preset_def)

	if validation_error.length() > 0:
		push_error("Invalid demand preset definition: %s" % [validation_error])
		return false

	_demand_presets.append(preset_def)
	return true


func has_demand_preset(preset_id: int) -> bool:
	return preset_id >= 0 and preset_id < _demand_presets.size()


func get_demand_preset(preset_id: int) -> DemandPresetDefinition:
	if not has_demand_preset(preset_id):
		push_error("Demand preset ID not found: " + str(preset_id))
		return null

	return _demand_presets[preset_id] as DemandPresetDefinition


func get_demand_presets() -> Array:
	return _demand_presets


func register_stop(stop_def: StopDefinition) -> bool:
	var validation_error = TransportHelper.validate_stop_definition(_network_manager, self, stop_def)

	if validation_error.length() > 0:
		push_error("Invalid stop definition: %s - %s" % [stop_def.name, validation_error])
		return false

	var idx = _stop_ids.occupy_next_id()

	if not stop_def.name or stop_def.name == "":
		stop_def.name = "Stop %d" % idx

	var stop = StopScene.instantiate() as Stop

	var target_segment = _network_manager.get_segment_between_nodes(
		stop_def.position.segment[0],
		stop_def.position.segment[1],
	)

	var target_relation = target_segment.get_relation_with_starting_node(stop_def.position.segment[0]) as NetRelation
	var demand_preset = get_demand_preset(stop_def.demand_preset)

	stop.setup(idx, stop_def, target_segment, target_relation.id, demand_preset)

	target_segment.place_stop(stop)

	_stops[idx] = stop

	return true


func get_stop(stop_id: int) -> Stop:
	if not _stops.has(stop_id):
		push_error("Stop ID not found: " + str(stop_id))
		return null
	return _stops[stop_id] as Stop


func stop_exists(stop_id: int) -> bool:
	return _stops.has(stop_id)


func get_stops() -> Array:
	return _stops.values()


func unregister_stop(stop_id: int) -> void:
	if _stops.has(stop_id):
		var stop = _stops[stop_id] as Stop
		stop.get_segment().remove_stop(stop)
		_stops.erase(stop_id)
		_stop_ids.release_id(stop_id)
	else:
		push_error("Attempted to unregister non-existent stop with ID %d." % stop_id)


func register_terminal(terminal_def: TerminalDefinition) -> bool:
	var validation_error = TransportHelper.validate_terminal_definition(_network_manager, self, terminal_def)

	if validation_error.length() > 0:
		push_error("Invalid terminal definition: %s - %s" % [terminal_def.name, validation_error])
		return false

	var idx = _terminal_ids.occupy_next_id()

	if not terminal_def.name or terminal_def.name == "":
		terminal_def.name = "Terminal %d" % idx

	var terminal_building = TerminalScene.instantiate() as Terminal

	var target_segment = _network_manager.get_segment_between_nodes(
		terminal_def.position.segment[0],
		terminal_def.position.segment[1],
	)

	var target_relation = target_segment.get_relation_with_starting_node(terminal_def.position.segment[0]) as NetRelation

	var building_info = BuildingInfo.new()
	building_info.type = BuildingInfo.BuildingType.TERMINAL
	building_info.offset_position = terminal_def.position.offset

	var building_id = _buildings_manager.register_building(terminal_building)
	if building_id == -1:
		push_error("Failed to register terminal building for terminal: %s" % terminal_def.name)
		return false

	var demand_preset = get_demand_preset(terminal_def.demand_preset)

	terminal_building.id = building_id
	terminal_building.setup(target_relation.id, target_segment, building_info)
	terminal_building.setup_terminal(idx, terminal_def, demand_preset)

	target_segment.place_terminal(terminal_building)

	terminal_building.setup_connections()

	_terminals[idx] = terminal_building

	return true


func get_terminal(terminal_id: int) -> Terminal:
	if not _terminals.has(terminal_id):
		push_error("Terminal ID not found: " + str(terminal_id))
		return null
	return _terminals[terminal_id] as Terminal


func terminal_exists(terminal_id: int) -> bool:
	return _terminals.has(terminal_id)


func get_terminals() -> Array:
	return _terminals.values()


func unregister_terminal(terminal_id: int) -> void:
	if _terminals.has(terminal_id):
		var terminal = _terminals[terminal_id] as Terminal
		terminal.segment.remove_terminal(terminal)
		_buildings_manager.destroy_building(terminal.id)
		_terminals.erase(terminal_id)
		_terminal_ids.release_id(terminal_id)
	else:
		push_error("Attempted to unregister non-existent terminal with ID %d." % terminal_id)


func register_depot(depot_def: DepotDefinition) -> bool:
	var validation_error = TransportHelper.validate_depot_definition(_network_manager, depot_def)

	if validation_error.length() > 0:
		push_error("Invalid depot definition: %s - %s" % [depot_def.name, validation_error])
		return false

	var idx = _depot_ids.occupy_next_id()

	if not depot_def.name or depot_def.name == "":
		depot_def.name = "Depot %d" % idx

	var depot_building = DepotScene.instantiate() as Depot

	var target_segment = _network_manager.get_segment_between_nodes(
		depot_def.position.segment[0],
		depot_def.position.segment[1],
	)

	var target_relation = target_segment.get_relation_with_starting_node(depot_def.position.segment[0]) as NetRelation
	var building_info = BuildingInfo.new()
	building_info.type = BuildingInfo.BuildingType.DEPOT
	building_info.offset_position = depot_def.position.offset

	var building_id = _buildings_manager.register_building(depot_building)
	if building_id == -1:
		push_error("Failed to register depot building for depot: %s" % depot_def.name)
		return false

	depot_building.id = building_id
	depot_building.setup(target_relation.id, target_segment, building_info)
	depot_building.setup_depot(idx, depot_def)

	target_segment.place_depot(depot_building)

	depot_building.setup_connections()

	_depots[idx] = depot_building

	return true


func get_depot(depot_id: int) -> Depot:
	if not _depots.has(depot_id):
		push_error("Depot ID not found: " + str(depot_id))
		return null
	return _depots[depot_id] as Depot


func depot_exists(depot_id: int) -> bool:
	return _depots.has(depot_id)


func unregister_depot(depot_id: int) -> void:
	if _depots.has(depot_id):
		var depot = _depots[depot_id] as Depot
		depot.segment.remove_depot(depot)
		_buildings_manager.destroy_building(depot.id)
		_depots.erase(depot_id)
		_depot_ids.release_id(depot_id)
	else:
		push_error("Attempted to unregister non-existent depot with ID %d." % depot_id)


func get_depots() -> Array:
	return _depots.values()


func register_line(line_def: LineDefinition) -> bool:
	var validation_error = TransportHelper.validate_line_definition(self, _network_manager, line_def)

	if validation_error.length() > 0:
		push_error("Invalid line definition: %s - %s" % [line_def.name, validation_error])
		return false

	var idx = _get_next_idx(_lines)

	var line = TransportLine.new() as TransportLine

	line.setup(idx, line_def)

	_lines[idx] = line

	if not await line.trace_routes():
		push_error("Failed to trace paths for routes of line: %s" % line_def.name)
		return false

	return true


func get_line(line_id: int) -> TransportLine:
	if not _lines.has(line_id):
		push_error("Line ID not found: " + str(line_id))
		return null
	return _lines[line_id] as TransportLine


func line_exists(line_id: int) -> bool:
	return _lines.has(line_id)


func get_lines() -> Array:
	return _lines.values()


func generate_line_schedule(line: TransportLine) -> void:
	var routes = line.get_routes()

	var serialized_routes = { }

	for route_idx in routes.keys():
		serialized_routes[route_idx] = []

		var route_steps = routes[route_idx] as Array[RouteStep]

		var accumulated_time = 0
		for idx in range(route_steps.size()):
			var step = route_steps[idx] as RouteStep

			accumulated_time += TransportHelper.estimate_travel_time(step.length)

			if step.step_type == Enums.TransportRouteStepType.WAYPOINT:
				continue

			var trip_step = TripStep.new()
			trip_step.step_id = idx
			trip_step.travel_time = ceil(accumulated_time)

			serialized_routes[route_idx].append(trip_step.serialize())
			accumulated_time = 0

	var start_time_dict = null
	var start_time = line.get_start_time()
	if start_time:
		start_time_dict = start_time.serialize()

	var end_time_dict = null
	var end_time = line.get_end_time()
	if end_time:
		end_time_dict = end_time.serialize()

	var schedule_data = _schedule_generator.GenerateSchedule(
		serialized_routes,
		line.get_frequency_minutes(),
		line.get_min_layover_minutes(),
		start_time_dict,
		end_time_dict,
	)

	var brigades_ids: Array = []

	for schedule_dict in schedule_data:
		var brigade_schedule = BrigadeSchedule.deserialize(schedule_dict as Dictionary)
		brigades_ids.append(brigades.register(brigade_schedule, line.id, line.display_number, brigades_ids.size(), line.color_hex))

	line.assign_brigades(brigades_ids)


func draw_line_route(transport_line: TransportLine, route_idx: int) -> void:
	var layer = TransportHelper.get_container_layer_for_route(_game_manager.get_map(), transport_line.id, route_idx)

	if not layer:
		return

	if layer.get_child_count() > 0:
		layer.visible = true
		_update_drawn_lines(transport_line.id, route_idx, true)
		return #already drawn, just show it

	var path = transport_line.get_traced_path(route_idx)

	if path.size() == 0:
		push_error("No traced path to draw for route index %d in line ID %d" % [route_idx, transport_line.id])
		return

	var curves = transport_line.get_route_curves(route_idx)
	var target_route_def = transport_line.get_route_definition(route_idx) as Array[RouteStepDefinition]

	TransportHelper.draw_route(curves, layer, transport_line.color_hex, _line_helper)

	TransportHelper.draw_route_step_points(
		target_route_def,
		layer,
		transport_line.color_hex,
		transport_line.get_waypoint_to_curve_map(route_idx),
		self,
	)

	_update_drawn_lines(transport_line.id, route_idx, true)


func hide_line_route_drawing(line: TransportLine, route_idx: int) -> void:
	var layer = TransportHelper.get_container_layer_for_route(_game_manager.get_map(), line.id, route_idx)

	if not layer:
		return

	layer.visible = false
	_update_drawn_lines(line.id, route_idx, false)


func draw_line_routes(line: TransportLine) -> void:
	for route_idx in [0, 1]:
		draw_line_route(line, route_idx)


func hide_line_route_drawings(line: TransportLine) -> void:
	for route_idx in [0, 1]:
		hide_line_route_drawing(line, route_idx)


func draw_all_lines() -> void:
	for line in _lines.values():
		var transport_line = line as TransportLine
		draw_line_routes(transport_line)


func hide_all_line_drawings() -> void:
	for line in _lines.values():
		var transport_line = line as TransportLine
		hide_line_route_drawings(transport_line)


func is_line_route_drawn(line_id: int, route_idx: int) -> bool:
	if not _drawn_lines.has(line_id):
		return false

	var line_routes = _drawn_lines[line_id] as Array

	return line_routes.has(route_idx)


func get_drawn_lines() -> Dictionary:
	return _drawn_lines


func is_line_drawn(line_id: int) -> bool:
	if not _drawn_lines.has(line_id):
		return false

	var line_routes = _drawn_lines[line_id] as Array
	return line_routes.size() > 0


func get_drawn_routes_for_line(line_id: int) -> Array:
	if not _drawn_lines.has(line_id):
		return []

	return _drawn_lines[line_id] as Array


func are_all_lines_drawn() -> bool:
	return _lines.size() == _drawn_lines.size()


func are_no_lines_drawn() -> bool:
	return _drawn_lines.size() == 0


func clear_state() -> void:
	_demand_presets.clear()
	_stops.clear()
	_terminals.clear()
	_depots.clear()
	_lines.clear()
	_drawn_lines.clear()
	brigades.clear_state()

	_stop_ids.reset()
	_terminal_ids.reset()
	_depot_ids.reset()


func _get_next_idx(dict: Dictionary) -> int:
	return dict.size()


func _update_drawn_lines(line_id: int, route_idx: int, drawn: bool) -> void:
	if not _drawn_lines.has(line_id):
		_drawn_lines[line_id] = []

	if drawn:
		_drawn_lines[line_id].append(route_idx)
	else:
		_drawn_lines[line_id].erase(route_idx)
		if _drawn_lines[line_id].size() == 0:
			_drawn_lines.erase(line_id)
