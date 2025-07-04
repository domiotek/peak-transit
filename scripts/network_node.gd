extends Node2D
class_name RoadNode

const NodeLayerHelperScript = preload("res://graphic-helpers/node_layer_helper.gd")
const DebugCircleScript = preload("res://graphic-helpers/debug_circle.gd")
const LaneCalculatorScript = preload("res://helpers/LaneCalculator.cs")
const ConnectionsHelperScript = preload("res://graphic-helpers/connections_helper.gd")

var layerHelper: NodeLayerHelper = NodeLayerHelper.new()
var circleHelper: DebugCircleHelper = DebugCircleHelper.new()
var lane_calculator = LaneCalculator.new()
var connections_helper = ConnectionsHelper.new()
@onready var config_manager = get_node("/root/ConfigManager")

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
	add_child(connections_helper)

func update_visuals() -> void:
	connected_segments = NetworkManager.get_node_connected_segments(id)

	var max_lanes = 0

	for segment in connected_segments:
		if segment.total_lanes > max_lanes:
			max_lanes = segment.total_lanes

	if connected_segments.size() > 0:
		var node_width = max_lanes * NetworkConstants.LANE_WIDTH

		if config_manager.DrawNodeLayers:
			under_layer.color = Color.RED
			under_layer.z_index = 1
			under_layer.z_as_relative = false
			main_layer.color = Color.GREEN
			boundary_layer.color = Color.BLUE_VIOLET

		if connected_segments.size() > 2:
			corner_points = layerHelper.find_intersection_corners(connected_segments)

			main_layer.polygon = layerHelper.create_precise_intersection_layer(self, connected_segments, corner_points)
			var perpendicular_segment = SegmentHelper.find_perpendicular_segment_at_node(connected_segments, id)
			var parallel_segments = connected_segments.filter(func(seg): return seg != perpendicular_segment)
			layerHelper.create_trapezoid_underlayer(self, parallel_segments)
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

	_update_debug_layer()

func get_intersection_polygon() -> PackedVector2Array:
	var global_points: PackedVector2Array = []

	var target_layer = main_layer if main_layer.polygon.size() > 0 else boundary_layer

	for point in target_layer.polygon:
		global_points.append(to_global(point))
	return global_points

func _update_debug_layer() -> void:
	for child in debug_layer.get_children():
		child.queue_free()

	if config_manager.DrawNetworkNodes:
		var circle = circleHelper.DebugCircle.new()
		circle.z_index = 1
		circle.radius = 24.0
		circle.color = Color.RED
		
		debug_layer.add_child(circle)


	if config_manager.DrawLaneEndpoints:
		for in_id in incoming_endpoints + outgoing_endpoints:
			var color = Color.DARK_KHAKI if incoming_endpoints.has(in_id) else Color.DARK_ORANGE

			var endpoint = NetworkManager.get_lane_endpoint(in_id)
			circleHelper._draw_debug_circle(to_local(endpoint.Position), color, debug_layer)

			if config_manager.DrawLaneEndpointIds:
				var label = Label.new()
				label.text = str(endpoint.Id)
				label.position = to_local(endpoint.Position)
				debug_layer.add_child(label)

		for point in corner_points:
			var circle = circleHelper.DebugCircle.new()
			circle.z_index = 5
			circle.radius = 1.0
			circle.color = Color.AQUA
			circle.position = to_local(point)
			
			debug_layer.add_child(circle)

	if config_manager.DrawLaneConnections:
		for in_id in incoming_endpoints:
			for out_id in connections.get(in_id, []):
				var path = get_connection_path(in_id, out_id)
				LineHelper.draw_solid_line(path.curve,debug_layer, 1, Color.YELLOW)

func _setup_connections() -> void:

	if connected_segments.size() == 0:
		return

	if connected_segments.size() == 1:
		connections_helper.setup_one_segment_connections(self)
	elif connected_segments.size() == 2:
		connections_helper.setup_two_segment_connections(self)
	else:
		connections_helper.setup_mutli_segment_connections(self)

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
