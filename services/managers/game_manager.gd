extends RefCounted

class_name GameManager

enum SelectionType {
	NONE,
	VEHICLE
}

var camera_bounds: Rect2
var camera_projection_offset := Vector2(2, 1.35)
var camera_speed := 500.0
var camera_zoom_bounds: Array[Vector2] = [Vector2(0.5, 0.5), Vector2(6, 6)]
var map_size := Vector2(5000, 5000)
var initial_map_pos = Vector2(150, 900)

var selected_object: Object = null
var selection_type: SelectionType = SelectionType.NONE
var selection_popup_id: Variant = null

var ui_manager: UIManager
var config_manager: ConfigManager
var line_helper: LineHelper

var map: Map

func initialize(_map: Node2D, camera: Camera2D) -> void:
	ui_manager = GDInjector.inject("UIManager") as UIManager
	map = _map as Map

	map.map_size = map_size
	var rect_position = -map_size / 2
	camera_bounds = Rect2(rect_position, map_size)
	camera.set_camera_props(camera_bounds, camera_projection_offset, camera_zoom_bounds, camera_speed)
	camera.position = initial_map_pos

	var simulation_manager = GDInjector.inject("SimulationManager") as SimulationManager
	var vehicle_manager = GDInjector.inject("VehicleManager") as VehicleManager
	line_helper = GDInjector.inject("LineHelper") as LineHelper

	vehicle_manager.set_vehicles_layer(map.get_drawing_layer("VehiclesLayer"))

	simulation_manager.start_simulation()

func get_camera_bounds() -> Rect2:
	return camera_bounds

func set_selection(object: Object, type: SelectionType) -> void:
	selection_type = type
	selected_object = object

	if selection_type != type:
		if selection_popup_id:
			ui_manager.hide_ui_view_by_id(selection_popup_id)
			selection_popup_id = null

	match type:
		SelectionType.NONE:
			selected_object = null
		SelectionType.VEHICLE:
			selection_popup_id = "VehiclePopupView"
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
		"type": selection_type
	}

func get_selected_object() -> Object:
	return selected_object

func get_selection_type() -> SelectionType:
	return selection_type

func draw_vehicle_route(vehicle: Vehicle) -> void:
	if not vehicle:
		return

		
	var route_layer = map.get_drawing_layer("VehicleRouteLayer") as Node2D
	if not route_layer:
		return

	var route = vehicle.get_all_trip_curves()

	for curve in route:
		var curve2d = curve as Curve2D
	
		line_helper.convert_curve_global_to_local(curve2d, route_layer)

		var line2d = Line2D.new()
		line2d.width = 2
		line2d.default_color = Color.YELLOW
		
		var curve_length = curve2d.get_baked_length()
		if curve_length > 0:
			var sample_distance = 10.0
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

	var route_layer = map.get_drawing_layer("VehicleRouteLayer") as Node2D
	if not route_layer:
		return

	for curve in route_layer.get_children():
		curve.queue_free()
