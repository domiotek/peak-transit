extends Node

class_name ConnectionsHelper

const LaneCalculatorScript = preload("res://helpers/LaneCalculator.cs")
var lane_calculator = LaneCalculator.new()

func setup_one_segment_connections(node: RoadNode) -> void:
	if node == null or  node.connected_segments.size() != 1:
		return

	var segment = node.connected_segments[0]
	var edge_info = SegmentHelper.get_segment_edge_points_at_node(segment, node.id)

	for in_id in node.incoming_endpoints:
		var in_endpoint = NetworkManager.get_lane_endpoint(in_id)

		for out_id in node.outgoing_endpoints:
			var out_endpoint = NetworkManager.get_lane_endpoint(out_id)
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
		 
		
func setup_two_segment_connections(node: RoadNode) -> void:
	if node == null or node.connected_segments.size() != 2:
		return

	var seg1 = node.connected_segments[0]
	var seg2 = node.connected_segments[1]

	for in_id in node.incoming_endpoints:
		var in_endpoint = NetworkManager.get_lane_endpoint(in_id)
		var other_segment = seg2 if seg1.endpoints.has(in_id) else seg1

		for out_id in node.outgoing_endpoints:
			var out_endpoint = NetworkManager.get_lane_endpoint(out_id)
			if other_segment.endpoints.has(out_id):
				if abs(in_endpoint.LaneNumber - out_endpoint.LaneNumber) >1:
					continue

				in_endpoint.AddConnection(out_id)
				var connections_array = node.connections.get(in_id, [])
				connections_array.append(out_id)
				node.connections[in_id] = connections_array

				var direction = -1 if in_endpoint.LaneNumber < out_endpoint.LaneNumber else 1
				var strength = 0.0 if in_endpoint.LaneNumber == out_endpoint.LaneNumber else 0.1

				var curve = LineHelper.calc_curve(node.to_local(in_endpoint.Position), node.to_local(out_endpoint.Position), strength, direction)

				node.add_connection_path(in_id, out_id, curve)

func setup_mutli_segment_connections(node: RoadNode) -> void:

	for segment in node.connected_segments:
		var in_endpoints = segment.endpoints.filter(func (_id): return node.incoming_endpoints.has(_id))

		var directions = SegmentHelper.get_segment_directions_from_segment(node, segment, node.connected_segments.filter(func (s): return s != segment))

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
				var endpoint = NetworkManager.get_lane_endpoint(_id)
				if endpoint:
					endpoints_dict[direction].append(endpoint)

		var in_endpoints_array = []
		for endpoint_id in in_endpoints:
			var endpoint = NetworkManager.get_lane_endpoint(endpoint_id)
			if endpoint:
				in_endpoints_array.append(endpoint)

		var config_manager = get_node("/root/ConfigManager")

		if config_manager.PrintIntersectionSegmentsOrientations:
			print("Incoming Endpoints: ", in_endpoints)
			print("Forward Endpoints: ", ids_dict["forward"])
			print("Left Endpoints: ", ids_dict["left"])
			print("Right Endpoints: ", ids_dict["right"])
		

		var new_connections = lane_calculator.CalculateLaneConnections(in_endpoints_array, endpoints_dict["left"], endpoints_dict["forward"], endpoints_dict["right"])

		node.connections.merge(new_connections)

		for in_id in new_connections.keys():
			var in_endpoint = NetworkManager.get_lane_endpoint(in_id)

			for out_id in new_connections[in_id]:
				var out_endpoint = NetworkManager.get_lane_endpoint(out_id)

				var is_forward = endpoints_dict["forward"].has(out_endpoint)
				var strength
				var direction

				if is_forward:
					direction = -1 if in_endpoint.LaneNumber < out_endpoint.LaneNumber else 1
					strength = 0.0 if in_endpoint.LaneNumber == out_endpoint.LaneNumber else 0.1
				else:
					direction = 1 if endpoints_dict['left'].has(out_endpoint) else -1
					strength = 0.5

				var curve = LineHelper.calc_curve(node.to_local(in_endpoint.Position), node.to_local(out_endpoint.Position), strength, direction)
				node.add_connection_path(in_id, out_id, curve)
