extends RefCounted

class_name IntersectionManager

var NullIntersectionHandlerModule = load("res://services/managers/intersections/handlers/null_handler.gd")
var TrafficLightsIntersectionHandlerModule = load("res://services/managers/intersections/handlers/traffic_lights_handler.gd")


var network_manager: NetworkManager
var line_helper: LineHelper

var node: RoadNode

var handler: RefCounted


func setup_intersection(assigned_node: RoadNode) -> void:
	if not assigned_node:
		push_error("Invalid node provided to setup_intersection")
		return

	if node:
		push_error("IntersectionManager is already assigned to a node")
		return

	node = assigned_node

	network_manager = GDInjector.inject("NetworkManager") as NetworkManager
	line_helper = GDInjector.inject("LineHelper") as LineHelper

	var stoppers = []

	for endpoint_id in node.incoming_endpoints:
		var endpoint = network_manager.get_lane_endpoint(endpoint_id)

		var curve = network_manager.get_segment(endpoint.SegmentId).lanes[endpoint.LaneId].trail.curve

		var scene = load("res://game-objects/network/net-node/lane-stopper/lane_stopper.tscn")
		var stopper = scene.instantiate() as LaneStopper

		stopper.endpoint = endpoint
		stopper.position = node.to_local(endpoint.Position)
		stopper.rotation = line_helper.rotate_along_curve(curve, endpoint.Position)
		node.pathing_layer.add_child(stopper)
		
		stopper.set_active(true)

		stoppers.append(stopper)

	handler = _choose_intersection_handler()
	handler.setup(node, stoppers)

func process_tick(delta: float) -> void:
	if handler:
		handler.process_tick(delta)


func _choose_intersection_handler() -> RefCounted:
	if node.connected_segments.size() <= 2:
		return NullIntersectionHandler.new()
	else:
		match node.definition.IntersectionType:
			Enums.IntersectionType.Default:
				return DefaultIntersectionHandler.new()
			Enums.IntersectionType.TrafficLights:
				return TrafficLightsIntersectionHandler.new()
		return TrafficLightsIntersectionHandler.new()

func get_used_intersection_type() -> String:
	if handler:
		return handler.CLASS_NAME
	return "None"
