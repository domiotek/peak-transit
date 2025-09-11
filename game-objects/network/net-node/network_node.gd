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

@export var id: int
var connections: Dictionary = {}
var incoming_endpoints: Array = []
var outgoing_endpoints: Array = []
var connection_paths: Dictionary = {}

var corner_points: PackedVector2Array = []
var connected_segments: Array = []


@onready var debug_layer: Node2D = $DebugLayer
@onready var markings_layer: Node2D = $MarkingsLayer
@onready var main_layer: Polygon2D = $MainLayer
@onready var under_layer: Polygon2D = $UnderLayer
@onready var boundary_layer: Polygon2D = $BoundaryLayer
@onready var pathing_layer: Node2D = $PathingLayer

func _ready() -> void:
	config_manager.DebugToggles.ToggleChanged.connect(_on_debug_toggles_changed)


func update_visuals() -> void:
	connected_segments = network_manager.get_node_connected_segments(id)

	var max_lanes = 0

	for segment in connected_segments:
		if segment.total_lanes > max_lanes:
			max_lanes = segment.total_lanes

	if connected_segments.size() > 0:
		var node_width = max_lanes * NetworkConstants.LANE_WIDTH

		if connected_segments.size() > 2:
			corner_points = layerHelper.find_intersection_corners(connected_segments)

			main_layer.polygon = layerHelper.create_precise_intersection_layer(self, connected_segments, corner_points)
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

	_update_debug_layer()

func get_intersection_polygon() -> PackedVector2Array:
	var global_points: PackedVector2Array = []

	var target_layer = main_layer if main_layer.polygon.size() > 0 else boundary_layer

	for point in target_layer.polygon:
		global_points.append(to_global(point))
	return global_points

func add_connection_path(in_id: int, out_id: int, curve: Curve2D) -> void:
	var path = Path2D.new()
	path.curve = curve
	path.z_index = 2
	pathing_layer.add_child(path)
	connection_paths[str(in_id) + "-" + str(out_id)] = path


func get_connection_path(in_id: int, out_id: int) -> Path2D:
	var key = str(in_id) + "-" + str(out_id)
	if connection_paths.has(key):
		return connection_paths[key]
	else:
		return null

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
			line_helper.draw_dash_line(perpendicular_line, markings_layer, 12.0, 5.0, 3.0, Color.GRAY)


func _update_debug_layer() -> void:
	for child in debug_layer.get_children():
		child.queue_free()

	if config_manager.DebugToggles.DrawNetworkNodes:
		circle_helper.draw_debug_circle(Vector2.ZERO, Color.RED, debug_layer, {"size": 24.0, "text": str(id)})


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
			var circleText = str(endpoint.Id) if config_manager.DebugToggles.DrawLaneEndpointIds else ""
			circle_helper.draw_debug_circle(to_local(endpoint.Position), color, debug_layer, {"size": 6.0, "text": circleText})

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
				line_helper.draw_solid_line(path.curve,debug_layer, 1, Color.YELLOW)

func _on_debug_toggles_changed(_name, _state) -> void:
	_update_debug_layer()
