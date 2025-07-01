extends Node2D
class_name RoadNode

class DebugCircle extends Node2D:
	var radius: float = 10.0
	var color: Color = Color.RED
	var circle_position: Vector2 = Vector2.ZERO
	
	func _draw():
		draw_circle(circle_position, radius, color)

@export var id: int
var connections: Dictionary = {}


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
		var lane_width = 32
		var node_width = max_lanes * lane_width
		var node_height = 32

		var config_manager = get_node("/root/ConfigManager")

		if config_manager.DrawNodeLayers:
			under_layer.color = Color.RED
			under_layer.z_index = 1
			under_layer.z_as_relative = false
			main_layer.color = Color.GREEN
			boundary_layer.color = Color.BLUE_VIOLET

		if segments.size() > 2:
			var corners = _find_intersection_corners()

			_create_intersection_layer(segments, corners)
			var perpendicular_segment = SegmentHelper.find_perpendicular_segment_at_node(segments, id)
			var parallel_segments = segments.filter(func(seg): return seg != perpendicular_segment)
			_create_trapezoid_underlayer(parallel_segments)
		elif segments.size() == 2 and segments[0].total_lanes != segments[1].total_lanes:
			_create_trapezoid_underlayer(segments)
		elif segments.size() == 2:
			_create_rectangle_underlayer(segments, node_width, node_height)
		elif segments.size() == 1:
			_create_circle_underlayer(segments[0], segments[0].total_lanes * lane_width / 2.0)

		if segments.size() < 3:
			_create_simple_intersection(segments, node_width, node_height)

	_update_debug_layer()

func get_intersection_polygon() -> PackedVector2Array:
	var global_points: PackedVector2Array = []

	var target_layer = main_layer if main_layer.polygon.size() > 0 else boundary_layer

	for point in target_layer.polygon:
		global_points.append(to_global(point))
	return global_points

func _find_intersection_corners() -> PackedVector2Array:

	var segments = NetworkManager.get_node_connected_segments(id)
	if segments.size() < 3:
		return []

	var intersection_points = []

	for segmentA in segments:
		for segmentB in segments:
			if segmentA == segmentB:
				continue

			var sement_a_edges = [segmentA.left_edge_curve, segmentA.right_edge_curve]
			var segment_b_edges = [segmentB.left_edge_curve, segmentB.right_edge_curve]

			for edgeA in sement_a_edges:
				for edgeB in segment_b_edges:
					var points = LineHelper.find_curve_curve_intersections(edgeA.get_baked_points(), edgeB.get_baked_points())
					intersection_points.append_array(points)

	intersection_points = LineHelper.remove_duplicate_points(intersection_points)

	for point in intersection_points:
		var circle = DebugCircle.new()
		circle.z_index = 5
		circle.radius = 1.0
		circle.color = Color.AQUA
		circle.position = to_local(point)
		
		debug_layer.add_child(circle)

	return intersection_points



func _update_debug_layer() -> void:
	for child in debug_layer.get_children():
		child.queue_free()

	var config_manager = get_node("/root/ConfigManager")
	if config_manager.DrawNetworkNodes:
		var circle = DebugCircle.new()
		circle.z_index = 1
		circle.radius = 24.0
		circle.color = Color.RED
		
		debug_layer.add_child(circle)

func _create_intersection_layer(segments: Array, corners: PackedVector2Array) -> void:
	var all_edge_points = []
	var used_corners = []
		
	for segment in segments:
		var edge_info = SegmentHelper.get_segment_edge_points_at_node(segment, id, 50.0)
		var left_edge_local = to_local(edge_info.left_edge)
		var right_edge_local = to_local(edge_info.right_edge)
		
		var closest_corner_left = _find_closest_unused_corner(left_edge_local, corners, used_corners, 32.0)
		if closest_corner_left != Vector2.ZERO:
			all_edge_points.append(to_local(closest_corner_left))
			used_corners.append(closest_corner_left)
		else:
			all_edge_points.append(left_edge_local)
		
		var closest_corner_right = _find_closest_unused_corner(right_edge_local, corners, used_corners, 32.0)
		if closest_corner_right != Vector2.ZERO:
			all_edge_points.append(to_local(closest_corner_right))
			used_corners.append(closest_corner_right)
		else:
			all_edge_points.append(right_edge_local)
	
	if all_edge_points.size() >= 3:
		var center = Vector2.ZERO
		for point in all_edge_points:
			center += point
		center /= all_edge_points.size()
		
		all_edge_points.sort_custom(func(a, b): 
			return (a - center).angle() < (b - center).angle()
		)
		
		main_layer.polygon = PackedVector2Array(all_edge_points)

func _create_simple_intersection(segments: Array, node_width: float, node_height: float) -> void:
	if segments.size() == 0:
		return
	
	var avg_direction = Vector2.ZERO
	var segment_count = 0
	
	for segment in segments:
		var direction: Vector2
		if segment.nodes[0].id == id:
			direction = segment.main_layer_curve.get_point_out(0).normalized()
		else:
			var last_point = segment.main_layer_curve.point_count - 1
			direction = -segment.main_layer_curve.get_point_in(last_point).normalized()
		
		avg_direction += direction
		segment_count += 1
	
	if segment_count > 0:
		avg_direction = avg_direction.normalized()
	
	var rect_width = max(node_width, 64.0)
	var rect_height = max(node_height, 32.0)
	
	if segments.size() == 2:
		rect_width *= 1.5
	
	var half_width = rect_width / 2.0
	var half_height = rect_height / 2.0
	
	var angle = avg_direction.angle() + PI/2

	var points = PackedVector2Array([
		Vector2(-half_width, -half_height),
		Vector2(half_width, -half_height),
		Vector2(half_width, half_height),
		Vector2(-half_width, half_height)
	])
	
	var rotated_points = PackedVector2Array()
	var cos_angle = cos(angle)
	var sin_angle = sin(angle)
	
	for point in points:
		var rotated_point = Vector2(
			point.x * cos_angle - point.y * sin_angle,
			point.x * sin_angle + point.y * cos_angle
		)
		rotated_points.append(rotated_point)
	
	boundary_layer.polygon = rotated_points
	


func _create_rectangle_underlayer(segments: Array, width: float, height: float) -> void:
	var half_width = width / 2.0
	var half_height = height / 2.0

	var tangent1: Vector2
	var tangent2: Vector2
	
	if segments[0].nodes[0].id == id:
		tangent1 = segments[0].main_layer_curve.get_point_out(0)
	else:
		var last_point = segments[0].main_layer_curve.point_count - 1
		tangent1 = -segments[0].main_layer_curve.get_point_in(last_point)
	
	if segments[1].nodes[0].id == id:
		tangent2 = segments[1].main_layer_curve.get_point_out(0)
	else:
		var last_point = segments[1].main_layer_curve.point_count - 1
		tangent2 = -segments[1].main_layer_curve.get_point_in(last_point) 
	
	var norm_tangent1 = tangent1.normalized()
	var norm_tangent2 = tangent2.normalized()
	
	var avg_tangent = (norm_tangent1 + norm_tangent2).normalized()
	var angle = avg_tangent.angle()
	under_layer.rotation = angle + PI/2
	
	
	under_layer.polygon = PackedVector2Array([
		Vector2(-half_width, -half_height),
		Vector2(half_width, -half_height),
		Vector2(half_width, half_height),
		Vector2(-half_width, half_height)
	])

func _create_trapezoid_underlayer(segments: Array) -> void:
	if segments.size() != 2:
		return

	var seg1 = segments[0]
	var seg2 = segments[1]

	var wider_segment = seg1 if seg1.total_lanes > seg2.total_lanes else seg2
	var narrower_segment = seg1 if seg1.total_lanes < seg2.total_lanes else seg2
	
	var wider_edge_info = SegmentHelper.get_segment_edge_points_at_node(wider_segment, id)
	var narrower_edge_info = SegmentHelper.get_segment_edge_points_at_node(narrower_segment, id, 50.0)
	
	var wider_left_local = to_local(wider_edge_info.left_edge)
	var wider_right_local = to_local(wider_edge_info.right_edge)

	var narrow_left_local = to_local(narrower_edge_info.left_edge)
	var narrow_right_local = to_local(narrower_edge_info.right_edge)
	
	if wider_segment == seg1:
		under_layer.polygon = PackedVector2Array([ narrow_left_local, narrow_right_local, wider_right_local,wider_left_local])
	else:
		under_layer.polygon = PackedVector2Array([wider_right_local,wider_left_local, narrow_left_local, narrow_right_local])

func _create_circle_underlayer(segment: NetSegment, radius: float) -> void:
	var edge_info = SegmentHelper.get_segment_edge_points_at_node(segment, id)
	var curve_center_local = to_local(edge_info.center)
	
	var points = []
	var segments = 32
	for i in range(segments):
		var angle = (i / float(segments)) * TAU
		var point = Vector2(cos(angle), sin(angle)) * radius + curve_center_local
		points.append(point)
	
	under_layer.polygon = PackedVector2Array(points)

func _find_closest_unused_corner(edge_point: Vector2, corners: PackedVector2Array, used_corners: Array, max_distance: float) -> Vector2:
	var closest_corner: Vector2
	var closest_distance = max_distance
	var found = false
	
	for corner in corners:
		var corner_local = to_local(corner)
		var distance = edge_point.distance_to(corner_local)
		
		if distance <= max_distance and not used_corners.has(corner) and distance < closest_distance:
			closest_corner = corner
			closest_distance = distance
			found = true
	
	return closest_corner if found else Vector2.ZERO
