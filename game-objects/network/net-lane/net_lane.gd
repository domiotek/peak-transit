extends Node2D
class_name NetLane
@onready var trail: Path2D = $PathingTrail
@onready var debug_layer: Node2D = $DebugLayer

var id: int
var segment: NetSegment
var data: NetLaneInfo
var offset: float = 0.0

var from_endpoint: int
var to_endpoint: int

@onready var line_helper = GDInjector.inject("LineHelper") as LineHelper
@onready var segment_helper = GDInjector.inject("SegmentHelper") as SegmentHelper
@onready var network_manager = GDInjector.inject("NetworkManager") as NetworkManager
@onready var config_manager = GDInjector.inject("ConfigManager") as ConfigManager

func _ready() -> void:
	config_manager.DebugToggles.ToggleChanged.connect(_on_debug_toggles_changed)


func setup(lane_id: int, parent_segment: NetSegment, lane_info: NetLaneInfo, lane_offset: float) -> void:
	id = lane_id
	segment = parent_segment
	data = lane_info
	offset = lane_offset

func update_trail_shape(curve: Curve2D) -> void:
	if curve == null:
		return

	var new_curve = line_helper.get_curve_with_offset(curve, offset)
	var points = {}

	for node in segment.nodes:
		var point = _get_endpoint_for_node(node, new_curve)
		var road_side = segment_helper.get_road_side_at_endpoint(segment, point)
		var point_global = to_global(point)

		var is_outgoing = road_side == SegmentHelper.RoadSide.Left;
		var is_at_path_start = segment.nodes[0] == node

		if is_outgoing and not is_at_path_start:
			new_curve = line_helper.reverse_curve(new_curve)
			is_at_path_start = true

		var endpoint_id = network_manager.add_lane_endpoint(id, point_global, segment, node, is_outgoing, _calc_lane_number(), is_at_path_start)

		if is_outgoing:
			from_endpoint = endpoint_id
			points[0] = point_global
		else:
			to_endpoint = endpoint_id
			points[1] = point_global

	new_curve = line_helper.trim_curve(new_curve, points[0], points[1])
	trail.curve = new_curve

	_update_debug_layer()

func get_endpoint_by_id(endpoint_id: int) -> NetLaneEndpoint:
	return network_manager.get_lane_endpoint(endpoint_id)

func get_endpoint_by_type(is_outgoing: bool) -> NetLaneEndpoint:
	return network_manager.get_lane_endpoint(from_endpoint if is_outgoing else to_endpoint)

func get_curve() -> Curve2D:
	return trail.curve

func _get_endpoint_for_node(node: RoadNode, curve: Curve2D) -> Vector2:
	var polygon = node.get_intersection_polygon()

	if polygon.size() > 0:
		var points = line_helper.find_curve_polygon_intersections(curve.get_baked_points(), polygon)

		if points.size() > 0:
			return points[0]

	return Vector2.ZERO


func _update_debug_layer() -> void:
	for child in debug_layer.get_children():
		child.queue_free()

	if !config_manager.DebugToggles.DrawLaneLayers:
		return

	line_helper.draw_solid_line(trail.curve, debug_layer, 2.0, Color.PURPLE)


func _calc_lane_number() -> int:
	return abs(int(offset / NetworkConstants.LANE_WIDTH))


func _on_debug_toggles_changed(_name, _state) -> void:
	_update_debug_layer()

	
