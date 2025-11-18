extends Node2D

class_name RoadNode

@onready var layerHelper = GDInjector.inject("NodeLayerHelper") as NodeLayerHelper
@onready var circle_helper = GDInjector.inject("DebugCircleHelper") as DebugCircleHelper
@onready var lane_calculator = GDInjector.inject("LaneCalculator") as LaneCalculator
@onready var connections_helper = GDInjector.inject("ConnectionsHelper") as ConnectionsHelper
@onready var config_manager = GDInjector.inject("ConfigManager") as ConfigManager
@onready var line_helper = GDInjector.inject("LineHelper") as LineHelper
@onready var segment_helper = GDInjector.inject("SegmentHelper") as SegmentHelper
@onready var network_manager = GDInjector.inject("NetworkManager") as NetworkManager
@onready var game_manager = GDInjector.inject("GameManager") as GameManager

@export var id: int
var definition: NetNodeInfo
var connections: Dictionary = { }
var incoming_endpoints: Array = []
var outgoing_endpoints: Array = []

var connection_paths: Dictionary = { }
var connection_directions: Dictionary = { }

var corner_points: PackedVector2Array = []
var connected_segments: Array = []
var segment_directions: Dictionary = { }
var segment_priorities: Dictionary = { }
var is_priority_based: bool = false

var intersection_manager: IntersectionManager

@onready var debug_layer: Node2D = $DebugLayer
@onready var markings_layer: Node2D = $MarkingsLayer
@onready var main_layer: Polygon2D = $MainLayer
@onready var coating_layer: Node2D = $CoatingLayer
@onready var under_layer: Polygon2D = $UnderLayer
@onready var boundary_layer: Polygon2D = $BoundaryLayer
@onready var pathing_layer: Node2D = $PathingLayer
@onready var top_layer: Node2D = $TopLayer


func _ready() -> void:
	config_manager.DebugToggles.ToggleChanged.connect(_on_debug_toggles_changed)


func _process(delta: float) -> void:
	if game_manager.is_debug_pick_enabled() && game_manager.try_hit_debug_pick(self):
		print("Debug pick triggered for node ID %d" % id)
		breakpoint

	if not intersection_manager:
		return

	intersection_manager.process_tick(delta)


func update_visuals() -> void:
	connected_segments = network_manager.get_node_connected_segments(id)

	_fill_segment_priorities()

	var max_lanes = 0

	for segment in connected_segments:
		if segment.total_lanes > max_lanes:
			max_lanes = segment.total_lanes

	if connected_segments.size() > 0:
		var node_width = max_lanes * NetworkConstants.LANE_WIDTH

		if connected_segments.size() > 2:
			corner_points = layerHelper.find_intersection_corners(connected_segments)

			main_layer.polygon = layerHelper.create_precise_intersection_layer(self, connected_segments, corner_points)
			var coatings = line_helper.get_polygon_chunks(main_layer, NetworkConstants.LANE_WIDTH)
			for coating in coatings:
				coating.color = Color(0.2, 0.2, 0.2)
				coating_layer.add_child(coating)

		elif connected_segments.size() == 2 and connected_segments[0].total_lanes != connected_segments[1].total_lanes:
			layerHelper.create_trapezoid_underlayer(self, connected_segments)
		elif connected_segments.size() == 2:
			layerHelper.create_rectangle_underlayer(self, connected_segments, node_width, NetworkConstants.LANE_WIDTH)
		elif connected_segments.size() == 1:
			layerHelper.create_circle_underlayer(self, connected_segments[0], connected_segments[0].total_lanes * NetworkConstants.LANE_WIDTH / 2.0)

		if connected_segments.size() < 3:
			boundary_layer.polygon = layerHelper.create_simple_intersection(self, connected_segments, node_width, NetworkConstants.LANE_WIDTH)

	_update_debug_layer()


func late_update_visuals() -> void:
	_setup_connections()

	if connected_segments.size() > 2:
		_draw_stop_lines()

	intersection_manager = IntersectionManager.new()
	intersection_manager.setup_intersection(self)

	_update_debug_layer()


func get_intersection_polygon() -> PackedVector2Array:
	var global_points: PackedVector2Array = []

	var target_layer = main_layer if main_layer.polygon.size() > 0 else boundary_layer

	for point in target_layer.polygon:
		global_points.append(to_global(point))
	return global_points


func add_connection_path(in_id: int, out_id: int, curve: Curve2D, direction: Enums.Direction) -> void:
	var path = Path2D.new()
	path.curve = curve
	path.z_index = 2
	pathing_layer.add_child(path)
	var key = str(in_id) + "-" + str(out_id)

	connection_paths[key] = path
	connection_directions[key] = direction


func get_connection_path(in_id: int, out_id: int) -> Path2D:
	var key = str(in_id) + "-" + str(out_id)
	if connection_paths.has(key):
		return connection_paths[key]
	else:
		return null


func get_connection_direction(in_id: int, out_id: int) -> Enums.Direction:
	var key = str(in_id) + "-" + str(out_id)
	if connection_directions.has(key):
		return connection_directions[key]
	else:
		return Enums.Direction.BACKWARD


func get_connection_priority(in_id: int) -> Enums.IntersectionPriority:
	var from_segment_id = network_manager.get_lane_endpoint(in_id).SegmentId
	return segment_priorities.get(from_segment_id, Enums.IntersectionPriority.YIELD)


func get_connection_details(in_id: int, out_id: int) -> Dictionary:
	var source_endpoint = network_manager.get_lane_endpoint(in_id)
	var dest_endpoint = network_manager.get_lane_endpoint(out_id)

	return {
		"source": source_endpoint,
		"source_segment": network_manager.get_segment(source_endpoint.SegmentId),
		"source_lane": network_manager.get_segment(source_endpoint.SegmentId).get_lane(source_endpoint.LaneId),
		"destination": dest_endpoint,
		"destination_segment": network_manager.get_segment(dest_endpoint.SegmentId),
		"destination_lane": network_manager.get_segment(dest_endpoint.SegmentId).get_lane(dest_endpoint.LaneId),
	}


func get_destination_endpoints(from_endpoint_id: int) -> Array:
	return connections.get(from_endpoint_id, [])


func get_source_endpoints(to_endpoint_id: int) -> Array:
	var sources: Array = []
	for source_id in connections.keys():
		if connections[source_id].has(to_endpoint_id):
			sources.append(source_id)
	return sources


func _setup_connections() -> void:
	if connected_segments.size() == 0:
		return

	if connected_segments.size() == 1:
		connections_helper.setup_one_segment_connections(self)
	elif connected_segments.size() == 2:
		connections_helper.setup_two_segment_connections(self)
	else:
		connections_helper.setup_mutli_segment_connections(self)


func _draw_stop_lines() -> void:
	for endpoint_id in incoming_endpoints:
		var endpoint = network_manager.get_lane_endpoint(endpoint_id)
		var lane = network_manager.get_segment(endpoint.SegmentId).lanes[endpoint.LaneId]
		var perpendicular_line = line_helper.create_perpendicular_line_at_point(lane.trail.curve, endpoint.Position, self, NetworkConstants.LANE_WIDTH)

		if perpendicular_line:
			var priority = segment_priorities.get(endpoint.SegmentId, Enums.IntersectionPriority.YIELD)

			match priority:
				Enums.IntersectionPriority.PRIORITY:
					continue
				Enums.IntersectionPriority.STOP:
					line_helper.draw_solid_line(perpendicular_line, markings_layer, 3.0, Color.GRAY)
				Enums.IntersectionPriority.YIELD:
					line_helper.draw_dash_line(perpendicular_line, markings_layer, 12.0, 5.0, 3.0, Color.GRAY)


func _fill_segment_priorities() -> void:
	var get_all_yield = func() -> Dictionary:
		var dict: Dictionary = { }
		for segment in connected_segments:
			dict[segment.id] = Enums.IntersectionPriority.YIELD
		return dict

	var new_state = { }

	var priority_count = 0

	for segment in connected_segments:
		var dest_node_id = segment.get_other_node_id(id)
		var is_in_priority = definition.priority_segments.has(dest_node_id)
		var is_in_stop = definition.stop_segments.has(dest_node_id)

		if is_in_priority:
			if priority_count >= 2 || is_in_stop:
				push_error("Intersection node " + str(id) + " has more than two priority segments or a segment marked as both priority and stop. All non-priority segments will be set to yield.")
				segment_priorities = get_all_yield.call()
				return

			new_state[segment.id] = Enums.IntersectionPriority.PRIORITY
			priority_count += 1
		elif is_in_stop:
			new_state[segment.id] = Enums.IntersectionPriority.STOP
		else:
			new_state[segment.id] = Enums.IntersectionPriority.YIELD

	if priority_count != 2:
		for priority in new_state.keys():
			if new_state[priority] == Enums.IntersectionPriority.PRIORITY:
				new_state[priority] = Enums.IntersectionPriority.YIELD

	is_priority_based = priority_count == 2
	segment_priorities = new_state


func _update_debug_layer() -> void:
	for child in debug_layer.get_children():
		child.queue_free()

	if config_manager.DebugToggles.DrawNetworkNodes:
		circle_helper.draw_debug_circle(Vector2.ZERO, Color.RED, debug_layer, { "size": 24.0, "text": str(id) })

	if config_manager.DebugToggles.DrawNodeLayers:
		under_layer.color = Color.RED
		under_layer.z_index = 1
		under_layer.z_as_relative = false
		main_layer.color = Color.GREEN
		boundary_layer.color = Color.BLUE_VIOLET
	else:
		under_layer.color = Color(0.2, 0.2, 0.2)
		under_layer.z_index = 0
		under_layer.z_as_relative = true
		main_layer.color = Color(0.2, 0.2, 0.2)
		boundary_layer.color = Color(0, 0, 0, 0)

	if config_manager.DebugToggles.DrawLaneEndpoints:
		for in_id in incoming_endpoints + outgoing_endpoints:
			var color = Color.DARK_KHAKI if incoming_endpoints.has(in_id) else Color.DARK_ORANGE

			var endpoint = network_manager.get_lane_endpoint(in_id)
			var circleText = str(endpoint.Id)
			circle_helper.draw_debug_circle(to_local(endpoint.Position), color, debug_layer, { "size": 6.0, "text": circleText })

		for point in corner_points:
			var circle = circle_helper.DebugCircle.new()
			circle.z_index = 5
			circle.radius = 1.0
			circle.color = Color.AQUA
			circle.position = to_local(point)

			debug_layer.add_child(circle)

	if config_manager.DebugToggles.DrawLaneConnections:
		for in_id in incoming_endpoints:
			for out_id in connections.get(in_id, []):
				var path = get_connection_path(in_id, out_id)
				line_helper.draw_solid_line(path.curve, debug_layer, 1, Color.YELLOW)


func _on_debug_toggles_changed(_name, _state) -> void:
	_update_debug_layer()
