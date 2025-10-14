class_name SegmentHelper

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
	var curve = segment.curve_shape
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


func get_segment_directions_from_segment(node: RoadNode, ref_segment: NetSegment, other_segments: Array) -> Dictionary:
	var directions = {
		"left": null,
		"right": null,
		"forward": null,
		"backward": ref_segment
	}

	var assigned_segments = []

	var ref_curve = ref_segment.main_layer_curve
	if not ref_curve:
		return directions
	
	var node_id = node.id
	
	var ref_edge_data = get_segment_edge_points_at_node(ref_segment, node_id)
	if ref_edge_data.is_empty():
		return directions
	
	var ref_center = ref_edge_data["center"]
	var ref_tangent = ref_edge_data["tangent"]
	
	var sample_distance = 60.0
	var ref_sample_point: Vector2
	
	if ref_edge_data["is_at_start"]:
		var sample_pos = min(sample_distance, ref_curve.get_baked_length())
		ref_sample_point = ref_curve.sample_baked(sample_pos)
	else:
		var sample_pos = max(0.0, ref_curve.get_baked_length() - sample_distance)
		ref_sample_point = ref_curve.sample_baked(sample_pos)
	
	var ref_line_vector = (ref_sample_point - ref_center).normalized()
	
	for segment in other_segments:
		
		var segment_has_node = false
		for seg_node in segment.nodes:
			if seg_node.id == node_id:
				segment_has_node = true
				break
		
		if not segment_has_node:
			continue
		
		var other_edge_data = get_segment_edge_points_at_node(segment, node_id)
		if other_edge_data.is_empty():
			continue
		
		var other_tangent = other_edge_data["tangent"]
		
		var dot_product = ref_tangent.dot(other_tangent)
		
		if dot_product > 0.7:
			directions["forward"] = segment
			assigned_segments.append(segment)
		elif dot_product < -0.7:
			continue
		else:
			var other_sample_point: Vector2
			var other_curve = segment.main_layer_curve
			
			if other_edge_data["is_at_start"]:
				var sample_pos = min(sample_distance, other_curve.get_baked_length())
				other_sample_point = other_curve.sample_baked(sample_pos)
			else:
				var sample_pos = max(0.0, other_curve.get_baked_length() - sample_distance)
				other_sample_point = other_curve.sample_baked(sample_pos)
			
			var to_other_sample = other_sample_point - ref_center
			var cross_product = ref_line_vector.cross(to_other_sample)
			
			if cross_product > 0:
				directions["left"] = segment
				assigned_segments.append(segment)
			else:
				directions["right"] = segment
				assigned_segments.append(segment)


	if directions['forward'] == null:
		var unassigned_segment = other_segments.filter(func(s): return s not in assigned_segments)

		if unassigned_segment.size() > 0:
			directions['forward'] = unassigned_segment[0]
			assigned_segments.append(unassigned_segment[0])

	
	return directions


func get_edge_lanes(segment: NetSegment) -> Dictionary:
	if segment.lanes.size() == 0:
		return {}

	var result = {}

	for lane in segment.lanes:
		var relation_idx = lane.relation_id
		if not result.has(relation_idx):
			result[relation_idx] = lane
		else:
			var existing_lane = result[relation_idx]
			if lane.lane_number > existing_lane.lane_number:
				result[relation_idx] = lane

	return result
