extends Node2D
class_name NetLane
@onready var trail: Path2D = $PathingTrail
@onready var debug_layer: Node2D = $DebugLayer

var id: int
var segment: NetSegment
var data: NetLaneInfo
var offset: float = 0.0


func setup(lane_id: int, parent_segment: NetSegment, lane_info: NetLaneInfo, lane_offset: float) -> void:
	id = lane_id
	segment = parent_segment
	data = lane_info
	offset = lane_offset

func update_trail_shape(curve: Curve2D) -> void:
	if curve == null:
		return

	var new_curve = LineHelper.get_curve_with_offset(curve, offset)

	for node in segment.nodes:
		var point = _get_endpoint_for_node(node, new_curve)
		var road_side = SegmentHelper.get_road_side_at_endpoint(segment, point)
		var point_global = to_global(point)

		var is_outgoing = road_side == SegmentHelper.RoadSide.Left;
		NetworkManager.add_lane_endpoint(id, point_global, segment, node, is_outgoing, _calc_lane_number())

	trail.curve = new_curve

	_update_debug_layer()

func _get_endpoint_for_node(node: RoadNode, curve: Curve2D) -> Vector2:
	var polygon = node.get_intersection_polygon()

	if polygon.size() > 0:
		var points = LineHelper.find_curve_polygon_intersections(curve.get_baked_points(), polygon)

		if points.size() > 0:
			return points[0]

	return Vector2.ZERO


func _update_debug_layer() -> void:
	var config_manager = get_node("/root/ConfigManager")

	if !config_manager.DrawLaneLayers:
		return

	LineHelper.draw_solid_line(trail.curve, debug_layer, 2.0, Color.PURPLE)


func _calc_lane_number() -> int:
	return abs(int(offset / NetworkConstants.LANE_WIDTH))

	
