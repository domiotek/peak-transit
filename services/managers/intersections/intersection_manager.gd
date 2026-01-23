extends RefCounted

class_name IntersectionManager

const LaneStopperScene = preload("res://game-objects/network/net-node/lane-stopper/lane_stopper.tscn")

enum IntersectionHandlerType {
	NULL = -1,
	DEFAULT = Enums.IntersectionType.DEFAULT,
	TRAFFIC_LIGHTS = Enums.IntersectionType.TRAFFIC_LIGHTS,
}

var network_manager: NetworkManager
var line_helper: LineHelper

var node: RoadNode

var handler: RefCounted
var _handler_type: IntersectionHandlerType = IntersectionHandlerType.NULL

var crossing_vehicles: Dictionary = { }


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

		var stopper = LaneStopperScene.instantiate() as LaneStopper

		stopper.endpoint = endpoint
		stopper.position = node.to_local(endpoint.Position)
		stopper.rotation = line_helper.rotate_along_curve(curve, endpoint.Position)
		node.pathing_layer.add_child(stopper)

		stopper.set_active(true)

		stoppers.append(stopper)

	handler = _choose_intersection_handler()
	handler.setup(node, stoppers)


func dispose_intersection() -> void:
	if not node:
		return

	if handler:
		handler.dispose()

	handler = null
	node = null
	crossing_vehicles.clear()


func switch_intersection_type(new_type: Enums.IntersectionType) -> void:
	if not node:
		push_error("No node assigned to IntersectionManager")
		return

	var stoppers = handler.stoppers if handler else []

	if handler:
		handler.dispose()
		handler = null

	handler = _choose_intersection_handler(new_type as IntersectionHandlerType)
	handler.setup(node, stoppers)


func get_intersection_handler_type() -> IntersectionHandlerType:
	return _handler_type


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
	return { }


func _choose_intersection_handler(override: IntersectionHandlerType = IntersectionHandlerType.NULL) -> RefCounted:
	if node.connected_segments.size() <= 2:
		_handler_type = IntersectionHandlerType.NULL
		return NullIntersectionHandler.new()

	var intersection_type = override if override != IntersectionHandlerType.NULL else (node.definition.intersection_type as IntersectionHandlerType)

	match intersection_type:
		Enums.IntersectionType.DEFAULT:
			_handler_type = IntersectionHandlerType.DEFAULT
			return DefaultIntersectionHandler.new()
		Enums.IntersectionType.TRAFFIC_LIGHTS:
			_handler_type = IntersectionHandlerType.TRAFFIC_LIGHTS
			return TrafficLightsIntersectionHandler.new()
	return TrafficLightsIntersectionHandler.new()
