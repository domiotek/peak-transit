class_name NodeLayerHelper

const CORNER_SCAN_DISTANCE: float = 140.0

var line_helper = GDInjector.inject("LineHelper") as LineHelper
var segment_helper = GDInjector.inject("SegmentHelper") as SegmentHelper


func find_intersection_corners(target_node: RoadNode, segments: Array) -> PackedVector2Array:
	if segments.size() < 3:
		return []

	var intersection_points: PackedVector2Array = []
	var segment_edges: Array = []

	for segment in segments:
		var edges: Array = []
		var is_at_start: bool = segment.nodes[0].id == target_node.id
		for edge in [segment.left_edge_curve, segment.right_edge_curve]:
			if edge == null:
				continue

			var baked_points: PackedVector2Array = _get_points_near_node(edge, is_at_start, CORNER_SCAN_DISTANCE)
			if baked_points.size() < 2:
				continue

			edges.append(
				{
					"points": baked_points,
					"bounds": _calculate_points_bounds(baked_points),
				},
			)

		segment_edges.append(edges)

	for i in range(segments.size() - 1):
		for j in range(i + 1, segments.size()):
			var edges_a: Array = segment_edges[i]
			var edges_b: Array = segment_edges[j]

			if edges_a.is_empty() or edges_b.is_empty():
				continue

			for edge_a in edges_a:
				for edge_b in edges_b:
					if not _rects_overlap(edge_a["bounds"], edge_b["bounds"], 0.01):
						continue

					var points = line_helper.find_curve_curve_intersections(edge_a["points"], edge_b["points"], false)
					if points.size() > 0:
						intersection_points.append_array(points)

	return line_helper.remove_duplicate_points(intersection_points)


func _get_points_near_node(curve: Curve2D, is_at_start: bool, max_distance: float) -> PackedVector2Array:
	var points: PackedVector2Array = curve.get_baked_points()
	if points.size() < 2 or max_distance <= 0.0:
		return points

	if is_at_start:
		var from_start: PackedVector2Array = []
		var traversed := 0.0
		from_start.append(points[0])

		for i in range(points.size() - 1):
			var next_point: Vector2 = points[i + 1]
			traversed += points[i].distance_to(next_point)
			from_start.append(next_point)

			if traversed >= max_distance:
				break

		return from_start

	var from_end_reversed: PackedVector2Array = []
	var traversed_from_end := 0.0
	from_end_reversed.append(points[points.size() - 1])

	for i in range(points.size() - 1, 0, -1):
		var prev_point: Vector2 = points[i - 1]
		traversed_from_end += points[i].distance_to(prev_point)
		from_end_reversed.append(prev_point)

		if traversed_from_end >= max_distance:
			break

	from_end_reversed.reverse()
	return from_end_reversed


func _calculate_points_bounds(points: PackedVector2Array) -> Rect2:
	if points.is_empty():
		return Rect2()

	var min_x = INF
	var min_y = INF
	var max_x = -INF
	var max_y = -INF

	for point in points:
		min_x = min(min_x, point.x)
		min_y = min(min_y, point.y)
		max_x = max(max_x, point.x)
		max_y = max(max_y, point.y)

	return Rect2(Vector2(min_x, min_y), Vector2(max_x - min_x, max_y - min_y))


func _rects_overlap(a: Rect2, b: Rect2, padding: float = 0.0) -> bool:
	return (
		a.position.x <= b.end.x + padding
		and a.end.x + padding >= b.position.x
		and a.position.y <= b.end.y + padding
		and a.end.y + padding >= b.position.y
	)


func create_simple_intersection(target_node: RoadNode, segments: Array, node_width: float, node_height: float) -> PackedVector2Array:
	if segments.size() == 0:
		return PackedVector2Array()

	var avg_direction = Vector2.ZERO
	var segment_count = 0

	for segment in segments:
		var direction: Vector2
		if segment.nodes[0].id == target_node.id:
			direction = segment.main_layer_curve.get_point_out(0).normalized()
		else:
			var last_point = segment.main_layer_curve.point_count - 1
			direction = -segment.main_layer_curve.get_point_in(last_point).normalized()

		avg_direction += direction
		segment_count += 1

	if segment_count > 0:
		avg_direction = avg_direction.normalized()

	var rect_width = max(node_width, 64.0)
	var rect_height = max(node_height, 48.0)

	if segments.size() == 2:
		rect_width *= 1.5

	var half_width = rect_width / 2.0
	var half_height = rect_height / 2.0

	var angle = avg_direction.angle() + PI / 2

	var points = PackedVector2Array(
		[
			Vector2(-half_width, -half_height),
			Vector2(half_width, -half_height),
			Vector2(half_width, half_height),
			Vector2(-half_width, half_height),
		],
	)

	var rotated_points = PackedVector2Array()
	var cos_angle = cos(angle)
	var sin_angle = sin(angle)

	for point in points:
		var rotated_point = Vector2(
			point.x * cos_angle - point.y * sin_angle,
			point.x * sin_angle + point.y * cos_angle,
		)
		rotated_points.append(rotated_point)

	return rotated_points


func create_precise_intersection_layer(target_node: RoadNode, segments: Array, corners: PackedVector2Array) -> PackedVector2Array:
	var all_edge_points = []
	var used_corners = []

	for segment in segments:
		var edge_info = segment_helper.get_segment_edge_points_at_node(segment, target_node.id, 50.0)
		var left_edge_local = target_node.to_local(edge_info.left_edge)
		var right_edge_local = target_node.to_local(edge_info.right_edge)

		var closest_corner_left = _find_closest_unused_corner(target_node, left_edge_local, corners, used_corners, 32.0)
		if closest_corner_left != Vector2.ZERO:
			all_edge_points.append(target_node.to_local(closest_corner_left))
			used_corners.append(closest_corner_left)
		else:
			all_edge_points.append(left_edge_local)

		var closest_corner_right = _find_closest_unused_corner(target_node, right_edge_local, corners, used_corners, 32.0)
		if closest_corner_right != Vector2.ZERO:
			all_edge_points.append(target_node.to_local(closest_corner_right))
			used_corners.append(closest_corner_right)
		else:
			all_edge_points.append(right_edge_local)

	if all_edge_points.size() >= 3:
		var center = Vector2.ZERO
		for point in all_edge_points:
			center += point
		center /= all_edge_points.size()

		all_edge_points.sort_custom(
			func(a, b):
				return (a - center).angle() < (b - center).angle()
		)

		return PackedVector2Array(all_edge_points)

	return PackedVector2Array()


func create_rectangle_underlayer(target_node: RoadNode, segments: Array, width: float, height: float) -> void:
	var half_width = width / 2.0
	var half_height = height / 1.25

	var tangent1: Vector2
	var tangent2: Vector2

	if segments[0].nodes[0].id == target_node.id:
		tangent1 = segments[0].main_layer_curve.get_point_out(0)
	else:
		var last_point = segments[0].main_layer_curve.point_count - 1
		tangent1 = -segments[0].main_layer_curve.get_point_in(last_point)

	if segments[1].nodes[0].id == target_node.id:
		tangent2 = segments[1].main_layer_curve.get_point_out(0)
	else:
		var last_point = segments[1].main_layer_curve.point_count - 1
		tangent2 = -segments[1].main_layer_curve.get_point_in(last_point)

	var norm_tangent1 = tangent1.normalized()
	var norm_tangent2 = tangent2.normalized()

	var avg_tangent = (norm_tangent1 + norm_tangent2).normalized()
	var angle = avg_tangent.angle()
	target_node.under_layer.rotation = angle + PI / 2

	var pos_offset = segments[0].main_layer_offset

	target_node.under_layer.polygon = PackedVector2Array(
		[
			Vector2(-half_width + pos_offset, -half_height),
			Vector2(half_width + pos_offset, -half_height),
			Vector2(half_width + pos_offset, half_height),
			Vector2(-half_width + pos_offset, half_height),
		],
	)


func create_circle_underlayer(target_node: RoadNode, segment: NetSegment, radius: float) -> void:
	var edge_info = segment_helper.get_segment_edge_points_at_node(segment, target_node.id)
	var curve_center_local = target_node.to_local(edge_info.center)

	var points = []
	var segments = 32
	for i in range(segments):
		var angle = (i / float(segments)) * TAU
		var point = Vector2(cos(angle), sin(angle)) * radius + curve_center_local
		points.append(point)

	target_node.under_layer.polygon = PackedVector2Array(points)


func create_trapezoid_underlayer(target_node: RoadNode, segments: Array) -> void:
	if segments.size() != 2:
		return

	var seg1 = segments[0]
	var seg2 = segments[1]

	var wider_segment = seg1 if seg1.get_lane_count() > seg2.get_lane_count() else seg2
	var narrower_segment = seg1 if seg1.get_lane_count() < seg2.get_lane_count() else seg2

	var wider_edge_info = segment_helper.get_segment_edge_points_at_node(wider_segment, target_node.id)
	var narrower_edge_info = segment_helper.get_segment_edge_points_at_node(narrower_segment, target_node.id, 50.0)

	var wider_left_local = target_node.to_local(wider_edge_info.left_edge)
	var wider_right_local = target_node.to_local(wider_edge_info.right_edge)

	var narrow_left_local = target_node.to_local(narrower_edge_info.left_edge)
	var narrow_right_local = target_node.to_local(narrower_edge_info.right_edge)

	if wider_segment == seg1:
		target_node.under_layer.polygon = PackedVector2Array([narrow_left_local, narrow_right_local, wider_right_local, wider_left_local])
	else:
		target_node.under_layer.polygon = PackedVector2Array([wider_right_local, wider_left_local, narrow_left_local, narrow_right_local])


func _find_closest_unused_corner(node: RoadNode, edge_point: Vector2, corners: PackedVector2Array, used_corners: Array, max_distance: float) -> Vector2:
	var closest_corner: Vector2
	var closest_distance = max_distance
	var found = false

	for corner in corners:
		var corner_local = node.to_local(corner)
		var distance = edge_point.distance_to(corner_local)

		if distance <= max_distance and not used_corners.has(corner) and distance < closest_distance:
			closest_corner = corner
			closest_distance = distance
			found = true

	return closest_corner if found else Vector2.ZERO
