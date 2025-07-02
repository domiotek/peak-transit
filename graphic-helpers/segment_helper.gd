extends Node

func find_perpendicular_segment_at_node(segments: Array, node_id: int) -> NetSegment:

	for segment in segments:
		var tangent: Vector2
		if segment.nodes[0].id == node_id:
			tangent = segment.main_layer_curve.get_point_out(0).normalized()
		else:
			var last_point = segment.main_layer_curve.point_count - 1
			tangent = -segment.main_layer_curve.get_point_in(last_point).normalized()
		
		var is_perpendicular = true
		for other_segment in segments:
			if other_segment == segment:
				continue
			
			var other_tangent: Vector2
			if other_segment.nodes[0].id == node_id:
				other_tangent = other_segment.main_layer_curve.get_point_out(0).normalized()
			else:
				var other_last_point = other_segment.main_layer_curve.point_count - 1
				other_tangent = -other_segment.main_layer_curve.get_point_in(other_last_point).normalized()
			
			var dot_product = abs(tangent.dot(other_tangent))
			if dot_product > 0.3:
				is_perpendicular = false
				break
		
		if is_perpendicular:
			return segment

	return null

func get_segment_edge_points_at_node(segment: NetSegment, node_id: int,  sample_offset=0.0) -> Dictionary:
	var road_half_width = (segment.total_lanes * NetworkConstants.LANE_WIDTH) / 2.0
	
	var main_curve = segment.main_layer_curve
	if not main_curve:
		return {}

	var is_at_start = segment.nodes[0].id == node_id
	var sample_position = 0.0 + sample_offset if is_at_start else main_curve.get_baked_length() - sample_offset
	
	var center_point = main_curve.sample_baked(sample_position)
	var tangent: Vector2
	
	if is_at_start:
		tangent = main_curve.get_point_out(0).normalized()
	else:
		var last_point = main_curve.point_count - 1
		tangent = -main_curve.get_point_in(last_point).normalized()
	
	var perpendicular = Vector2(-tangent.y, tangent.x)

	var left_edge = center_point - perpendicular * road_half_width
	var right_edge = center_point + perpendicular * road_half_width

	
	return {
		"center": center_point,
		"left_edge": left_edge,
		"right_edge": right_edge,
		"tangent": tangent,
		"perpendicular": perpendicular,
		"width": road_half_width * 2,
		"is_at_start": is_at_start
	}

enum RoadSide {
	Left, Right
}


func get_road_side_at_endpoint(segment: NetSegment, point: Vector2) -> RoadSide:
	var curve = segment.main_layer_curve
	if not curve or curve.get_baked_length() == 0:
		return RoadSide.Right
	
	var start_point = curve.sample_baked(0.0)
	var end_point = curve.sample_baked(curve.get_baked_length())
	
	var is_at_start = start_point.distance_to(point) < end_point.distance_to(point)
	var closest_point = start_point if is_at_start else end_point
	
	var sample_distance = min(10.0, curve.get_baked_length() * 0.1)
	var second_point: Vector2
	
	if is_at_start:
		second_point = curve.sample_baked(sample_distance)
	else:
		second_point = curve.sample_baked(curve.get_baked_length() - sample_distance)
	
	var direction = second_point - closest_point
	var to_point = point - closest_point
	var cross_product = direction.cross(to_point)
	
	if cross_product > 0:
		return RoadSide.Left
	else:
		return RoadSide.Right
