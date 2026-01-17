extends Node2D

class_name NetLane

var speed_limit_sign_scene = preload("res://game-objects/network/speed-limit-sign/speed_limit_sign.tscn")

const LANE_USAGE_EMA_ALPHA: float = 0.1

@onready var main_layer: Node2D = $MainLayer
@onready var trail: Path2D = $PathingTrail
@onready var debug_layer: Node2D = $DebugLayer
@onready var usage_indicator: Line2D = $UsageIndicator
@onready var usage_timer: Timer = $UsageTimer

var id: int
var segment: NetSegment
var data: NetLaneInfo
var offset: float = 0.0
var relation_id: int = -1
var lane_number: int = 0

var from_endpoint: int
var to_endpoint: int

var direction: Enums.Direction = Enums.Direction.UNSPECIFIED
var bus_lane_direction: Enums.BaseDirection = Enums.BaseDirection.UNSPECIFIED

var assigned_vehicles: Array

var lane_usage_ema: float = 0.0

var _constructed: bool = false
var _original_curve: Curve2D = null

@onready var map_pickable_area: Area2D = $PickableArea
var collision_shape: CollisionPolygon2D = null

@onready var game_manager = GDInjector.inject("GameManager") as GameManager
@onready var line_helper = GDInjector.inject("LineHelper") as LineHelper
@onready var segment_helper = GDInjector.inject("SegmentHelper") as SegmentHelper
@onready var network_manager = GDInjector.inject("NetworkManager") as NetworkManager
@onready var config_manager = GDInjector.inject("ConfigManager") as ConfigManager
@onready var vehicle_manager = GDInjector.inject("VehicleManager") as VehicleManager


func _ready() -> void:
	config_manager.DebugToggles.ToggleChanged.connect(_on_debug_toggles_changed)
	usage_timer.timeout.connect(_update_lane_usage)
	usage_timer.start()

	usage_indicator.visible = config_manager.DebugToggles.DrawLaneUsage

	vehicle_manager.vehicle_destroyed.connect(Callable(self, "_on_vehicle_destroyed"))

	if game_manager.get_game_mode() == Enums.GameMode.MAP_EDITOR:
		collision_shape = CollisionPolygon2D.new()
		collision_shape.build_mode = CollisionPolygon2D.BUILD_SEGMENTS
		map_pickable_area.add_child(collision_shape)


func setup(lane_id: int, parent_segment: NetSegment, lane_info: NetLaneInfo, lane_offset: float, _relation_id: int) -> void:
	id = lane_id
	segment = parent_segment
	data = lane_info
	offset = lane_offset
	relation_id = _relation_id


func update_trail_shape(curve: Curve2D) -> void:
	if curve == null or _constructed:
		return

	_constructed = true

	var new_curve = line_helper.get_curve_with_offset(curve, offset)
	_original_curve = new_curve

	var points = { }

	for node in segment.nodes:
		var point = _get_endpoint_for_node(node, new_curve)
		var road_side = segment_helper.get_road_side_at_endpoint(segment, point)
		var point_global = to_global(point)

		var is_outgoing = road_side == SegmentHelper.RoadSide.Left
		var is_at_path_start = segment.nodes[0] == node

		if is_outgoing and not is_at_path_start:
			new_curve = line_helper.reverse_curve(new_curve)
			_original_curve = new_curve # Update if reversed
			is_at_path_start = true

		lane_number = _calc_lane_number()

		var endpoint_id = network_manager.add_lane_endpoint(id, point_global, segment, node, is_outgoing, lane_number, is_at_path_start)

		if is_outgoing:
			from_endpoint = endpoint_id
			points[0] = point_global
		else:
			to_endpoint = endpoint_id
			points[1] = point_global

	new_curve = line_helper.trim_curve(new_curve, points[0], points[1])
	trail.curve = new_curve
	usage_indicator.points = new_curve.tessellate()
	_populate_main_layer()

	if collision_shape:
		collision_shape.polygon = line_helper.convert_curve_to_polygon(new_curve, NetworkConstants.LANE_WIDTH)

	_update_debug_layer()


func get_endpoint_by_id(endpoint_id: int) -> Variant:
	return network_manager.get_lane_endpoint(endpoint_id)


func get_endpoint_by_type(is_outgoing: bool) -> Variant:
	return network_manager.get_lane_endpoint(from_endpoint if is_outgoing else to_endpoint)


func get_curve() -> Curve2D:
	return trail.curve


func get_parent_segment() -> NetSegment:
	return segment


func get_segment_relation_id() -> int:
	return relation_id


func get_segment_relation() -> NetRelation:
	return segment.get_relation_of_lane(id)


func assign_vehicle(vehicle: Vehicle) -> void:
	if vehicle in assigned_vehicles:
		push_warning("Trying to assign vehicle ID %d to lane ID %d, but it is already assigned to this lane." % [vehicle.id, id])
		breakpoint
		return

	assigned_vehicles.append(vehicle)


func remove_vehicle(vehicle: Vehicle) -> void:
	if vehicle == null:
		push_warning("Trying to remove a null vehicle from lane ID %d." % id)
		return

	if vehicle not in assigned_vehicles:
		push_warning("Trying to remove vehicle ID %d from lane ID %d, but it is not assigned to this lane." % [vehicle.id, id])
		return

	assigned_vehicles.erase(vehicle)


func get_remaining_space() -> float:
	var last_vehicle = assigned_vehicles[assigned_vehicles.size() - 1] if assigned_vehicles.size() > 0 else null

	if last_vehicle and not is_instance_valid(last_vehicle):
		assigned_vehicles.pop_back()
		return get_remaining_space()

	return last_vehicle.main_path_follower.progress if last_vehicle else trail.curve.get_baked_length()


func get_first_vehicle() -> Vehicle:
	var first_vehicle = assigned_vehicles[0] if assigned_vehicles.size() > 0 else null

	if assigned_vehicles.size() > 0 and not is_instance_valid(first_vehicle):
		assigned_vehicles.pop_front()
		return get_first_vehicle()

	return assigned_vehicles[0] if assigned_vehicles.size() > 0 else null


func get_last_vehicle() -> Vehicle:
	if assigned_vehicles.size() == 0:
		return null

	var last_vehicle = assigned_vehicles[assigned_vehicles.size() - 1]
	if is_instance_valid(last_vehicle):
		return last_vehicle

	assigned_vehicles.pop_back()
	return get_last_vehicle()


func get_vehicle_count(only_waiting: bool = false) -> int:
	if not only_waiting:
		return assigned_vehicles.size()

	return assigned_vehicles.filter(func(v): return v.driver.get_state() == Driver.VehicleState.BLOCKED).size()


func get_vehicles_stats() -> Dictionary:
	var stats = {
		"total": 0,
		"waiting": 0,
		"moving": 0,
	}

	for vehicle in assigned_vehicles:
		if not is_instance_valid(vehicle):
			continue

		if vehicle.driver.get_state() == Driver.VehicleState.BLOCKED:
			stats["waiting"] += 1
		else:
			stats["moving"] += 1

	stats["total"] += stats["waiting"] + stats["moving"]

	return stats


func count_vehicles_within_distance(node_id: int, distance: float) -> int:
	var count = 0

	var is_node_at_start = get_endpoint_by_id(from_endpoint).NodeId == node_id

	for vehicle in assigned_vehicles:
		if not is_instance_valid(vehicle):
			continue

		var vehicle_distance = vehicle.main_path_follower.progress if is_node_at_start else trail.curve.get_baked_length() - vehicle.main_path_follower.progress
		if vehicle_distance <= distance:
			count += 1

	return count


func get_max_allowed_speed() -> float:
	return data.max_speed if data.max_speed > 0 else segment.data.max_speed if segment.data.max_speed > 0 else INF


func get_lane_usage() -> float:
	return lane_usage_ema


func get_length() -> float:
	if trail.curve == null:
		return 0.0

	return trail.curve.get_baked_length()


func reposition_endpoint(of_node: RoadNode, type: String) -> void:
	var endpoint_id = to_endpoint if type == "to" else from_endpoint
	var target_endpoint = network_manager.get_lane_endpoint(endpoint_id)

	if _original_curve == null:
		push_warning("No untrimmed curve stored for lane %d, cannot reposition endpoint" % id)
		return

	var point = _get_endpoint_for_node(of_node, _original_curve)

	target_endpoint.Position = point

	var other_endpoint = network_manager.get_lane_endpoint(to_endpoint if type == "from" else from_endpoint)

	var points = { }
	if type == "from":
		points[0] = point
		points[1] = other_endpoint.Position
	else:
		points[0] = other_endpoint.Position
		points[1] = point

	var trimmed = line_helper.trim_curve(_original_curve, points[0], points[1])
	trail.curve = trimmed
	usage_indicator.points = trimmed.tessellate()


func update_lane_direction(new_direction: Enums.Direction, allowed_vehicles: Dictionary) -> void:
	data.set_direction_from_enum(new_direction)
	data.set_allowed_vehicles(allowed_vehicles)


func update_speed_limit(new_speed_limit: int) -> void:
	data.max_speed = new_speed_limit

	_update_debug_layer()


func _update_lane_usage() -> void:
	var stats = get_vehicles_stats()

	var usage_ratio = stats["waiting"] / max(stats["total"], 1)

	lane_usage_ema = (LANE_USAGE_EMA_ALPHA * usage_ratio) + ((1.0 - LANE_USAGE_EMA_ALPHA) * lane_usage_ema)

	usage_indicator.default_color = _get_color_for_usage(lane_usage_ema)


func _get_color_for_usage(usage: float) -> Color:
	usage = clamp(usage, 0.0, 1.0)

	var low_usage = Color(0.9, 0.9, 0.9, 0.3)
	var full_usage = Color(1.0, 0.0, 0.0, 0.6)

	return low_usage.lerp(full_usage, usage)


func _get_endpoint_for_node(node: RoadNode, curve: Curve2D) -> Vector2:
	var polygon = node.get_intersection_polygon()

	if polygon.size() > 0:
		var points = line_helper.find_curve_polygon_intersections(curve.get_baked_points(), polygon)

		if points.size() > 0:
			return points[0]

	return Vector2.ZERO


func _update_debug_layer() -> void:
	for child in debug_layer.get_children():
		child.queue_free()

	if config_manager.DebugToggles.DrawLaneLayers:
		line_helper.draw_solid_line(trail.curve, debug_layer, 2.0, Color.PURPLE)

	if config_manager.DebugToggles.DrawLaneSpeedLimits:
		var speed_limit = get_max_allowed_speed()
		var mid_point = trail.curve.sample_baked(trail.curve.get_baked_length() / 2)

		var sign_instance = speed_limit_sign_scene.instantiate() as SpeedLimitSign
		sign_instance.position = to_local(mid_point)
		if speed_limit == INF:
			sign_instance.set_no_speed_limit()
		else:
			sign_instance.set_speed_limit(int(speed_limit))
		debug_layer.add_child(sign_instance)


func _populate_main_layer() -> void:
	for child in main_layer.get_children():
		child.queue_free()

	var chunks = line_helper.get_curve_chunks(trail.curve, NetworkConstants.LANE_WIDTH * 2)
	for chunk in chunks:
		var line = Line2D.new()
		line.width = NetworkConstants.LANE_WIDTH
		line.default_color = Color(0.2, 0.2, 0.2)
		line.points = chunk.get_baked_points()
		main_layer.add_child(line)


func _calc_lane_number() -> int:
	return abs(int(offset / NetworkConstants.LANE_WIDTH))


func _on_debug_toggles_changed(_name, _state) -> void:
	_update_debug_layer()

	usage_indicator.visible = config_manager.DebugToggles.DrawLaneUsage


func _on_vehicle_destroyed(vehicle_id: int, _vehicle_type: VehicleManager.VehicleType) -> void:
	for vehicle in assigned_vehicles:
		if not is_instance_valid(vehicle) or vehicle.id == vehicle_id:
			assigned_vehicles.erase(vehicle)
			break
