class_name LineHelper

func calc_curve(start_pos: Vector2, target_pos: Vector2, strength: float, direction: NetSegmentInfo.CurveDirection) -> Curve2D:
	var line_vector = target_pos - start_pos
	var line_length = line_vector.length()

	var perpendicular = Vector2(-line_vector.y, line_vector.x).normalized()
	var mid_point = (start_pos + target_pos) / 2.0
	var control_point = mid_point + perpendicular * line_length * strength * direction

	var curve = Curve2D.new()

	curve.add_point(start_pos)

	var to_control = 2.0 / 3.0 * (control_point - start_pos)
	var from_control = 2.0 / 3.0 * (control_point - target_pos)

	curve.set_point_out(0, to_control)

	curve.add_point(target_pos, from_control, Vector2.ZERO)

	return curve


func calc_curve_asymmetric(
		start_pos: Vector2,
		target_pos: Vector2,
		start_strength: float,
		end_strength: float,
		direction: int,
		bulge_factor: float = 0.0,
) -> Curve2D:
	var line_vector = target_pos - start_pos
	var line_length = line_vector.length()

	var perpendicular = Vector2(-line_vector.y, line_vector.x).normalized()
	var forward = line_vector.normalized()

	var start_handle_length = line_length * start_strength
	var end_handle_length = line_length * end_strength

	var start_forward_blend = bulge_factor if bulge_factor > 0 else (start_strength * 0.5)
	var end_forward_blend = bulge_factor if bulge_factor > 0 else (end_strength * 0.5)

	var start_control = start_pos + perpendicular * start_handle_length * direction + forward * (start_handle_length * start_forward_blend)
	var end_control = target_pos + perpendicular * end_handle_length * direction - forward * (end_handle_length * end_forward_blend)

	var curve = Curve2D.new()

	curve.add_point(start_pos)
	var out_handle = start_control - start_pos
	curve.set_point_out(0, out_handle)

	var in_handle = end_control - target_pos
	curve.add_point(target_pos, in_handle, Vector2.ZERO)

	return curve


func get_curve_with_offset(curve: Curve2D, offset: float) -> Curve2D:
	if not curve or not offset:
		return null

	var offset_curve = Curve2D.new()
	var length = curve.get_baked_length()

	if length <= 0:
		return null

	var sample_count = max(curve.point_count * 2, int(length / 10.0))
	sample_count = clamp(sample_count, 10, 100)

	var offset_points = []

	for i in range(sample_count + 1):
		var t = float(i) / float(sample_count)
		var distance = t * length

		var pos = curve.sample_baked(distance)

		var epsilon = 1.0
		var forward_pos = curve.sample_baked(min(distance + epsilon, length))
		var backward_pos = curve.sample_baked(max(distance - epsilon, 0))

		var tangent = (forward_pos - backward_pos).normalized()
		var normal = Vector2(-tangent.y, tangent.x)

		var offset_pos = pos + normal * offset
		offset_points.append(offset_pos)

	for i in range(offset_points.size()):
		var point = offset_points[i]
		var handle_in = Vector2.ZERO
		var handle_out = Vector2.ZERO

		if i > 0 and i < offset_points.size() - 1:
			var prev_point = offset_points[i - 1]
			var next_point = offset_points[i + 1]

			var direction = (next_point - prev_point).normalized()
			var distance_to_prev = (point - prev_point).length()
			var distance_to_next = (next_point - point).length()

			handle_in = -direction * distance_to_prev * 0.3
			handle_out = direction * distance_to_next * 0.3
		elif i == 0 and offset_points.size() > 1:
			var next_point = offset_points[i + 1]
			var direction = (next_point - point).normalized()
			handle_out = direction * (next_point - point).length() * 0.3
		elif i == offset_points.size() - 1 and offset_points.size() > 1:
			var prev_point = offset_points[i - 1]
			var direction = (point - prev_point).normalized()
			handle_in = -direction * (point - prev_point).length() * 0.3

		offset_curve.add_point(point, handle_in, handle_out)

	return offset_curve


func draw_dash_line(
		curve: Curve2D,
		target_layer: Node2D,
		dash_length: float = NetworkConstants.DASH_LENGTH,
		gap_length: float = NetworkConstants.DASH_GAP_LENGTH,
		line_width: float = NetworkConstants.LINE_WIDTH,
		line_color: Color = NetworkConstants.DASH_COLOR,
) -> void:
	if not curve:
		return

	var path_length = curve.get_baked_length()
	var current_distance = 0.0
	var drawing_dash = true

	while current_distance < path_length:
		var segment_length = dash_length if drawing_dash else gap_length
		var start_point = curve.sample_baked(current_distance)

		current_distance += segment_length
		current_distance = min(current_distance, path_length)

		var end_point = curve.sample_baked(current_distance)

		if drawing_dash:
			var dash_line = Line2D.new()
			dash_line.default_color = line_color
			dash_line.width = line_width
			dash_line.antialiased = true
			dash_line.points = [start_point, end_point]
			target_layer.add_child(dash_line)

		drawing_dash = !drawing_dash


func draw_solid_line(
		curve: Curve2D,
		target_layer: Node2D,
		line_width: float = NetworkConstants.LINE_WIDTH,
		line_color: Color = NetworkConstants.LINE_COLOR,
) -> void:
	if not curve or not target_layer:
		return

	var solid_line = Line2D.new()
	solid_line.points = curve.get_baked_points()
	solid_line.width = line_width
	solid_line.default_color = line_color
	solid_line.antialiased = true
	target_layer.add_child(solid_line)


func find_curve_curve_intersections(curve1_points: PackedVector2Array, curve2_points: PackedVector2Array) -> PackedVector2Array:
	var intersections: PackedVector2Array = []

	for i in range(curve1_points.size() - 1):
		var curve1_start = curve1_points[i]
		var curve1_end = curve1_points[i + 1]

		for j in range(curve2_points.size() - 1):
			var curve2_start = curve2_points[j]
			var curve2_end = curve2_points[j + 1]

			var intersection = Geometry2D.segment_intersects_segment(
				curve1_start,
				curve1_end,
				curve2_start,
				curve2_end,
			)

			if intersection != null:
				intersections.append(intersection)

	return remove_duplicate_points(intersections)


func find_curve_polygon_intersections(curve_points: PackedVector2Array, polygon: PackedVector2Array, offset_tolerance: float = 5.0) -> PackedVector2Array:
	var intersections: PackedVector2Array = []

	if curve_points.size() < 2 or polygon.size() < 3:
		return intersections

	for i in range(curve_points.size() - 1):
		var curve_start = curve_points[i]
		var curve_end = curve_points[i + 1]

		for j in range(polygon.size()):
			var poly_start = polygon[j]
			var poly_end = polygon[(j + 1) % polygon.size()]

			var intersection = Geometry2D.segment_intersects_segment(
				curve_start,
				curve_end,
				poly_start,
				poly_end,
			)

			if intersection != null:
				intersections.append(intersection)

	var filtered_intersections = remove_duplicate_points(intersections, offset_tolerance)

	if filtered_intersections.size() <= 1:
		return filtered_intersections

	var curve_center = calculate_curve_center(curve_points)
	var closest_point = filtered_intersections[0]
	var closest_distance = curve_center.distance_to(closest_point)

	for i in range(1, filtered_intersections.size()):
		var distance = curve_center.distance_to(filtered_intersections[i])
		if distance < closest_distance:
			closest_distance = distance
			closest_point = filtered_intersections[i]

	var result: PackedVector2Array = []
	result.append(closest_point)
	return result


func remove_duplicate_points(points: PackedVector2Array, tolerance: float = 0.01) -> PackedVector2Array:
	var filtered: PackedVector2Array = []

	for point in points:
		var is_duplicate = false
		for existing in filtered:
			if point.distance_to(existing) <= tolerance:
				is_duplicate = true
				break

		if not is_duplicate:
			filtered.append(point)

	return filtered


func calculate_curve_center(curve_points: PackedVector2Array) -> Vector2:
	if curve_points.size() == 0:
		return Vector2.ZERO

	var center = Vector2.ZERO
	for point in curve_points:
		center += point

	return center / curve_points.size()


func find_closer_curve_end(curve: Curve2D, point: Vector2) -> Vector2:
	if not curve or curve.point_count == 0:
		return Vector2.ZERO

	var start_point = curve.get_point_position(0)
	var end_point = curve.get_point_position(curve.point_count - 1)

	var start_distance = start_point.distance_to(point)
	var end_distance = end_point.distance_to(point)

	return start_point if start_distance < end_distance else end_point


func create_perpendicular_line_at_point(curve: Curve2D, point: Vector2, ref: Node2D, line_length: float = 50.0) -> Curve2D:
	if not curve or curve.point_count == 0:
		return null

	var closest_offset = curve.get_closest_offset(point)

	var transform = curve.sample_baked_with_rotation(closest_offset, true)
	var tangent_vector = transform.x.normalized()

	var perpendicular = Vector2(-tangent_vector.y, tangent_vector.x).normalized()

	var half_length = line_length * 0.5
	var line_start = point - perpendicular * half_length
	var line_end = point + perpendicular * half_length

	var perpendicular_curve = Curve2D.new()
	perpendicular_curve.add_point(ref.to_local(line_start))
	perpendicular_curve.add_point(ref.to_local(line_end))

	return perpendicular_curve


func reverse_curve(curve: Curve2D) -> Curve2D:
	if not curve:
		return null

	var reversed_curve = Curve2D.new()
	for i in range(curve.point_count - 1, -1, -1):
		var point_pos = curve.get_point_position(i)
		var point_in = curve.get_point_out(i)
		var point_out = curve.get_point_in(i)
		reversed_curve.add_point(point_pos, point_in, point_out)
	return reversed_curve


func trim_curve(curve: Curve2D, start_pos: Vector2, end_pos: Vector2) -> Curve2D:
	var curve_trimmer = CurveTrimmer.new()
	return curve_trimmer.trim_curve(curve, start_pos, end_pos)


func get_connecting_curve(curve1: Curve2D, curve2: Curve2D) -> Curve2D:
	var connecting_curve = Curve2D.new()

	var end_pos_1 = curve1.get_point_position(curve1.get_point_count() - 1)
	var start_pos_2 = curve2.get_point_position(0)
	var distance = end_pos_1.distance_to(start_pos_2)

	var curve1_length = curve1.get_baked_length()
	var curve2_length = curve2.get_baked_length()

	var sample_dist = min(5.0, curve1_length * 0.05)
	var end_direction_1 = Vector2(1, 0)
	if curve1_length > sample_dist:
		var sample_pos = curve1.sample_baked(curve1_length - sample_dist)
		end_direction_1 = (end_pos_1 - sample_pos).normalized()

	sample_dist = min(5.0, curve2_length * 0.05)
	var start_direction_2 = Vector2(1, 0)
	if curve2_length > sample_dist:
		var sample_pos = curve2.sample_baked(sample_dist)
		start_direction_2 = (sample_pos - start_pos_2).normalized()

	if distance < NetworkConstants.SHARP_LANE_CONNECTION_THRESHOLD:
		var handle_strength = distance * 0.6

		connecting_curve.add_point(end_pos_1)
		connecting_curve.set_point_out(0, end_direction_1 * handle_strength)
		connecting_curve.add_point(start_pos_2)
		connecting_curve.set_point_in(1, -start_direction_2 * handle_strength)
	else:
		var base_factor = NetworkConstants.LANE_CONNECTION_BASE_CURVATURE_FACTOR
		var max_factor = NetworkConstants.LANE_CONNECTION_MAX_CURVATURE_FACTOR
		var distance_threshold = NetworkConstants.LANE_CONNECTION_DISTANCE_THRESHOLD

		var distance_ratio = min(distance / distance_threshold, 1.0)
		var curvature_factor = base_factor + (max_factor - base_factor) * distance_ratio

		var handle_length = distance * curvature_factor * 0.15
		var enhanced_out_handle = end_direction_1 * handle_length
		var enhanced_in_handle = -start_direction_2 * handle_length

		connecting_curve.add_point(end_pos_1)
		connecting_curve.set_point_out(0, enhanced_out_handle)
		connecting_curve.add_point(start_pos_2)
		connecting_curve.set_point_in(1, enhanced_in_handle)

	return connecting_curve


func convert_curve_global_to_local(curve: Curve2D, target_node: Node2D) -> Curve2D:
	var local_curve = Curve2D.new()

	for i in range(curve.get_point_count()):
		var global_point = curve.get_point_position(i)
		var global_out_handle = curve.get_point_out(i)
		var global_in_handle = curve.get_point_in(i)

		var local_point = target_node.to_local(global_point)
		var local_out_handle = target_node.to_local(global_point + global_out_handle) - local_point
		var local_in_handle = target_node.to_local(global_point + global_in_handle) - local_point

		local_curve.add_point(local_point)
		local_curve.set_point_out(i, local_out_handle)
		local_curve.set_point_in(i, local_in_handle)

	return local_curve


func convert_curve_local_to_global(curve: Curve2D, source_node: Node2D) -> Curve2D:
	var local_curve = Curve2D.new()

	for i in range(curve.get_point_count()):
		var global_point = curve.get_point_position(i)
		var global_out_handle = curve.get_point_out(i)
		var global_in_handle = curve.get_point_in(i)

		var local_point = source_node.to_global(global_point)
		var local_out_handle = source_node.to_global(global_point + global_out_handle) - local_point
		var local_in_handle = source_node.to_global(global_point + global_in_handle) - local_point

		local_curve.add_point(local_point)
		local_curve.set_point_out(i, local_out_handle)
		local_curve.set_point_in(i, local_in_handle)

	return local_curve


func curves_intersect(curve1: Curve2D, curve2: Curve2D, resolution := 10.0) -> bool:
	curve1.bake_interval = resolution
	curve2.bake_interval = resolution
	var points1 = curve1.get_baked_points()
	var points2 = curve2.get_baked_points()

	var segments_intersect = func(p1: Vector2, p2: Vector2, q1: Vector2, q2: Vector2) -> bool:
		var d1 = (p2.x - p1.x) * (q1.y - p1.y) - (p2.y - p1.y) * (q1.x - p1.x)
		var d2 = (p2.x - p1.x) * (q2.y - p1.y) - (p2.y - p1.y) * (q2.x - p1.x)
		var d3 = (q2.x - q1.x) * (p1.y - q1.y) - (q2.y - q1.y) * (p1.x - q1.x)
		var d4 = (q2.x - q1.x) * (p2.y - q1.y) - (q2.y - q1.y) * (p2.x - q1.x)
		return (d1 * d2 < 0) and (d3 * d4 < 0)

	for i in range(points1.size() - 1):
		var a1 = points1[i]
		var a2 = points1[i + 1]
		for j in range(points2.size() - 1):
			var b1 = points2[j]
			var b2 = points2[j + 1]
			if segments_intersect.call(a1, a2, b1, b2):
				return true
	return false


func rotate_along_curve(curve: Curve2D, point: Vector2) -> float:
	var closest_offset = curve.get_closest_offset(point)
	var curve_transform = curve.sample_baked_with_rotation(closest_offset, true)
	var rotation_angle = curve_transform.get_rotation()

	return rotation_angle


func get_point_along_curve(curve: Curve2D, distance: float, x_offset: float = 0.0) -> Vector2:
	if not curve or curve.point_count == 0:
		return Vector2.ZERO

	var length = curve.get_baked_length()
	var clamped_distance = clamp(distance, 0.0, length)
	var base_point = curve.sample_baked(clamped_distance)

	if x_offset == 0:
		return base_point

	var curve_transform = curve.sample_baked_with_rotation(clamped_distance, true)
	var tangent = curve_transform.x.normalized()
	var normal = Vector2(-tangent.y, tangent.x)

	return base_point + normal * x_offset


func get_distance_from_point(curve: Curve2D, point: Vector2) -> float:
	if not curve or curve.point_count == 0:
		return 0.0

	var point_on_curve = curve.get_closest_point(point)
	var closest_offset = curve.get_closest_offset(point_on_curve)
	return closest_offset


func rotate_perpendicular_to_curve(curve: Curve2D, point: Vector2) -> float:
	var closest_offset = curve.get_closest_offset(point)
	var curve_transform = curve.sample_baked_with_rotation(closest_offset, true)
	var rotation_angle = curve_transform.get_rotation() + PI / 2.0

	return rotation_angle


func get_curve_chunks(curve: Curve2D, chunk_length: float) -> Array:
	var chunks: Array = []
	if not curve or curve.point_count == 0:
		return chunks

	var total_length = curve.get_baked_length()
	var current_distance = 0.0
	while current_distance < total_length:
		var end_distance = min(current_distance + chunk_length, total_length)
		var chunk_curve = Curve2D.new()

		var start_point = curve.sample_baked(current_distance)
		var end_point = curve.sample_baked(end_distance)

		var start_transform = curve.sample_baked_with_rotation(current_distance, true)
		var start_tangent = start_transform.x.normalized()

		var end_transform = curve.sample_baked_with_rotation(end_distance, true)
		var end_tangent = end_transform.x.normalized()

		chunk_curve.add_point(start_point)
		chunk_curve.set_point_out(0, start_tangent * (end_distance - current_distance) / 3.0)

		chunk_curve.add_point(end_point)
		chunk_curve.set_point_in(1, -end_tangent * (end_distance - current_distance) / 3.0)

		chunks.append(chunk_curve)
		current_distance += chunk_length

	return chunks


func get_polygon_chunks(poly: Polygon2D, chunk_size: float = 100.0) -> Array[Polygon2D]:
	var chunks: Array[Polygon2D] = []

	if not poly or poly.polygon.size() < 3:
		return chunks

	var points = poly.polygon
	var min_x = INF
	var min_y = INF
	var max_x = -INF
	var max_y = -INF

	for point in points:
		min_x = min(min_x, point.x)
		min_y = min(min_y, point.y)
		max_x = max(max_x, point.x)
		max_y = max(max_y, point.y)

	var y = min_y
	while y < max_y:
		var x = min_x
		while x < max_x:
			var cell_rect = PackedVector2Array(
				[
					Vector2(x, y),
					Vector2(x + chunk_size, y),
					Vector2(x + chunk_size, y + chunk_size),
					Vector2(x, y + chunk_size),
				],
			)

			var intersected = Geometry2D.intersect_polygons(points, cell_rect)

			for intersected_poly in intersected:
				if intersected_poly.size() >= 3:
					var chunk_poly = Polygon2D.new()
					chunk_poly.polygon = intersected_poly
					chunk_poly.color = poly.color
					chunk_poly.texture = poly.texture
					chunk_poly.texture_offset = poly.texture_offset
					chunk_poly.texture_scale = poly.texture_scale
					chunk_poly.texture_rotation = poly.texture_rotation
					chunks.append(chunk_poly)

			x += chunk_size
		y += chunk_size

	return chunks


func get_curves_total_length(curves: Array) -> float:
	var total_length: float = 0.0

	for curve in curves:
		if curve:
			total_length += curve.get_baked_length()

	return total_length


func approximate_curve_from_line(line: Line2D) -> Curve2D:
	var curve = Curve2D.new()
	for i in range(line.get_point_count()):
		var point = line.get_point_position(i)
		curve.add_point(point)
	return curve
