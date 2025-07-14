extends Node


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
	
	return remove_duplicate_points(intersections, offset_tolerance)

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
