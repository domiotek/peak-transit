class_name PolygonHelper

static func get_bounding_box(polygon: PackedVector2Array, offset: float = 0.0) -> PackedVector2Array:
	if polygon.size() == 0:
		return PackedVector2Array()

	var min_x = polygon[0].x
	var max_x = polygon[0].x
	var min_y = polygon[0].y
	var max_y = polygon[0].y

	for point in polygon:
		if point.x < min_x:
			min_x = point.x
		if point.x > max_x:
			max_x = point.x
		if point.y < min_y:
			min_y = point.y
		if point.y > max_y:
			max_y = point.y

	return PackedVector2Array(
		[
			Vector2(min_x - offset, min_y - offset),
			Vector2(max_x + offset, min_y - offset),
			Vector2(max_x + offset, max_y + offset),
			Vector2(min_x - offset, max_y + offset),
		],
	)
