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
var vehicle_manager: VehicleManager

var node: RoadNode

var handler: RefCounted
var _handler_type: IntersectionHandlerType = IntersectionHandlerType.NULL

var crossing_vehicles: Dictionary = { }
var _crossing_vehicles_total: int = 0
var _reserved_entry_space_by_endpoint: Dictionary[int, float] = { }
var _entry_space_reservation_frame: int = -1


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
	vehicle_manager = GDInjector.inject("VehicleManager") as VehicleManager

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
	_crossing_vehicles_total = 0


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
	_ensure_entry_space_reservation_frame()
	if handler:
		handler.process_tick(delta)


func register_crossing_vehicle(vehicle_id: int, from_endpoint_id: int, to_endpoint_id: int) -> void:
	var key = _compose_crossing_key(from_endpoint_id, to_endpoint_id)

	if not crossing_vehicles.has(key):
		crossing_vehicles[key] = { }

	var crossing_set = crossing_vehicles[key] as Dictionary
	if not crossing_set.has(vehicle_id):
		crossing_set[vehicle_id] = true
		_crossing_vehicles_total += 1


func mark_vehicle_left(vehicle_id: int, from_endpoint_id: int, to_endpoint_id: int) -> void:
	var key = _compose_crossing_key(from_endpoint_id, to_endpoint_id)

	if crossing_vehicles.has(key):
		var crossing_set = crossing_vehicles[key] as Dictionary
		if crossing_set.erase(vehicle_id):
			_crossing_vehicles_total = max(0, _crossing_vehicles_total - 1)

		if crossing_set.size() == 0:
			crossing_vehicles.erase(key)


func get_vehicles_crossing(from_endpoint_id: int, to_endpoint_id: int) -> Array:
	var key = _compose_crossing_key(from_endpoint_id, to_endpoint_id)
	var crossing_set = _get_pruned_crossing_set(key)
	if crossing_set.size() == 0:
		return []

	return crossing_set.keys()


func has_vehicles_crossing(from_endpoint_id: int, to_endpoint_id: int) -> bool:
	var key = _compose_crossing_key(from_endpoint_id, to_endpoint_id)
	var crossing_set = _get_pruned_crossing_set(key)
	if crossing_set.size() == 0:
		return false

	return true


func get_vehicles_crossing_count() -> int:
	return _crossing_vehicles_total


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

func reset_state() -> void:
	if handler and handler.has_method("reset_state"):
		handler.reset_state()


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


func _compose_crossing_key(from_endpoint_id: int, to_endpoint_id: int) -> int:
	return (from_endpoint_id << 32) | (to_endpoint_id & 0xFFFFFFFF)


func _get_pruned_crossing_set(key: int) -> Dictionary:
	if not crossing_vehicles.has(key):
		return { }

	var crossing_set = crossing_vehicles[key] as Dictionary
	var removed_count = 0

	for vehicle_id in crossing_set.keys():
		if vehicle_manager and not vehicle_manager.vehicle_exists(vehicle_id):
			crossing_set.erase(vehicle_id)
			removed_count += 1

	if removed_count > 0:
		_crossing_vehicles_total = max(0, _crossing_vehicles_total - removed_count)

	if crossing_set.size() == 0:
		crossing_vehicles.erase(key)
		return { }

	return crossing_set


func try_reserve_target_lane_space(target_endpoint_id: int, required_space: float) -> bool:
	_ensure_entry_space_reservation_frame()

	var target_endpoint = network_manager.get_lane_endpoint(target_endpoint_id)
	if not target_endpoint:
		return false

	var target_lane = network_manager.get_segment(target_endpoint.SegmentId).get_lane(target_endpoint.LaneId)
	if not target_lane:
		return false

	var available_space: float = target_lane.get_remaining_space()
	var reserved_space: float = _reserved_entry_space_by_endpoint.get(target_endpoint_id, 0.0)

	if available_space - reserved_space < required_space:
		return false

	_reserved_entry_space_by_endpoint[target_endpoint_id] = reserved_space + required_space
	return true


func _ensure_entry_space_reservation_frame() -> void:
	var frame = Engine.get_physics_frames()
	if _entry_space_reservation_frame == frame:
		return

	_entry_space_reservation_frame = frame
	_reserved_entry_space_by_endpoint.clear()
