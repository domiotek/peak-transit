class_name ConnectionsHelper

var lane_calculator
var line_helper
var segment_helper
var network_manager


func inject_dependencies() -> void:
	lane_calculator = GDInjector.inject("LaneCalculator") as LaneCalculator
	line_helper = GDInjector.inject("LineHelper") as LineHelper
	segment_helper = GDInjector.inject("SegmentHelper") as SegmentHelper
	network_manager = GDInjector.inject("NetworkManager") as NetworkManager


func setup_one_segment_connections(node: RoadNode) -> void:
	if node == null or node.connected_segments.size() != 1:
		return

	var segment = node.connected_segments[0]
	var is_start_of_segment = segment.nodes[0] == node
	var edge_info = segment_helper.get_segment_edge_points_at_node(segment, node.id)

	node.segment_directions[segment.id] = {
		"forward": null,
		"backward": segment,
		"left": null,
		"right": null,
	}

	for in_id in node.incoming_endpoints:
		var in_endpoint = network_manager.get_lane_endpoint(in_id)

		var target_lane = segment.get_lane(in_endpoint.LaneId)
		target_lane.direction = Enums.Direction.BACKWARD

		for out_id in node.outgoing_endpoints:
			var out_endpoint = network_manager.get_lane_endpoint(out_id)
			if segment.endpoints.has(out_id):
				var lane_diff = abs(in_endpoint.LaneNumber - out_endpoint.LaneNumber)
				if lane_diff > 1:
					continue

				in_endpoint.Connections.append(out_id)
				var connections_array = node.connections.get(in_id, [])
				connections_array.append(out_id)
				node.connections[in_id] = connections_array

				var tangent = edge_info["tangent"] * (-1 if is_start_of_segment else 1)
				var offset = (in_endpoint.LaneNumber + 1) * NetworkConstants.LANE_WIDTH * 2
				var offset_point = edge_info["center"] + tangent * offset
				var p0 = node.to_local(in_endpoint.Position)
				var p1 = node.to_local(offset_point)
				var p2 = node.to_local(out_endpoint.Position)

				var curve := Curve2D.new()
				var segments_count := 16

				for i in range(segments_count + 1):
					var t := i / float(segments_count)
					var a := p0.lerp(p1, t)
					var b := p1.lerp(p2, t)
					var point := a.lerp(b, t)
					curve.add_point(point)

				node.add_connection_path(in_id, out_id, curve, Enums.Direction.BACKWARD)
				add_direction_marker(node, in_endpoint, "backward", 0)


func setup_two_segment_connections(node: RoadNode) -> void:
	if node == null or node.connected_segments.size() != 2:
		return

	var seg1 = node.connected_segments[0]
	var seg2 = node.connected_segments[1]

	for in_id in node.incoming_endpoints:
		var in_endpoint = network_manager.get_lane_endpoint(in_id)
		var in_segment = seg1 if seg1.endpoints.has(in_id) else seg2
		var other_segment = seg2 if in_segment == seg1 else seg1

		var target_lane = in_segment.get_lane(in_endpoint.LaneId)
		var is_enabled = target_lane.data.direction != NetLaneInfo.LaneDirection.Backward

		target_lane.direction = Enums.Direction.FORWARD if is_enabled else Enums.Direction.UNSPECIFIED

		node.segment_directions[in_segment.id] = {
			"forward": other_segment,
			"backward": null,
			"left": null,
			"right": null,
		}

		if not is_enabled:
			continue

		for out_id in node.outgoing_endpoints:
			var out_endpoint = network_manager.get_lane_endpoint(out_id)
			if other_segment.endpoints.has(out_id):
				if abs(in_endpoint.LaneNumber - out_endpoint.LaneNumber) > 1:
					continue

				in_endpoint.Connections.append(out_id)
				var connections_array = node.connections.get(in_id, [])
				connections_array.append(out_id)
				node.connections[in_id] = connections_array

				create_connecting_path(in_id, out_id, node, Enums.Direction.FORWARD)

		var public_transport_only_direction = _check_for_public_transport_only_direction(target_lane)

		if public_transport_only_direction != Enums.BaseDirection.UNSPECIFIED:
			add_direction_marker(
				node,
				in_endpoint,
				"bus_lane",
				NetworkConstants.DIRECTION_MARKER_OFFSET + NetworkConstants.DIRECTION_LABEL_OFFSET,
			)


func setup_mutli_segment_connections(node: RoadNode) -> void:
	for segment in node.connected_segments:
		var in_endpoints = segment.endpoints.filter(func(_id): return node.incoming_endpoints.has(_id))

		var directions = segment_helper.get_segment_directions_from_segment(node, segment, node.connected_segments.filter(func(s): return s != segment))

		var endpoints_dict = {
			"forward": [],
			"backward": [],
			"left": [],
			"right": [],
		}

		var ids_dict = {
			"forward": [],
			"backward": [],
			"left": [],
			"right": [],
		}

		node.segment_directions[segment.id] = directions

		for direction in directions.keys():
			if directions[direction] == null:
				continue

			var ids = directions[direction].endpoints.filter(func(_id): return node.outgoing_endpoints.has(_id))
			ids_dict[direction] = ids
			for endpoint_id in ids:
				var endpoint = network_manager.get_lane_endpoint(endpoint_id)
				if endpoint:
					endpoints_dict[direction].append(endpoint)

		var in_endpoints_array = []
		for endpoint_id in in_endpoints:
			var endpoint = network_manager.get_lane_endpoint(endpoint_id)
			if endpoint:
				in_endpoints_array.append(endpoint)

		var new_connections = lane_calculator.CalculateLaneConnections(
			in_endpoints_array,
			endpoints_dict["left"],
			endpoints_dict["forward"],
			endpoints_dict["right"],
		)

		node.connections.merge(new_connections)

		var possible_directions = node.get_segment_directions(segment.id)

		for in_id in new_connections.keys():
			var in_endpoint = network_manager.get_lane_endpoint(in_id)
			var in_lane = network_manager.get_segment(in_endpoint.SegmentId).get_lane(in_endpoint.LaneId)

			for out_id in new_connections[in_id]:
				var conn_direction = determine_connection_direction(ids_dict, out_id)
				create_connecting_path(in_id, out_id, node, conn_direction)
				in_endpoint.Connections.append(out_id)
				var base_direction = convert_to_base_direction(conn_direction)
				in_endpoint.ConnectionsExt[out_id] = {
					"Direction": base_direction,
					"AllowedVehicles": in_lane.data.allowed_vehicles.get(base_direction, []),
				}

			var public_transport_only_direction = _check_for_public_transport_only_direction(in_lane)

			var direction = determine_lane_direction(ids_dict, new_connections[in_id])

			var target_lane = segment.get_lane(in_endpoint.LaneId)
			target_lane.direction = direction

			if public_transport_only_direction != Enums.BaseDirection.UNSPECIFIED and possible_directions.has(public_transport_only_direction):
				var subtracted_direction = subtract_base_direction(direction, public_transport_only_direction)

				if subtracted_direction != Enums.Direction.UNSPECIFIED:
					if direction == subtracted_direction:
						# Subtracted incompatible directions (e.g. right - forward = right) resulting in same direction
						# Bus lane direction is out of the calculated direction, need to update global lane direction
						target_lane.direction = add_base_direction(direction, public_transport_only_direction)

					direction = subtracted_direction

					var pt_direction_marker_name = _map_direction_to_marker_name(convert_to_combined_direction(public_transport_only_direction))
					add_direction_marker(
						node,
						in_endpoint,
						pt_direction_marker_name,
						NetworkConstants.SUPPORT_DIRECTION_MARKER_OFFSET,
						NetworkConstants.SUPPORT_MARKER_TINT,
					)
					add_direction_marker(
						node,
						in_endpoint,
						"bus_lane",
						NetworkConstants.SUPPORT_DIRECTION_MARKER_OFFSET + NetworkConstants.DIRECTION_LABEL_OFFSET,
						NetworkConstants.SUPPORT_MARKER_TINT,
					)
				else:
					add_direction_marker(
						node,
						in_endpoint,
						"bus_lane",
						NetworkConstants.DIRECTION_MARKER_OFFSET + NetworkConstants.DIRECTION_LABEL_OFFSET,
					)
			target_lane.bus_lane_direction = convert_to_combined_direction(public_transport_only_direction)
			var direction_marker_name = _map_direction_to_marker_name(direction)
			add_direction_marker(node, in_endpoint, direction_marker_name)


func create_connecting_path(in_id: int, out_id: int, node: RoadNode, direction: Enums.Direction) -> void:
	var in_endpoint = network_manager.get_lane_endpoint(in_id)
	var out_endpoint = network_manager.get_lane_endpoint(out_id)

	var in_segment = network_manager.get_segment(in_endpoint.SegmentId)
	var out_segment = network_manager.get_segment(out_endpoint.SegmentId)

	var in_curve = in_segment.get_lane(in_endpoint.LaneId).get_curve()
	var out_curve = out_segment.get_lane(out_endpoint.LaneId).get_curve()

	if not in_curve or not out_curve:
		return

	var curve = line_helper.get_connecting_curve(in_curve, out_curve)
	curve = line_helper.convert_curve_global_to_local(curve, node)
	node.add_connection_path(in_id, out_id, curve, direction)


func add_direction_marker(
		node: RoadNode,
		in_endpoint: Dictionary,
		asset_name: String,
		marker_offset: float = NetworkConstants.DIRECTION_MARKER_OFFSET,
		modulate = Color(1, 1, 1, 1),
) -> void:
	var asset_path = "res://assets/road_markers/" + asset_name + "_marker.svg"
	var marker_image = load(asset_path)

	if not marker_image:
		print("Failed to load asset: ", asset_path)

	var target_segment = network_manager.get_segment(in_endpoint.SegmentId)

	if not target_segment:
		return

	var lane = target_segment.get_lane(in_endpoint.LaneId)
	if not lane:
		return

	var curve = lane.trail.curve
	var curve_length = curve.get_baked_length()

	var start_point = curve.sample_baked(0)
	var end_point = curve.sample_baked(curve_length)
	var endpoint_pos = in_endpoint.Position

	var distance_to_start = start_point.distance_to(endpoint_pos)
	var distance_to_end = end_point.distance_to(endpoint_pos)

	var offset
	var rotation_offset = 0.0
	if distance_to_start < distance_to_end:
		offset = marker_offset + distance_to_start
		rotation_offset = PI
	else:
		offset = curve_length - marker_offset - distance_to_end

	var point_on_curve = curve.sample_baked(offset)
	var tangent = curve.sample_baked_with_rotation(offset).y
	var position = point_on_curve + tangent.normalized()

	var marker_sprite = Sprite2D.new()
	marker_sprite.set_meta("endpoint_id", in_endpoint.Id)
	marker_sprite.texture = marker_image
	marker_sprite.scale = Vector2(0.125, 0.125)
	marker_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	marker_sprite.modulate = modulate

	marker_sprite.position = node.to_local(position)
	var rotation = tangent.angle() + rotation_offset
	marker_sprite.rotation = rotation
	node.markings_layer.add_child(marker_sprite)


func determine_connection_direction(directions_dict: Dictionary, other_endpoint: int) -> Enums.Direction:
	if directions_dict["left"].has(other_endpoint):
		return Enums.Direction.LEFT
	if directions_dict["forward"].has(other_endpoint):
		return Enums.Direction.FORWARD
	if directions_dict["right"].has(other_endpoint):
		return Enums.Direction.RIGHT

	return Enums.Direction.BACKWARD


func convert_to_base_direction(direction: Enums.Direction) -> Enums.BaseDirection:
	match direction:
		Enums.Direction.FORWARD:
			return Enums.BaseDirection.FORWARD
		Enums.Direction.LEFT:
			return Enums.BaseDirection.LEFT
		Enums.Direction.RIGHT:
			return Enums.BaseDirection.RIGHT
		_:
			return Enums.BaseDirection.FORWARD


func convert_to_combined_direction(base_direction: Enums.BaseDirection) -> Enums.Direction:
	match base_direction:
		Enums.BaseDirection.FORWARD:
			return Enums.Direction.FORWARD
		Enums.BaseDirection.LEFT:
			return Enums.Direction.LEFT
		Enums.BaseDirection.RIGHT:
			return Enums.Direction.RIGHT
		_:
			return Enums.Direction.UNSPECIFIED


func determine_lane_direction(directions_dict: Dictionary, lane_connections: Array) -> Enums.Direction:
	var has_left = directions_dict["left"].filter(func(x): return lane_connections.has(x)).size() > 0
	var has_forward = directions_dict["forward"].filter(func(x): return lane_connections.has(x)).size() > 0
	var has_right = directions_dict["right"].filter(func(x): return lane_connections.has(x)).size() > 0

	return construct_direction(has_left, has_forward, has_right)


func construct_direction(has_left: bool, has_forward: bool, has_right: bool) -> Enums.Direction:
	var direction_bits = (int(has_left) << 2) | (int(has_forward) << 1) | int(has_right)

	match direction_bits:
		0b001:
			return Enums.Direction.RIGHT
		0b010:
			return Enums.Direction.FORWARD
		0b011:
			return Enums.Direction.RIGHT_FORWARD
		0b100:
			return Enums.Direction.LEFT
		0b101:
			return Enums.Direction.LEFT_RIGHT
		0b110:
			return Enums.Direction.LEFT_FORWARD
		0b111:
			return Enums.Direction.ALL_DIRECTIONS
		_:
			return Enums.Direction.BACKWARD


func deconstruct_direction(direction: Enums.Direction) -> Dictionary:
	var has_left = false
	var has_forward = false
	var has_right = false

	match direction:
		Enums.Direction.LEFT:
			has_left = true
		Enums.Direction.FORWARD:
			has_forward = true
		Enums.Direction.RIGHT:
			has_right = true
		Enums.Direction.LEFT_FORWARD:
			has_left = true
			has_forward = true
		Enums.Direction.RIGHT_FORWARD:
			has_right = true
			has_forward = true
		Enums.Direction.LEFT_RIGHT:
			has_left = true
			has_right = true
		Enums.Direction.ALL_DIRECTIONS:
			has_left = true
			has_forward = true
			has_right = true

	return {
		"has_left": has_left,
		"has_forward": has_forward,
		"has_right": has_right,
	}


func is_combined_direction(direction: Enums.Direction) -> bool:
	return direction in [Enums.Direction.LEFT_FORWARD, Enums.Direction.RIGHT_FORWARD, Enums.Direction.LEFT_RIGHT, Enums.Direction.ALL_DIRECTIONS]


func is_in_combined_direction(direction: Enums.Direction, basic_direction: Enums.Direction) -> bool:
	if basic_direction == Enums.Direction.FORWARD:
		return direction in [Enums.Direction.FORWARD, Enums.Direction.LEFT_FORWARD, Enums.Direction.RIGHT_FORWARD, Enums.Direction.ALL_DIRECTIONS]
	if basic_direction == Enums.Direction.LEFT:
		return direction in [Enums.Direction.LEFT, Enums.Direction.LEFT_FORWARD, Enums.Direction.LEFT_RIGHT, Enums.Direction.ALL_DIRECTIONS]
	if basic_direction == Enums.Direction.RIGHT:
		return direction in [Enums.Direction.RIGHT, Enums.Direction.RIGHT_FORWARD, Enums.Direction.LEFT_RIGHT, Enums.Direction.ALL_DIRECTIONS]

	return false


func subtract_base_direction(direction: Enums.Direction, base_direction: Enums.BaseDirection) -> Enums.Direction:
	if base_direction == null:
		return direction

	match base_direction:
		Enums.BaseDirection.FORWARD:
			if direction == Enums.Direction.FORWARD:
				return Enums.Direction.UNSPECIFIED
			if direction == Enums.Direction.LEFT_FORWARD:
				return Enums.Direction.LEFT
			if direction == Enums.Direction.RIGHT_FORWARD:
				return Enums.Direction.RIGHT
			if direction == Enums.Direction.ALL_DIRECTIONS:
				return Enums.Direction.LEFT_RIGHT
		Enums.BaseDirection.LEFT:
			if direction == Enums.Direction.LEFT:
				return Enums.Direction.UNSPECIFIED
			if direction == Enums.Direction.LEFT_FORWARD:
				return Enums.Direction.FORWARD
			if direction == Enums.Direction.LEFT_RIGHT:
				return Enums.Direction.RIGHT
			if direction == Enums.Direction.ALL_DIRECTIONS:
				return Enums.Direction.RIGHT_FORWARD
		Enums.BaseDirection.RIGHT:
			if direction == Enums.Direction.RIGHT:
				return Enums.Direction.UNSPECIFIED
			if direction == Enums.Direction.RIGHT_FORWARD:
				return Enums.Direction.FORWARD
			if direction == Enums.Direction.LEFT_RIGHT:
				return Enums.Direction.LEFT
			if direction == Enums.Direction.ALL_DIRECTIONS:
				return Enums.Direction.LEFT_FORWARD

	return direction


func add_base_direction(direction: Enums.Direction, base_direction: Enums.BaseDirection) -> Enums.Direction:
	if base_direction == null:
		return direction

	match base_direction:
		Enums.BaseDirection.FORWARD:
			if direction == Enums.Direction.UNSPECIFIED:
				return Enums.Direction.FORWARD
			if direction == Enums.Direction.LEFT:
				return Enums.Direction.LEFT_FORWARD
			if direction == Enums.Direction.RIGHT:
				return Enums.Direction.RIGHT_FORWARD
			if direction == Enums.Direction.LEFT_RIGHT:
				return Enums.Direction.ALL_DIRECTIONS
		Enums.BaseDirection.LEFT:
			if direction == Enums.Direction.UNSPECIFIED:
				return Enums.Direction.LEFT
			if direction == Enums.Direction.FORWARD:
				return Enums.Direction.LEFT_FORWARD
			if direction == Enums.Direction.RIGHT:
				return Enums.Direction.LEFT_RIGHT
			if direction == Enums.Direction.RIGHT_FORWARD:
				return Enums.Direction.ALL_DIRECTIONS
		Enums.BaseDirection.RIGHT:
			if direction == Enums.Direction.UNSPECIFIED:
				return Enums.Direction.RIGHT
			if direction == Enums.Direction.FORWARD:
				return Enums.Direction.RIGHT_FORWARD
			if direction == Enums.Direction.LEFT:
				return Enums.Direction.LEFT_RIGHT
			if direction == Enums.Direction.LEFT_FORWARD:
				return Enums.Direction.ALL_DIRECTIONS

	return direction


func _map_direction_to_marker_name(direction: Enums.Direction) -> String:
	match direction:
		Enums.Direction.FORWARD:
			return "forward"
		Enums.Direction.LEFT:
			return "left"
		Enums.Direction.RIGHT:
			return "right"
		Enums.Direction.LEFT_FORWARD:
			return "left_forward"
		Enums.Direction.RIGHT_FORWARD:
			return "right_forward"
		Enums.Direction.LEFT_RIGHT:
			return "left_right"
		Enums.Direction.ALL_DIRECTIONS:
			return "all_directions"
		_:
			return "backward"


func _check_for_public_transport_only_direction(lane: NetLane) -> Enums.BaseDirection:
	for base_direction in Enums.BaseDirection.values():
		var allowed_vehicles = lane.data.allowed_vehicles.get(base_direction, [])
		if allowed_vehicles.size() == 1 and allowed_vehicles[0] == VehicleManager.VehicleCategory.PUBLIC_TRANSPORT:
			return base_direction
	return Enums.BaseDirection.UNSPECIFIED
