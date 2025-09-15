class_name CurveTrimmer


func trim_curve(curve: Curve2D, start_pos: Vector2, end_pos: Vector2) -> Curve2D:
	if not curve or curve.point_count < 2:
		return null

	var start_offset = curve.get_closest_offset(start_pos)
	var end_offset = curve.get_closest_offset(end_pos)
	if start_offset > end_offset:
		var temp = end_offset
		end_offset = start_offset
		start_offset = temp

	var start_seg_data = _find_segment_and_t(curve, start_offset)
	var end_seg_data = _find_segment_and_t(curve, end_offset)
	
	var start_segment = start_seg_data.segment
	var start_t = start_seg_data.t
	var end_segment = end_seg_data.segment
	var end_t = end_seg_data.t

	var new_curve = Curve2D.new()

	var start_data = _interpolate_handles(curve, start_segment, start_t)
	new_curve.add_point(start_pos, start_data.in_handle, start_data.out_handle)

	for i in range(start_segment + 1, end_segment + 1):
		new_curve.add_point(curve.get_point_position(i), curve.get_point_in(i), curve.get_point_out(i))

	var end_data = _interpolate_handles(curve, end_segment, end_t)
	new_curve.add_point(end_pos, end_data.in_handle, end_data.out_handle)

	return new_curve

func _interpolate_handles(curve: Curve2D, seg: int, t: float) -> Dictionary:
	var p0 = curve.get_point_position(seg)
	var p1 = curve.get_point_position(seg + 1)
	var out0 = curve.get_point_out(seg)
	var in1 = curve.get_point_in(seg + 1)

	var abs_out0 = p0 + out0
	var abs_in1 = p1 + in1

	var mt = 1.0 - t
	var point = p0 * mt * mt * mt + abs_out0 * 3 * mt * mt * t + abs_in1 * 3 * mt * t * t + p1 * t * t * t

	var deriv = 3 * (abs_out0 - p0) * mt * mt + 6 * (abs_in1 - abs_out0) * mt * t + 3 * (p1 - abs_in1) * t * t
	deriv = deriv.normalized()

	var out_len = out0.length() * (1 - t)
	var in_len = in1.length() * t

	return {
		"pos": point,
		"in_handle": -deriv * in_len,
		"out_handle": deriv * out_len
	}


func _find_segment_and_t(curve: Curve2D, offset: float) -> Dictionary:
	var point_count = curve.point_count
	var lengths = []

	var cumulative = 0.0
	for i in range(point_count - 1):
		var seg_start = curve.get_baked_length() * i / (point_count - 1)
		var seg_end = curve.get_baked_length() * (i + 1) / (point_count - 1)
		cumulative +=  seg_end - seg_start
		lengths.append(cumulative)

	var seg = 0
	for i in range(lengths.size()):
		if offset <= lengths[i]:
			seg = i
			break

	var prev_cum = 0.0 if seg == 0 else lengths[seg - 1]
	var seg_length = lengths[seg] - prev_cum
	var t = (offset - prev_cum) / seg_length
	t = clamp(t, 0.0, 1.0)

	return {"segment": seg, "t": t}