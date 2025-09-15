class_name LineHelper

var CurveTrimmerModule = load("res://helpers/graphic-helpers/curve_trimmer.gd") as Script


func calc_curve(start_pos: Vector2, target_pos: Vector2, strength: float, direction: int) -> Curve2D:
	var line_vector = target_pos - start_pos
	var line_length = line_vector.length()
	
	var perpendicular = Vector2(-line_vector.y, line_vector.x).normalized()
	var mid_point = (start_pos + target_pos) / 2.0
	var control_point = mid_point + perpendicular * line_length * strength * direction

	var curve = Curve2D.new()
	
	curve.add_point(start_pos)
	
	var to_control = 2.0/3.0 * (control_point - start_pos)
	var from_control = 2.0/3.0 * (control_point - target_pos)
	
	curve.set_point_out(0, to_control)

	curve.add_point(target_pos, from_control, Vector2.ZERO)

	return curve

func get_curve_with_offset(curve: Curve2D,offset: float) -> Curve2D:
	if not curve or not offset:
		return null
	
	var offset_curve = Curve2D.new()
	
	for i in range(curve.point_count):
		var original_point = curve.get_point_position(i)
		var original_in = curve.get_point_in(i)
		var original_out = curve.get_point_out(i)
		
		var perpendicular: Vector2
		
		if i == 0:
			var tangent = original_out.normalized()
			perpendicular = Vector2(-tangent.y, tangent.x)
		elif i == curve.point_count - 1:
			var tangent = (-original_in).normalized()
			perpendicular = Vector2(-tangent.y, tangent.x)
		else:
			var in_tangent = (-original_in).normalized()
			var out_tangent = original_out.normalized()
			var avg_tangent = (in_tangent + out_tangent).normalized()
			perpendicular = Vector2(-avg_tangent.y, avg_tangent.x)
		
		var offset_point = original_point + perpendicular * offset
		
		offset_curve.add_point(offset_point, original_in, original_out)
	
	return offset_curve



func draw_dash_line(
	curve: Curve2D, 
	target_layer: Node2D, 
	dash_length: float = NetworkConstants.DASH_LENGTH, 
	gap_length: float = NetworkConstants.DASH_GAP_LENGTH, 
	line_width: float = NetworkConstants.LINE_WIDTH, 
	line_color: Color = NetworkConstants.DASH_COLOR) -> void:

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
	line_color: Color = NetworkConstants.LINE_COLOR) -> void:

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
				curve1_start, curve1_end,
				curve2_start, curve2_end
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
				curve_start, curve_end,
				poly_start, poly_end
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
	var out_handle_1 = curve1.get_point_out(curve1.get_point_count() - 1)

	var start_pos_2 = curve2.get_point_position(0)
	var in_handle_2 = curve2.get_point_in(0)

	var distance = end_pos_1.distance_to(start_pos_2)

	if distance < NetworkConstants.SHARP_LANE_CONNECTION_THRESHOLD:
		var mid_point = (end_pos_1 + start_pos_2) * 0.5
		var dir = (start_pos_2 - end_pos_1).normalized()
		var normal = Vector2(dir.y, -dir.x)
		var arc_height = distance * 0.3

		var control1 = mid_point + normal * arc_height
		var control2 = mid_point + normal * arc_height

		connecting_curve.add_point(end_pos_1)
		connecting_curve.set_point_out(0, control1 - end_pos_1)

		connecting_curve.add_point(start_pos_2)
		connecting_curve.set_point_in(1, control2 - start_pos_2)
	else:
		connecting_curve.add_point(end_pos_1)
		connecting_curve.set_point_out(0, out_handle_1)
		connecting_curve.add_point(start_pos_2)
		connecting_curve.set_point_in(1, in_handle_2)


	return connecting_curve


func convert_curve_global_to_local(connecting_curve: Curve2D, target_node: Node2D) -> Curve2D:
	var local_curve = Curve2D.new()

	for i in range(connecting_curve.get_point_count()):
		var global_point = connecting_curve.get_point_position(i)
		var global_out_handle = connecting_curve.get_point_out(i)
		var global_in_handle = connecting_curve.get_point_in(i)

		var local_point = target_node.to_local(global_point)
		var local_out_handle = target_node.to_local(global_point + global_out_handle) - local_point
		var local_in_handle = target_node.to_local(global_point + global_in_handle) - local_point

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
