extends Node2D
class_name RoadNode

const NodeLayerHelperScript = preload("res://graphic-helpers/node_layer_helper.gd")
const DebugCircleScript = preload("res://graphic-helpers/debug_circle.gd")
const LaneCalculatorScript = preload("res://helpers/LaneCalculator.cs")

var layerHelper: NodeLayerHelper = NodeLayerHelper.new()
var circleHelper: DebugCircleHelper = DebugCircleHelper.new()
var lane_calculator = LaneCalculator.new()
@onready var config_manager = get_node("/root/ConfigManager")

@export var id: int
var connections: Dictionary = {}
var incoming_endpoints: Array = []
var outgoing_endpoints: Array = []

var corner_points: PackedVector2Array = []
var connected_segments: Array = []


@onready var debug_layer: Node2D = $DebugLayer
@onready var markings_layer: Node2D = $MarkingsLayer
@onready var main_layer: Polygon2D = $MainLayer
@onready var under_layer: Polygon2D = $UnderLayer
@onready var boundary_layer: Polygon2D = $BoundaryLayer

func update_visuals() -> void:
	connected_segments = NetworkManager.get_node_connected_segments(id)

	var max_lanes = 0

	for segment in connected_segments:
		if segment.total_lanes > max_lanes:
			max_lanes = segment.total_lanes

	if connected_segments.size() > 0:
		var node_width = max_lanes * NetworkConstants.LANE_WIDTH

		if config_manager.DrawNodeLayers:
			under_layer.color = Color.RED
			under_layer.z_index = 1
			under_layer.z_as_relative = false
			main_layer.color = Color.GREEN
			boundary_layer.color = Color.BLUE_VIOLET

		if connected_segments.size() > 2:
			corner_points = layerHelper.find_intersection_corners(connected_segments)

			main_layer.polygon = layerHelper.create_precise_intersection_layer(self, connected_segments, corner_points)
			var perpendicular_segment = SegmentHelper.find_perpendicular_segment_at_node(connected_segments, id)
			var parallel_segments = connected_segments.filter(func(seg): return seg != perpendicular_segment)
			layerHelper.create_trapezoid_underlayer(self, parallel_segments)
		elif connected_segments.size() == 2 and connected_segments[0].total_lanes != connected_segments[1].total_lanes:
			layerHelper.create_trapezoid_underlayer(self, connected_segments)
		elif connected_segments.size() == 2:
			layerHelper.create_rectangle_underlayer(self, connected_segments, node_width, NetworkConstants.LANE_WIDTH)
		elif connected_segments.size() == 1:
			layerHelper.create_circle_underlayer(self, connected_segments[0], connected_segments[0].total_lanes * NetworkConstants.LANE_WIDTH / 2.0)

		if connected_segments.size() < 3:
			boundary_layer.polygon = layerHelper.create_simple_intersection(self, connected_segments, node_width, NetworkConstants.LANE_WIDTH)

	_update_debug_layer()

func late_update_visuals() -> void:
	_setup_connections()

	_update_debug_layer()

func get_intersection_polygon() -> PackedVector2Array:
	var global_points: PackedVector2Array = []

	var target_layer = main_layer if main_layer.polygon.size() > 0 else boundary_layer

	for point in target_layer.polygon:
		global_points.append(to_global(point))
	return global_points

func _update_debug_layer() -> void:
	for child in debug_layer.get_children():
		child.queue_free()

	if config_manager.DrawNetworkNodes:
		var circle = circleHelper.DebugCircle.new()
		circle.z_index = 1
		circle.radius = 24.0
		circle.color = Color.RED
		
		debug_layer.add_child(circle)


	if config_manager.DrawLaneEndpoints:
		for in_id in incoming_endpoints + outgoing_endpoints:
			var color = Color.DARK_KHAKI if incoming_endpoints.has(in_id) else Color.DARK_ORANGE

			var endpoint = NetworkManager.get_lane_endpoint(in_id)
			circleHelper._draw_debug_circle(to_local(endpoint.Position), color, debug_layer)

			if config_manager.DrawLaneEndpointIds:
				var label = Label.new()
				label.text = str(endpoint.Id)
				label.position = to_local(endpoint.Position)
				debug_layer.add_child(label)

		for point in corner_points:
			var circle = circleHelper.DebugCircle.new()
			circle.z_index = 5
			circle.radius = 1.0
			circle.color = Color.AQUA
			circle.position = to_local(point)
			
			debug_layer.add_child(circle)
	
	for in_id in connections.keys():
		var connection_array = connections[in_id]
		for out_id in connection_array:
			var line = Line2D.new()
			line.width = 1.0
			line.antialiased = true
			
			var start = NetworkManager.get_lane_endpoint(in_id)
			var end = NetworkManager.get_lane_endpoint(out_id)

			match abs(start.LaneNumber - end.LaneNumber):
				0:
					line.default_color = Color.GREEN
				1:
					line.default_color = Color.YELLOW
				2:
					line.default_color = Color.ORANGE
			
			line.points = [to_local(start.Position), to_local(end.Position)]
			debug_layer.add_child(line)

func _setup_connections() -> void:

	if connected_segments.size() == 0:
		return

	if connected_segments.size() == 1:
		_setup_one_segment_connections()
	elif connected_segments.size() == 2:
		_setup_two_segment_connections()
	else:
		_setup_mutli_segment_connections()

func _setup_one_segment_connections() -> void:
	if connected_segments.size() != 1:
		return

	var segment = connected_segments[0]

	for in_id in incoming_endpoints:
		var in_endpoint = NetworkManager.get_lane_endpoint(in_id)

		for out_id in outgoing_endpoints:
			var out_endpoint = NetworkManager.get_lane_endpoint(out_id)
			if segment.endpoints.has(out_id):
				if in_endpoint.LaneNumber != out_endpoint.LaneNumber:
					continue

				in_endpoint.AddConnection(out_id)
				var connections_array = connections.get(in_id, [])
				connections_array.append(out_id)
				connections[in_id] = connections_array
		 
		
func _setup_two_segment_connections() -> void:
	if connected_segments.size() != 2:
		return

	var seg1 = connected_segments[0]
	var seg2 = connected_segments[1]

	for in_id in incoming_endpoints:
		var in_endpoint = NetworkManager.get_lane_endpoint(in_id)
		var other_segment = seg2 if seg1.endpoints.has(in_id) else seg1

		for out_id in outgoing_endpoints:
			var out_endpoint = NetworkManager.get_lane_endpoint(out_id)
			if other_segment.endpoints.has(out_id):
				if abs(in_endpoint.LaneNumber - out_endpoint.LaneNumber) >1:
					continue

				in_endpoint.AddConnection(out_id)
				var connections_array = connections.get(in_id, [])
				connections_array.append(out_id)
				connections[in_id] = connections_array

func _setup_mutli_segment_connections() -> void:

	for segment in connected_segments:
		var in_endpoints = segment.endpoints.filter(func (_id): return incoming_endpoints.has(_id))

		var directions = SegmentHelper.get_segment_directions_from_segment(self, segment, connected_segments.filter(func (s): return s != segment))

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

			var ids = directions[direction].endpoints.filter(func (_id): return outgoing_endpoints.has(_id))
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

		if config_manager.PrintIntersectionSegmentsOrientations:
			print("Incoming Endpoints: ", in_endpoints)
			print("Forward Endpoints: ", ids_dict["forward"])
			print("Left Endpoints: ", ids_dict["left"])
			print("Right Endpoints: ", ids_dict["right"])
		

		var new_connections = lane_calculator.CalculateLaneConnections(in_endpoints_array, endpoints_dict["left"], endpoints_dict["forward"], endpoints_dict["right"])

		connections.merge(new_connections)
