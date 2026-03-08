extends Node2D

class_name BaseBuilding

const LightScene = preload("res://game-objects/light/light.tscn")
const BUILDING_ENTERING_CHECK_INTERVAL_SEC: float = 0.2

var id: int
var building_info: BuildingInfo
var segment: NetSegment
var target_relation_idx: int = -1
var target_relation_dest_endpoint_id: int = -1
var type: BuildingInfo.BuildingType

var is_setup: bool = false

var connections: BuildingConnectionInfo.BuildingConnectionCollection = BuildingConnectionInfo.BuildingConnectionCollection.new()

var debug_visuals_enabled: bool = false

var vehicle_leaving: Vehicle = null
var vehicles_entering: Array[Vehicle] = []

@onready var debug_layer: Node2D = $DebugLayer

var segment_helper: SegmentHelper = GDInjector.inject("SegmentHelper") as SegmentHelper
var line_helper: LineHelper = GDInjector.inject("LineHelper") as LineHelper
var config_manager: ConfigManager = GDInjector.inject("ConfigManager") as ConfigManager
var buildings_manager: BuildingsManager = GDInjector.inject("BuildingsManager") as BuildingsManager


func _ready() -> void:
	config_manager.DebugToggles.ToggleChanged.connect(_on_debug_toggles_changed)


func setup(relation_id: int, _segment: NetSegment, _building_info: BuildingInfo) -> void:
	target_relation_idx = relation_id
	self.segment = _segment
	self.building_info = _building_info
	self.type = _building_info.type


func setup_connections() -> void:
	var endpoints := _get_connection_endpoints()

	var supports_both_directions := segment.get_lane_count() == 2 and not segment.is_asymetric

	var edge_lanes := segment_helper.get_edge_lanes(segment)

	if edge_lanes.size() < 1:
		push_error("Failed to acquire edge lanes for building connection.")
		return

	for direction in BuildingConnectionInfo.BUILDING_CONNECTION_TYPES:
		var endpoint := endpoints[direction]
		var is_out_direction := (direction == BuildingConnectionInfo.BuildingConnectionType.OUT) as bool

		var same_relation_lane = edge_lanes[target_relation_idx]

		if not same_relation_lane:
			push_error("No lane found for building connection.")
			continue
		_create_single_connection(same_relation_lane, endpoint, is_out_direction, true)

		if supports_both_directions:
			var opposite_relation_idx := segment.get_other_relation_idx(target_relation_idx)
			var opposite_relation_lane = edge_lanes[opposite_relation_idx]

			if opposite_relation_lane == null:
				continue

			_create_single_connection(opposite_relation_lane, endpoint, is_out_direction, false)

	call_deferred("_update_debug_visuals")
	is_setup = true


func get_in_connections() -> Array[BuildingConnectionInfo]:
	return connections.get_collection_by_key(BuildingConnectionInfo.BuildingConnectionType.IN).values().duplicate() as Array[BuildingConnectionInfo]


func get_out_connections() -> Array[BuildingConnectionInfo]:
	return connections.get_collection_by_key(BuildingConnectionInfo.BuildingConnectionType.OUT).values().duplicate() as Array[BuildingConnectionInfo]


func get_in_connection(endpoint_id: int) -> BuildingConnectionInfo:
	return connections.find_connection(false, endpoint_id)


func get_out_connection(endpoint_id: int) -> BuildingConnectionInfo:
	return connections.find_connection(true, endpoint_id)


func get_out_connection_from_in_endpoint(endpoint_id: int) -> BuildingConnectionInfo:
	var in_connection := get_in_connection(endpoint_id)
	if in_connection == null:
		return null

	var lane := in_connection.lane
	var other_endpoint = lane.get_endpoint_by_type(false)

	return get_out_connection(other_endpoint.Id)


func are_debug_visuals_enabled() -> bool:
	return debug_visuals_enabled


func supports_routed_leaving() -> bool:
	return false


static func get_collision_polygon() -> PackedVector2Array:
	return PackedVector2Array()


func _create_single_connection(lane: NetLane, endpoint: Vector2, is_out_direction: bool, is_same_relation: bool) -> void:
	var connection := _create_connection(lane, endpoint, is_out_direction, is_same_relation)
	var endpoint_key := connection.next_endpoint if is_out_direction else connection.from_endpoint

	if is_out_direction and is_same_relation:
		target_relation_dest_endpoint_id = connection.next_endpoint

	connections.add_connection(is_out_direction, endpoint_key, connection)


func _create_connection(lane: NetLane, building_endpoint: Vector2, is_forward: bool, is_same_relation: bool) -> BuildingConnectionInfo:
	var lane_curve = lane.get_curve()
	var point_on_lane = lane_curve.get_closest_point(building_endpoint)
	var distance_along_lane = lane_curve.get_closest_offset(point_on_lane)
	var connection_distance = BuildingConstants.BUILDING_CONNECTION_OFFSET if is_forward else -BuildingConstants.BUILDING_CONNECTION_OFFSET
	var connection_point = lane_curve.sample_baked(distance_along_lane + connection_distance)

	var direction_multiplier = 1 if !is_forward else -1

	var connecting_curve: Curve2D
	if not is_same_relation:
		if is_forward:
			connecting_curve = line_helper.calc_curve_asymmetric(
				to_local(building_endpoint),
				to_local(connection_point),
				0,
				BuildingConstants.BUILDING_CONNECTION_CURVATURE,
				-1 * direction_multiplier,
			)
		else:
			connecting_curve = line_helper.calc_curve_asymmetric(
				to_local(connection_point),
				to_local(building_endpoint),
				BuildingConstants.BUILDING_CONNECTION_CURVATURE,
				0,
				direction_multiplier,
			)
	else:
		if is_forward:
			connecting_curve = line_helper.calc_curve(
				to_local(building_endpoint),
				to_local(connection_point),
				BuildingConstants.BUILDING_CONNECTION_CURVATURE,
				direction_multiplier,
			)
		else:
			connecting_curve = line_helper.calc_curve(
				to_local(connection_point),
				to_local(building_endpoint),
				BuildingConstants.BUILDING_CONNECTION_CURVATURE,
				-1 * direction_multiplier,
			)

	var path = Path2D.new()
	path.curve = connecting_curve
	add_child(path)

	return BuildingConnectionInfo.create(
		lane,
		path,
		is_forward,
		building_endpoint,
		connection_point,
		is_same_relation,
	)


func _update_debug_visuals() -> void:
	for child in debug_layer.get_children():
		child.queue_free()

	if not config_manager.DebugToggles.DrawBuildingConnections:
		return

	const OUT_COLOR = Color(0.980, 0.392, 0.164)
	const IN_COLOR = Color(0.164, 0.980, 0.392)

	var endpoints := _get_connection_endpoints()
	for direction in BuildingConnectionInfo.BUILDING_CONNECTION_TYPES:
		var endpoint := endpoints[direction]

		var instance := LightScene.instantiate() as Light
		instance.position = debug_layer.to_local(endpoint)
		instance.inactive_color = Color(0.164, 0.392, 0.980)
		instance.radius = 4.0
		debug_layer.add_child(instance)

		for connection in (connections.get_collection_by_key(direction).values()) as Array[BuildingConnectionInfo]:
			var point := LightScene.instantiate() as Light
			point.position = debug_layer.to_local(connection.lane_point)
			point.inactive_color = OUT_COLOR if connection.is_outgoing else IN_COLOR
			point.radius = 2.0
			debug_layer.add_child(point)

			line_helper.draw_solid_line(connection.path.curve, debug_layer, 2.0, OUT_COLOR if connection.is_outgoing else IN_COLOR)


func _get_connection_endpoints() -> Dictionary[BuildingConnectionInfo.BuildingConnectionType, Vector2]:
	return {
		BuildingConnectionInfo.BuildingConnectionType.IN: to_global(Vector2(0, 11)),
		BuildingConnectionInfo.BuildingConnectionType.OUT: to_global(Vector2(0, 11)),
	}


func _on_debug_toggles_changed(_toggle_name: String, _value: bool) -> void:
	_update_debug_visuals()
