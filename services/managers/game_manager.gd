extends RefCounted

class_name GameManager

enum SelectionType {
	NONE,
	VEHICLE,
	NODE,
	STOPPER,
	SPAWNER_BUILDING,
	TERMINAL,
	TRANSPORT_STOP,
	DEPOT,
}

var selected_object: Object = null
var selection_type: SelectionType = SelectionType.NONE
var selection_popup_id: Variant = null
var debug_selection: bool = false
var vehicle_with_path_drawn: Vehicle = null

var ui_manager: UIManager
var config_manager: ConfigManager
var line_helper: LineHelper
var simulation_manager: SimulationManager
var vehicle_manager: VehicleManager
var network_manager: NetworkManager
var buildings_manager: BuildingsManager
var pathing_manager: PathingManager
var world_manager: WorldManager
var transport_manager: TransportManager

var game_controller: GameController

var world_definition: WorldDefinition

var game_speed: Enums.GameSpeed = Enums.GameSpeed.PAUSE
var initialized: bool = false
var game_menu_visible: bool = false
var clock = ClockManager.new()

signal game_speed_changed(new_speed: Enums.GameSpeed)
signal world_loading_progress(action: String, progress: float)


func setup(_game_controller: GameController) -> void:
	game_controller = _game_controller

	ui_manager = GDInjector.inject("UIManager") as UIManager
	simulation_manager = GDInjector.inject("SimulationManager") as SimulationManager
	vehicle_manager = GDInjector.inject("VehicleManager") as VehicleManager
	line_helper = GDInjector.inject("LineHelper") as LineHelper
	network_manager = GDInjector.inject("NetworkManager") as NetworkManager
	buildings_manager = GDInjector.inject("BuildingsManager") as BuildingsManager
	pathing_manager = GDInjector.inject("PathingManager") as PathingManager
	world_manager = GDInjector.inject("WorldManager") as WorldManager
	transport_manager = GDInjector.inject("TransportManager") as TransportManager

	vehicle_manager.set_vehicles_layer(game_controller.get_map().get_drawing_layer("VehiclesLayer"))

	simulation_manager.setup(game_controller)


func get_camera_bounds() -> Rect2:
	return game_controller.get_camera_bounds()


func initialize_game(world_file_path: String = "") -> void:
	if initialized:
		return

	if world_file_path == "":
		world_file_path = world_manager.GetDefaultWorldFilePath()

	print("Loading world from file: %s" % world_file_path)

	var world_def = world_manager.LoadSerializedWorldDefinition(world_file_path)

	if not world_def['definition']:
		push_error("Failed to load world definition from file: %s" % world_file_path)
		ui_manager.show_ui_view(
			MessageBoxView.VIEW_NAME,
			{
				"title": "Error during world load",
				"message": "Failed to parse world definition from file: %s\n\nAdditional info: %s" % [
					world_file_path,
					world_def['parsingError'] if world_def.has('parsingError') else "None",
				],
			},
		)

		return

	var parsed_def = WorldDefinition.deserialize(world_def.definition)

	self.world_definition = parsed_def

	initialized = true
	ui_manager.hide_main_menu()
	set_game_speed(Enums.GameSpeed.PAUSE)

	await game_controller.initialize_game(world_definition)
	simulation_manager.start_simulation()


func dispose_game() -> void:
	if not initialized:
		return

	initialized = false
	simulation_manager.stop_simulation()

	ui_manager.hide_all_ui_views()
	ui_manager.reset_ui_views()

	var map = game_controller.get_map()
	map.clear_layers()

	hide_game_menu()
	clear_state()
	ui_manager.show_main_menu()


func is_game_initialized() -> bool:
	return initialized


func show_game_menu() -> void:
	ui_manager.show_ui_view("GameMenuView")
	game_menu_visible = true
	set_game_speed(Enums.GameSpeed.PAUSE)


func hide_game_menu() -> void:
	ui_manager.hide_ui_view("GameMenuView")
	game_menu_visible = false


func toggle_game_menu() -> void:
	if game_menu_visible:
		hide_game_menu()
	else:
		show_game_menu()


func is_game_menu_visible() -> bool:
	return game_menu_visible


func push_loading_progress(action: String, progress: float) -> void:
	world_loading_progress.emit(action, progress)


func get_map() -> Map:
	return game_controller.get_map()


func set_game_speed(speed: Enums.GameSpeed) -> void:
	game_speed = speed

	match game_speed:
		Enums.GameSpeed.PAUSE:
			Engine.time_scale = 0.0
		Enums.GameSpeed.LOW:
			Engine.time_scale = 1.0
		Enums.GameSpeed.MEDIUM:
			Engine.time_scale = 2.0
		Enums.GameSpeed.HIGH:
			Engine.time_scale = 4.0
			Engine.physics_ticks_per_second = 80
		Enums.GameSpeed.TURBO:
			Engine.time_scale = 10.0
			Engine.physics_ticks_per_second = 120

	game_speed_changed.emit(game_speed)


func get_game_speed() -> Enums.GameSpeed:
	return game_speed


func set_selection(object: Object, type: SelectionType) -> void:
	if selection_type != type:
		if selection_popup_id:
			ui_manager.hide_ui_view(selection_popup_id)
			selection_popup_id = null

	selection_type = type
	selected_object = object

	match type:
		SelectionType.NONE:
			selected_object = null
		SelectionType.VEHICLE:
			selection_popup_id = "VehiclePopupView"
		SelectionType.SPAWNER_BUILDING:
			selection_popup_id = "SpawnerBuildingPopupView"
		SelectionType.DEPOT:
			selection_popup_id = DepotPopupView.VIEW_NAME
		SelectionType.NODE, SelectionType.STOPPER, SelectionType.TRANSPORT_STOP, SelectionType.TERMINAL:
			pass
		_:
			push_error("Unknown selection type: %s" % str(type))
			selection_type = SelectionType.NONE
			selected_object = null

	if selection_popup_id:
		ui_manager.show_ui_view(selection_popup_id)


func clear_selection() -> void:
	set_selection(null, SelectionType.NONE)


func get_selection() -> Dictionary:
	return {
		"object": selected_object,
		"type": selection_type,
	}


func get_selected_object() -> Object:
	return selected_object


func get_selection_type() -> SelectionType:
	return selection_type


func is_debug_pick_enabled() -> bool:
	return debug_selection


func try_hit_debug_pick(object: Object) -> bool:
	if not debug_selection:
		return false

	if selection_type == SelectionType.VEHICLE and selected_object == (object as Vehicle):
		debug_selection = false
		return true

	if selection_type == SelectionType.NODE and selected_object == (object as RoadNode):
		debug_selection = false
		return true

	if selection_type == SelectionType.STOPPER and selected_object == (object as LaneStopper):
		debug_selection = false
		return true

	if selection_type == SelectionType.SPAWNER_BUILDING and selected_object == (object as SpawnerBuilding):
		debug_selection = false
		return true

	return false


func jump_to_selection() -> void:
	if not selected_object:
		return

	var global_position: Vector2

	match selection_type:
		SelectionType.VEHICLE:
			var vehicle = selected_object as Vehicle
			global_position = vehicle.global_position
		SelectionType.NODE:
			var node = selected_object as RoadNode
			global_position = node.position
		SelectionType.STOPPER:
			var stopper = selected_object as LaneStopper
			global_position = stopper.global_position
		SelectionType.SPAWNER_BUILDING:
			var spawner = selected_object as SpawnerBuilding
			global_position = spawner.global_position
		SelectionType.TRANSPORT_STOP:
			var stop = selected_object as Stop
			global_position = stop.global_position
		SelectionType.TERMINAL:
			var terminal = selected_object as Terminal
			global_position = terminal.global_position
		_:
			return

	game_controller.get_camera().set_camera_position(global_position)


func draw_vehicle_route(vehicle: Vehicle) -> void:
	if not vehicle:
		return

	var route_layer = game_controller.get_map().get_drawing_layer("VehicleRouteLayer") as Node2D
	if not route_layer:
		return

	var route = vehicle.get_all_trip_curves()

	vehicle_with_path_drawn = vehicle

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
	if not vehicle_with_path_drawn:
		return

	if vehicle_with_path_drawn.navigator.is_connected("trip_rerouted", Callable(self, "redraw_route")):
		vehicle_with_path_drawn.navigator.trip_rerouted.disconnect(Callable(self, "redraw_route"))

	var route_layer = game_controller.get_map().get_drawing_layer("VehicleRouteLayer") as Node2D
	if not route_layer:
		return

	for curve in route_layer.get_children():
		curve.queue_free()


func redraw_route() -> void:
	if not vehicle_with_path_drawn:
		return

	call_deferred("clear_drawn_route")
	call_deferred("draw_vehicle_route", vehicle_with_path_drawn)


func clear_state() -> void:
	selected_object = null
	selection_type = SelectionType.NONE
	selection_popup_id = null
	debug_selection = false
	vehicle_with_path_drawn = null

	simulation_manager.vehicles_count = 0
	pathing_manager.clear_state()
	vehicle_manager.clear_state()
	network_manager.clear_state()
	buildings_manager.clear_state()
	transport_manager.clear_state()
