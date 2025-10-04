extends RefCounted

class_name IntersectionManager

var LANE_STOPPER = preload("res://game-objects/network/net-node/lane-stopper/lane_stopper.tscn")

var network_manager: NetworkManager
var line_helper: LineHelper

var node: RoadNode

var handler: RefCounted

var crossing_vehicles: Dictionary = {}


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

		var stopper = LANE_STOPPER.instantiate() as LaneStopper

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

func register_crossing_vehicle(vehicle_id: int, from_endpoint_id: int, to_endpoint_id: int) -> void:
	var key = str(from_endpoint_id) + "-" + str(to_endpoint_id)

	if not crossing_vehicles.has(key):
		crossing_vehicles[key] = []
	
	if vehicle_id not in crossing_vehicles[key]:
		crossing_vehicles[key].append(vehicle_id)

func mark_vehicle_left(vehicle_id: int, from_endpoint_id: int, to_endpoint_id: int) -> void:
	var key = str(from_endpoint_id) + "-" + str(to_endpoint_id)

	if crossing_vehicles.has(key):
		crossing_vehicles[key].erase(vehicle_id)
		if crossing_vehicles[key].size() == 0:
			crossing_vehicles.erase(key)

func get_vehicles_crossing(from_endpoint_id: int, to_endpoint_id: int) -> Array:
	var key = str(from_endpoint_id) + "-" + str(to_endpoint_id)

	return crossing_vehicles.get(key, [])

func get_vehicles_crossing_count() -> int:
	var total = 0

	for key in crossing_vehicles.keys():
		total += crossing_vehicles[key].size()

	return total

func get_used_intersection_type() -> String:
	if handler:
		return handler.CLASS_NAME
	return "None"

func get_stoppers_list() -> Array:
	if handler:
		return handler.stoppers
	return []

func get_custom_data() -> Dictionary:
	if handler and handler.has_method("get_custom_data"):
		return handler.get_custom_data()
	return {}


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
