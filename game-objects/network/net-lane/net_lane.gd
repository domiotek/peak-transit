extends Node2D
class_name NetLane

var speed_limit_sign_scene = preload("res://game-objects/network/speed-limit-sign/speed_limit_sign.tscn")

var LANE_USAGE_EMA_ALPHA: float = 0.1

@onready var trail: Path2D = $PathingTrail
@onready var debug_layer: Node2D = $DebugLayer
@onready var usage_indicator: Line2D = $UsageIndicator
@onready var usage_timer: Timer = $UsageTimer

var id: int
var segment: NetSegment
var data: NetLaneInfo
var offset: float = 0.0
var relation_id: int = -1

var from_endpoint: int
var to_endpoint: int

var direction: Enums.Direction = Enums.Direction.BACKWARD

var assigned_vehicles: Array

var lane_usage_ema: float = 0.0

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


func setup(lane_id: int, parent_segment: NetSegment, lane_info: NetLaneInfo, lane_offset: float, _relation_id: int) -> void:
	id = lane_id
	segment = parent_segment
	data = lane_info
	offset = lane_offset
	relation_id = _relation_id

func update_trail_shape(curve: Curve2D) -> void:
	if curve == null:
		return

	var new_curve = line_helper.get_curve_with_offset(curve, offset)
	var points = {}

	for node in segment.nodes:
		var point = _get_endpoint_for_node(node, new_curve)
		var road_side = segment_helper.get_road_side_at_endpoint(segment, point)
		var point_global = to_global(point)

		var is_outgoing = road_side == SegmentHelper.RoadSide.Left;
		var is_at_path_start = segment.nodes[0] == node

		if is_outgoing and not is_at_path_start:
			new_curve = line_helper.reverse_curve(new_curve)
			is_at_path_start = true

		var endpoint_id = network_manager.add_lane_endpoint(id, point_global, segment, node, is_outgoing, _calc_lane_number(), is_at_path_start)

		if is_outgoing:
			from_endpoint = endpoint_id
			points[0] = point_global
		else:
			to_endpoint = endpoint_id
			points[1] = point_global

	new_curve = line_helper.trim_curve(new_curve, points[0], points[1])
	trail.curve = new_curve
	usage_indicator.points = new_curve.tessellate()

	_update_debug_layer()

func get_endpoint_by_id(endpoint_id: int) -> NetLaneEndpoint:
	return network_manager.get_lane_endpoint(endpoint_id)

func get_endpoint_by_type(is_outgoing: bool) -> NetLaneEndpoint:
	return network_manager.get_lane_endpoint(from_endpoint if is_outgoing else to_endpoint)

func get_curve() -> Curve2D:
	return trail.curve

func assign_vehicle(vehicle: Vehicle) -> void:
	assigned_vehicles.append(vehicle)

func remove_vehicle(vehicle: Vehicle) -> void:
	assigned_vehicles.erase(vehicle)

func get_remaining_space() -> float:
	var last_vehicle = assigned_vehicles[assigned_vehicles.size() - 1] if assigned_vehicles.size() > 0  else null

	if last_vehicle and not is_instance_valid(last_vehicle):
		assigned_vehicles.pop_back()
		return get_remaining_space()

	return last_vehicle.path_follower.progress if last_vehicle else trail.curve.get_baked_length()

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
	else:
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
		"moving": 0
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

	var is_node_at_start = segment.nodes[0].id == node_id

	for vehicle in assigned_vehicles:
		if not is_instance_valid(vehicle):
			continue

		var vehicle_distance = vehicle.path_follower.progress if is_node_at_start else trail.curve.get_baked_length() - vehicle.path_follower.progress
		if vehicle_distance <= distance:
			count += 1

	return count

func get_max_allowed_speed() -> float:
	return data.MaxSpeed if data.MaxSpeed > 0 else segment.data.MaxSpeed if segment.data.MaxSpeed > 0 else INF

func get_lane_usage() -> float:
	return lane_usage_ema

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


func _calc_lane_number() -> int:
	return abs(int(offset / NetworkConstants.LANE_WIDTH))


func _on_debug_toggles_changed(_name, _state) -> void:
	_update_debug_layer()

	usage_indicator.visible = config_manager.DebugToggles.DrawLaneUsage

func _on_vehicle_destroyed(vehicle_id: int) -> void:
	for vehicle in assigned_vehicles:
		if not is_instance_valid(vehicle) or vehicle.id == vehicle_id:
			assigned_vehicles.erase(vehicle)
			break
