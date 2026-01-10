extends BaseGameController

class_name ChallengeGameController

var transport_manager: TransportManager = GDInjector.inject("TransportManager") as TransportManager
var vehicle_manager: VehicleManager = GDInjector.inject("VehicleManager") as VehicleManager
var line_helper: LineHelper = GDInjector.inject("LineHelper") as LineHelper

var _vehicle_with_path_drawn: Vehicle = null


func _ready() -> void:
	super._ready()
	map.create_drawing_layer("VehiclesLayer")
	map.create_drawing_layer("VehicleRouteLayer")
	map.create_drawing_layer("LinesRoutesLayer")


func draw_vehicle_route(vehicle: Vehicle) -> void:
	if not vehicle:
		return

	var route_layer = map.get_drawing_layer("VehicleRouteLayer") as Node2D
	if not route_layer:
		return

	var route = vehicle.get_all_trip_curves()

	_vehicle_with_path_drawn = vehicle

	vehicle.navigator.trip_rerouted.connect(Callable(self, "redraw_route"))

	for curve in route:
		var curve2d = curve as Curve2D

		line_helper.convert_curve_global_to_local(curve2d, route_layer)

		var line2d = Line2D.new()
		line2d.width = 2
		line2d.default_color = Color.YELLOW

		var curve_length = curve2d.get_baked_length()
		if curve_length > 0:
			var sample_distance = 5.0
			var num_samples = int(curve_length / sample_distance) + 1

			for i in range(num_samples):
				var offset: float = 0.0
				if num_samples > 1:
					offset = (i * curve_length) / (num_samples - 1)
				var point = curve2d.sample_baked(offset)
				line2d.add_point(point)
		else:
			for i in range(curve2d.get_point_count()):
				line2d.add_point(curve2d.get_point_position(i))

		route_layer.add_child(line2d)


func clear_drawn_route() -> void:
	if not _vehicle_with_path_drawn:
		return

	if _vehicle_with_path_drawn.navigator.is_connected("trip_rerouted", Callable(self, "redraw_route")):
		_vehicle_with_path_drawn.navigator.trip_rerouted.disconnect(Callable(self, "redraw_route"))
	var route_layer = map.get_drawing_layer("VehicleRouteLayer") as Node2D
	if not route_layer:
		return

	for curve in route_layer.get_children():
		curve.queue_free()


func redraw_route() -> void:
	if not _vehicle_with_path_drawn:
		return

	call_deferred("clear_drawn_route")
	call_deferred("draw_vehicle_route", _vehicle_with_path_drawn)


func _on_initialize_game(world: WorldDefinition) -> void:
	vehicle_manager.set_vehicles_layer(map.get_drawing_layer("VehiclesLayer"))

	await _load_network_grid(world.network)
	await _load_transport_systems(world.transport)


func _after_initialize_game() -> void:
	ui_manager.show_ui_view(GameSpeedView.VIEW_NAME)
	ui_manager.show_ui_view(GameClockView.VIEW_NAME)
	ui_manager.show_ui_view(ShortcutsView.VIEW_NAME)

	simulation_manager.start_simulation()


func _on_input_check() -> void:
	if Input.is_action_just_pressed("game_speed_0"):
		if game_manager.get_game_speed() != Enums.GameSpeed.PAUSE:
			game_manager.set_game_speed(Enums.GameSpeed.PAUSE)
		else:
			game_manager.set_game_speed(Enums.GameSpeed.LOW)
		return

	if Input.is_action_just_pressed("game_speed_1"):
		game_manager.set_game_speed(Enums.GameSpeed.LOW)
		return

	if Input.is_action_just_pressed("game_speed_2"):
		game_manager.set_game_speed(Enums.GameSpeed.MEDIUM)
		return

	if Input.is_action_just_pressed("game_speed_3"):
		game_manager.set_game_speed(Enums.GameSpeed.HIGH)
		return

	if Input.is_action_just_pressed("game_speed_4"):
		game_manager.set_game_speed(Enums.GameSpeed.TURBO)
		return


func _on_load_world(file_path: String):
	if file_path == "":
		file_path = world_manager.GetDefaultWorldFilePath()

	return _load_world_from_file_path(file_path)


func _load_network_grid(network_def: NetworkDefinition) -> void:
	var network_grid = map.get_drawing_layer("RoadGrid") as NetworkGrid

	await network_grid.load_network_definition(network_def)


func _load_transport_systems(transport_def: TransportDefinition) -> void:
	for i in range(transport_def.demand_presets.size()):
		game_manager.push_loading_progress("Loading demand presets...", i / float(transport_def.demand_presets.size()))
		await get_tree().process_frame
		var preset_def = transport_def.demand_presets[i]
		transport_manager.register_demand_preset(preset_def)

	for i in range(transport_def.depots.size()):
		game_manager.push_loading_progress("Placing transport depots...", i / float(transport_def.depots.size()))
		await get_tree().process_frame
		var depot_def = transport_def.depots[i]
		transport_manager.register_depot(depot_def)

	for i in range(transport_def.terminals.size()):
		game_manager.push_loading_progress("Placing transport terminals...", i / float(transport_def.terminals.size()))
		await get_tree().process_frame
		var terminal_def = transport_def.terminals[i]
		transport_manager.register_terminal(terminal_def)

	for i in range(transport_def.stops.size()):
		game_manager.push_loading_progress("Placing transport stops...", i / float(transport_def.stops.size()))
		await get_tree().process_frame
		var stop_def = transport_def.stops[i]
		transport_manager.register_stop(stop_def)

	for i in range(transport_def.lines.size()):
		game_manager.push_loading_progress("Setting up transport lines...", i / float(transport_def.lines.size()))
		await get_tree().process_frame
		var line_def = transport_def.lines[i]
		await transport_manager.register_line(line_def)

	var lines = transport_manager.get_lines()
	for line_id in range(lines.size()):
		var transport_line = lines[line_id] as TransportLine
		game_manager.push_loading_progress("Generating schedules...", line_id / float(lines.size()))
		await get_tree().process_frame
		transport_manager.generate_line_schedule(transport_line)

	var registered_stops = transport_manager.get_stops()
	var registered_terminals = transport_manager.get_terminals()

	game_manager.push_loading_progress("Finalizing transport systems", 0)
	await get_tree().process_frame

	for stop_abs in registered_stops + registered_terminals:
		stop_abs.late_setup()
