extends Node2D

class_name BaseBuilding

var DOT_SCENE = preload("res://game-objects/light/light.tscn")


var building_info: BuildingInfo
var segment: NetSegment
var target_relation_idx: int = -1

@onready var debug_layer: Node2D = $DebugLayer

@onready var segment_helper: SegmentHelper = GDInjector.inject("SegmentHelper") as SegmentHelper
@onready var line_helper: LineHelper = GDInjector.inject("LineHelper") as LineHelper
@onready var config_manager: ConfigManager = GDInjector.inject("ConfigManager") as ConfigManager


var connections: Dictionary = {
	"in": {},
	"out": {}
}

func _ready() -> void:
	config_manager.DebugToggles.ToggleChanged.connect(_on_debug_toggles_changed)

func setup(relation_id: int, _segment: NetSegment, _building_info: BuildingInfo) -> void:
	target_relation_idx = relation_id
	self.segment = _segment
	self.building_info = _building_info

func setup_connections() -> void:
	var endpoints = _get_connection_endpoints()

	var supports_both_directions = segment.total_lanes == 2 and not segment.is_asymetric

	var edge_lanes = segment_helper.get_edge_lanes(segment)

	if edge_lanes.size() < 1:
		push_error("Failed to acquire edge lanes for building connection.")
		return

	for direction in connections.keys():
		var endpoint = endpoints[direction]

		var same_relation_lane = edge_lanes[target_relation_idx]

		if not same_relation_lane:
			push_error("No lane found for building connection.")
			continue
		_create_connections(same_relation_lane, endpoint, true)

		if supports_both_directions:
			var opposite_relation_idx = segment.get_other_relation_idx(target_relation_idx)
			var opposite_relation_lane = edge_lanes[opposite_relation_idx]

			if opposite_relation_lane == null:
				continue

			_create_connections(opposite_relation_lane, endpoint, false)


	_update_debug_visuals()


func _create_connections(lane: NetLane, endpoint: Vector2, is_same_relation: bool) -> void:
	var in_connection = _create_connection(lane, endpoint, false, is_same_relation)
	var out_connection = _create_connection(lane, endpoint, true, is_same_relation)

	connections["in"][in_connection["from_endpoint"]] = in_connection
	connections["out"][out_connection["next_endpoint"]] = out_connection

func _create_connection(lane: NetLane, building_endpoint: Vector2, is_forward: bool, is_same_relation: bool) -> Dictionary:
	var lane_curve = lane.get_curve()
	var point_on_lane = lane_curve.get_closest_point(building_endpoint)
	var distance_along_lane = lane_curve.get_closest_offset(point_on_lane)
	var connection_distance = NetworkConstants.BUILDING_CONNECTION_OFFSET if is_forward else -NetworkConstants.BUILDING_CONNECTION_OFFSET
	var connection_point = lane_curve.sample_baked(distance_along_lane + connection_distance)

	var direction_multiplier = 1 if !is_forward else -1
	if not is_same_relation:
		direction_multiplier *= -1

	var connecting_curve = line_helper.calc_curve(to_local(building_endpoint), to_local(connection_point), NetworkConstants.BUILDING_CONNECTION_CURVATURE, direction_multiplier)

	var path = Path2D.new()
	path.curve = connecting_curve
	add_child(path)

	return {
		"lane": lane,
		"relation": "out" if is_forward else "in",
		"from": to_global(building_endpoint) if is_forward else connection_point,
		"to": connection_point if is_forward else to_global(building_endpoint),
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
