extends Node2D

class_name BaseBuilding

var DOT_SCENE = preload("res://game-objects/light/light.tscn")

enum BuildingType {
	RESIDENTIAL,
	COMMERCIAL,
	INDUSTRIAL
}

var id: int
var building_info: BuildingInfo
var segment: NetSegment
var target_relation_idx: int = -1
var type: BuildingType

var connections: Dictionary = {
	"in": {},
	"out": {}
}

@onready var debug_layer: Node2D = $DebugLayer

@onready var segment_helper: SegmentHelper = GDInjector.inject("SegmentHelper") as SegmentHelper
@onready var line_helper: LineHelper = GDInjector.inject("LineHelper") as LineHelper
@onready var config_manager: ConfigManager = GDInjector.inject("ConfigManager") as ConfigManager
@onready var buildings_manager: BuildingsManager = GDInjector.inject("BuildingsManager") as BuildingsManager

func _ready() -> void:
	config_manager.DebugToggles.ToggleChanged.connect(_on_debug_toggles_changed)

func setup(relation_id: int, _segment: NetSegment, _building_info: BuildingInfo) -> void:
	target_relation_idx = relation_id
	self.segment = _segment
	self.building_info = _building_info
	self.type = _building_info.Type

func setup_connections() -> void:
	var endpoints = _get_connection_endpoints()

	var supports_both_directions = segment.total_lanes == 2 and not segment.is_asymetric

	var edge_lanes = segment_helper.get_edge_lanes(segment)

	if edge_lanes.size() < 1:
		push_error("Failed to acquire edge lanes for building connection.")
		return

	for direction in connections.keys():
		var endpoint = endpoints[direction]
		var is_out_direction = (direction == "out")

		var same_relation_lane = edge_lanes[target_relation_idx]

		if not same_relation_lane:
			push_error("No lane found for building connection.")
			continue
		_create_single_connection(same_relation_lane, endpoint, is_out_direction, true)

		if supports_both_directions:
			var opposite_relation_idx = segment.get_other_relation_idx(target_relation_idx)
			var opposite_relation_lane = edge_lanes[opposite_relation_idx]

			if opposite_relation_lane == null:
				continue

			_create_single_connection(opposite_relation_lane, endpoint, is_out_direction, false)


	_update_debug_visuals()

func get_in_connections() -> Array:
	var in_conns = []
	for conn in connections["in"].values():
		in_conns.append(conn)
	return in_conns

func get_out_connections() -> Array:
	var out_conns = []
	for conn in connections["out"].values():
		out_conns.append(conn)
	return out_conns

func get_in_connection(endpoint_id: int) -> Dictionary:
	return connections["in"].get(endpoint_id, null)

func get_out_connection(endpoint_id: int) -> Dictionary:
	return connections["out"].get(endpoint_id, null)


func _create_single_connection(lane: NetLane, endpoint: Vector2, is_out_direction: bool, is_same_relation: bool) -> void:
	var connection = _create_connection(lane, endpoint, is_out_direction, is_same_relation)
	
	var direction_key = "out" if is_out_direction else "in"
	var endpoint_key = connection["next_endpoint"] if is_out_direction else connection["from_endpoint"]
	
	connections[direction_key][endpoint_key] = connection

func _create_connection(lane: NetLane, building_endpoint: Vector2, is_forward: bool, is_same_relation: bool) -> Dictionary:
	var lane_curve = lane.get_curve()
	var point_on_lane = lane_curve.get_closest_point(building_endpoint)
	var distance_along_lane = lane_curve.get_closest_offset(point_on_lane)
	var connection_distance = NetworkConstants.BUILDING_CONNECTION_OFFSET if is_forward else -NetworkConstants.BUILDING_CONNECTION_OFFSET
	var connection_point = lane_curve.sample_baked(distance_along_lane + connection_distance)

	var direction_multiplier = 1 if !is_forward else -1
	if not is_same_relation:
		direction_multiplier *= -1

	var connecting_curve: Curve2D
	if is_forward:
		connecting_curve = line_helper.calc_curve(to_local(building_endpoint), to_local(connection_point), NetworkConstants.BUILDING_CONNECTION_CURVATURE, direction_multiplier)
	else:
		connecting_curve = line_helper.calc_curve(to_local(connection_point), to_local(building_endpoint), NetworkConstants.BUILDING_CONNECTION_CURVATURE, -1 * direction_multiplier)

	var path = Path2D.new()
	path.curve = connecting_curve
	add_child(path)

	return {
		"lane": lane,
		"relation": "out" if is_forward else "in",
		"from": building_endpoint if is_forward else connection_point,
		"to": connection_point if is_forward else building_endpoint,
		"lane_point": connection_point,
		"path": path,
		"from_endpoint": lane.from_endpoint if not is_forward else -1,
		"next_endpoint": lane.to_endpoint if is_forward else -1
	}

func _update_debug_visuals() -> void:
	for child in debug_layer.get_children():
		child.queue_free()

	if not config_manager.DebugToggles.DrawBuildingConnections:
		return

	var endpoints = _get_connection_endpoints()
	for direction in connections.keys():
		var endpoint = endpoints[direction]

		var instance = DOT_SCENE.instantiate() as Light
		instance.position = debug_layer.to_local(endpoint)
		instance.inactive_color = Color(0.164, 0.392, 0.980)
		instance.radius = 4.0
		debug_layer.add_child(instance)

	var OUT_COLOR = Color(0.980, 0.392, 0.164)
	var IN_COLOR = Color(0.164, 0.980, 0.392)

	for direction in connections.keys():
		for related_endpoint in connections[direction].keys():
			var connection = connections[direction][related_endpoint]

			var point = DOT_SCENE.instantiate() as Light
			point.position = debug_layer.to_local(connection["lane_point"])
			point.inactive_color = OUT_COLOR if connection["relation"] == "out" else IN_COLOR
			point.radius = 2.0
			debug_layer.add_child(point)

			line_helper.draw_solid_line(connection["path"].curve, debug_layer, 2.0, OUT_COLOR if connection["relation"] == "out" else IN_COLOR)
		

func _get_connection_endpoints()-> Dictionary:
	return {
		"in": to_global(Vector2(0, 11)),
		"out": to_global(Vector2(0, 11))
	}

func _on_debug_toggles_changed(toggle_name: String, _value: bool) -> void:
	if toggle_name == "DrawBuildingConnections":
		_update_debug_visuals()
