extends Node2D
class_name RoadNode

const NodeLayerHelperScript = preload("res://graphic-helpers/node_layer_helper.gd")
const DebugCircleScript = preload("res://graphic-helpers/debug_circle.gd")

var layerHelper: NodeLayerHelper = NodeLayerHelper.new()
var circleHelper: DebugCircleHelper = DebugCircleHelper.new()

@export var id: int
var connections: Dictionary = {}
var icoming_endpoints: Array = []
var outgoing_endpoints: Array = []

var corner_points: PackedVector2Array = []


@onready var debug_layer: Node2D = $DebugLayer
@onready var markings_layer: Node2D = $MarkingsLayer
@onready var main_layer: Polygon2D = $MainLayer
@onready var under_layer: Polygon2D = $UnderLayer
@onready var boundary_layer: Polygon2D = $BoundaryLayer

func update_visuals() -> void:
	var segments = NetworkManager.get_node_connected_segments(id)

	var max_lanes = 0

	for segment in segments:
		if segment.total_lanes > max_lanes:
			max_lanes = segment.total_lanes

	if segments.size() > 0:
		var node_width = max_lanes * NetworkConstants.LANE_WIDTH

		var config_manager = get_node("/root/ConfigManager")

		if config_manager.DrawNodeLayers:
			under_layer.color = Color.RED
			under_layer.z_index = 1
			under_layer.z_as_relative = false
			main_layer.color = Color.GREEN
			boundary_layer.color = Color.BLUE_VIOLET

		if segments.size() > 2:
			corner_points = layerHelper.find_intersection_corners(segments)

			main_layer.polygon = layerHelper.create_precise_intersection_layer(self, segments, corner_points)
			var perpendicular_segment = SegmentHelper.find_perpendicular_segment_at_node(segments, id)
			var parallel_segments = segments.filter(func(seg): return seg != perpendicular_segment)
			layerHelper.create_trapezoid_underlayer(self, parallel_segments)
		elif segments.size() == 2 and segments[0].total_lanes != segments[1].total_lanes:
			layerHelper.create_trapezoid_underlayer(self, segments)
		elif segments.size() == 2:
			layerHelper.create_rectangle_underlayer(self, segments, node_width, NetworkConstants.LANE_WIDTH)
		elif segments.size() == 1:
			layerHelper.create_circle_underlayer(self, segments[0], segments[0].total_lanes * NetworkConstants.LANE_WIDTH / 2.0)

		if segments.size() < 3:
			boundary_layer.polygon = layerHelper.create_simple_intersection(self, segments, node_width, NetworkConstants.LANE_WIDTH)

	_update_debug_layer()

func late_update_visuals() -> void:
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

	var config_manager = get_node("/root/ConfigManager")
	if config_manager.DrawNetworkNodes:
		var circle = circleHelper.DebugCircle.new()
		circle.z_index = 1
		circle.radius = 24.0
		circle.color = Color.RED
		
		debug_layer.add_child(circle)


	if config_manager.DrawLaneEndpoints:
		for point in icoming_endpoints:
			circleHelper._draw_debug_circle(to_local(point), Color.DARK_KHAKI, debug_layer)
		for point in outgoing_endpoints:
			circleHelper._draw_debug_circle(to_local(point), Color.DARK_ORANGE, debug_layer)

		for point in corner_points:
			var circle = circleHelper.DebugCircle.new()
			circle.z_index = 5
			circle.radius = 1.0
			circle.color = Color.AQUA
			circle.position = to_local(point)
			
			debug_layer.add_child(circle)
