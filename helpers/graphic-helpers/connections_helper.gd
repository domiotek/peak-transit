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
	if node == null or  node.connected_segments.size() != 1:
		return

	var segment = node.connected_segments[0]
	var edge_info = segment_helper.get_segment_edge_points_at_node(segment, node.id)

	for in_id in node.incoming_endpoints:
		var in_endpoint = network_manager.get_lane_endpoint(in_id)

		for out_id in node.outgoing_endpoints:
			var out_endpoint = network_manager.get_lane_endpoint(out_id)
			if segment.endpoints.has(out_id):
				if in_endpoint.LaneNumber != out_endpoint.LaneNumber:
					continue

				in_endpoint.AddConnection(out_id)
				var connections_array = node.connections.get(in_id, [])
				connections_array.append(out_id)
				node.connections[in_id] = connections_array

				var offset = (in_endpoint.LaneNumber + 1) * NetworkConstants.LANE_WIDTH * 2
				var offset_point = edge_info["center"] + edge_info["tangent"] * offset
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

				node.add_connection_path(in_id, out_id, curve)
				add_direction_marker(node, in_endpoint, "backward", 0)
			
		 
		
func setup_two_segment_connections(node: RoadNode) -> void:
	if node == null or node.connected_segments.size() != 2:
		return

	var seg1 = node.connected_segments[0]
	var seg2 = node.connected_segments[1]

	for in_id in node.incoming_endpoints:
		var in_endpoint = network_manager.get_lane_endpoint(in_id)
		var other_segment = seg2 if seg1.endpoints.has(in_id) else seg1

		for out_id in node.outgoing_endpoints:
			var out_endpoint = network_manager.get_lane_endpoint(out_id)
			if other_segment.endpoints.has(out_id):
				if abs(in_endpoint.LaneNumber - out_endpoint.LaneNumber) >1:
					continue

				in_endpoint.AddConnection(out_id)
				var connections_array = node.connections.get(in_id, [])
				connections_array.append(out_id)
				node.connections[in_id] = connections_array

				var direction = -1 if in_endpoint.LaneNumber < out_endpoint.LaneNumber else 1
				var strength = 0.0 if in_endpoint.LaneNumber == out_endpoint.LaneNumber else 0.1

				var curve = line_helper.calc_curve(node.to_local(in_endpoint.Position), node.to_local(out_endpoint.Position), strength, direction)

				node.add_connection_path(in_id, out_id, curve)

func setup_mutli_segment_connections(node: RoadNode) -> void:

	for segment in node.connected_segments:
		var in_endpoints = segment.endpoints.filter(func (_id): return node.incoming_endpoints.has(_id))

		var directions = segment_helper.get_segment_directions_from_segment(node, segment, node.connected_segments.filter(func (s): return s != segment))

		var endpoints_dict = {
			"forward": [],
			"backward": [],
			"left": [],
			"right": []
		}

		var ids_dict = {
			"forward": [],
			"backward": [],
			"left": [],
			"right": []
		}

		for direction in directions.keys():
			if directions[direction] == null:
				continue

			var ids = directions[direction].endpoints.filter(func (_id): return node.outgoing_endpoints.has(_id))
			ids_dict[direction] = ids
			for _id in ids:
				var endpoint = network_manager.get_lane_endpoint(_id)
				if endpoint:
					endpoints_dict[direction].append(endpoint)

		var in_endpoints_array = []
		for endpoint_id in in_endpoints:
			var endpoint = network_manager.get_lane_endpoint(endpoint_id)
			if endpoint:
				in_endpoints_array.append(endpoint)

		var config_manager = GDInjector.inject("ConfigManager") as ConfigManager

		if config_manager.DebugToggles.PrintIntersectionSegmentsOrientations:
			print("Incoming Endpoints: ", in_endpoints)
			print("Forward Endpoints: ", ids_dict["forward"])
			print("Left Endpoints: ", ids_dict["left"])
			print("Right Endpoints: ", ids_dict["right"])
		

		var new_connections = lane_calculator.CalculateLaneConnections(in_endpoints_array, endpoints_dict["left"], endpoints_dict["forward"], endpoints_dict["right"])

		node.connections.merge(new_connections)

		for in_id in new_connections.keys():
			var in_endpoint = network_manager.get_lane_endpoint(in_id)

			for out_id in new_connections[in_id]:
				var out_endpoint = network_manager.get_lane_endpoint(out_id)

				var is_forward = endpoints_dict["forward"].has(out_endpoint)
				var strength
				var direction

				if is_forward:
					direction = -1 if in_endpoint.LaneNumber < out_endpoint.LaneNumber else 1
					strength = 0.0 if in_endpoint.LaneNumber == out_endpoint.LaneNumber else 0.1
				else:
					direction = 1 if endpoints_dict['left'].has(out_endpoint) else -1
					strength = 0.5

				var curve = line_helper.calc_curve(node.to_local(in_endpoint.Position), node.to_local(out_endpoint.Position), strength, direction)
				node.add_connection_path(in_id, out_id, curve)
			var direction_marker_name = determine_direction_marker(ids_dict, new_connections[in_id])
			add_direction_marker(node, in_endpoint, direction_marker_name)


func add_direction_marker(node: RoadNode, in_endpoint: NetLaneEndpoint, asset_name: String, marker_offset: float=NetworkConstants.DIRECTION_MARKER_OFFSET) -> void:
	var asset_path = "res://assets/road_markers/" + asset_name + "_marker.svg"
	var marker_image = load(asset_path)

	if not marker_image:
		print("Failed to load asset: ", asset_path)

	var marker_sprite = Sprite2D.new()
	marker_sprite.texture = marker_image
	marker_sprite.scale = Vector2(0.125, 0.125)
	marker_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR


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

	marker_sprite.position = node.to_local(position)
	var rotation = tangent.angle() + rotation_offset
	marker_sprite.rotation = rotation
	marker_sprite.z_index = 10
	node.markings_layer.add_child(marker_sprite)


func determine_direction_marker(directions_dict: Dictionary, lane_connections: Array) -> String:
	var has_left = directions_dict["left"].filter(func (x): return lane_connections.has(x)).size() > 0
	var has_forward = directions_dict["forward"].filter(func (x): return lane_connections.has(x)).size() > 0
	var has_right = directions_dict["right"].filter(func (x): return lane_connections.has(x)).size() > 0

	var direction_bits = (int(has_left) << 2) | (int(has_forward) << 1) | int(has_right)
	
	match direction_bits:
		0b001:
			return "right"
		0b010:
			return "forward"
		0b011:
			return "right_forward"
		0b100:
			return "left"
		0b101:
			return "left_right"
		0b110:
			return "left_forward"
		0b111:
			return "all_directions"
		_:
			return "backward"
