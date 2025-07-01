extends Node2D
class_name NetLane

class DebugCircle extends Node2D:
	var radius: float = 10.0
	var color: Color = Color.RED
	var circle_position: Vector2 = Vector2.ZERO
	
	func _draw():
		draw_circle(circle_position, radius, color)

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
		new_curve = _create_end_points_for_node(node, new_curve)

	trail.curve = new_curve

	_update_debug_layer()

func _create_end_points_for_node(node: RoadNode, curve: Curve2D) -> Curve2D:
	var polygon = node.get_intersection_polygon()

	if polygon.size() > 0:
		var points = LineHelper.find_curve_polygon_intersections(curve.get_baked_points(), polygon)

		if points.size() > 0:
			var circle = DebugCircle.new()
			circle.z_index = 5
			circle.radius = 6.0
			circle.color = Color.DARK_KHAKI
			circle.position = points[0]
			
			debug_layer.add_child(circle)

	return curve


func _update_debug_layer() -> void:
	var config_manager = get_node("/root/ConfigManager")

	if !config_manager.DrawLaneLayers:
		return

	LineHelper.draw_solid_line(trail.curve, debug_layer, 2.0, Color.PURPLE)

	
