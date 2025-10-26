extends Node2D
class_name NetSegment

var NET_LANE = preload("res://game-objects/network/net-lane/net_lane.tscn")
var BUILDING = preload("res://game-objects/buildings/base-building/base-building.tscn")

@onready var config_manager = GDInjector.inject("ConfigManager") as ConfigManager

var id: int
var data: NetSegmentInfo
var nodes: Array[RoadNode] = []
var relations: Array[NetRelation] = []
var lanes: Array[NetLane] = []
var curve_shape: Curve2D
var main_layer_curve: Curve2D
var main_layer_offset: float = 0.0
var left_edge_curve: Curve2D
var right_edge_curve: Curve2D
var total_lanes: int = 0
var is_asymetric: bool = false
var max_lanes_relation_idx: int = -1

var buildings: Array[int] = []

var endpoints: Array[int] = []
var endpoints_mappings: Dictionary[int, int] = {}

@onready var main_road_layer: Line2D = $MainLayer
@onready var debug_layer: Node2D = $DebugLayer
@onready var markings_layer: Node2D = $MarkingsLayer

var line_helper: LineHelper
var buildings_manager: BuildingsManager

func _ready() -> void:		
	var img = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.2, 0.2, 0.2, 1.0))
	
	main_road_layer.texture = ImageTexture.create_from_image(img)
	config_manager.DebugToggles.ToggleChanged.connect(_on_debug_toggles_changed)
	

func setup(start_node: RoadNode, target_node: RoadNode, segment_info: NetSegmentInfo) -> void:
	line_helper = GDInjector.inject("LineHelper") as LineHelper
	buildings_manager = GDInjector.inject("BuildingsManager") as BuildingsManager
	data = segment_info

	nodes.append(start_node)
	nodes.append(target_node)

	curve_shape = line_helper.calc_curve(
		to_local(start_node.global_position), 
		to_local(target_node.global_position), 
		segment_info.CurveStrength, 
		segment_info.CurveDirection)
		

func add_connection(start_node: RoadNode, target_node: RoadNode, connection_info: NetConnectionInfo) -> void:
	if !nodes.has(start_node) and !nodes.has(target_node):
		push_error("Cannot add connection: Nodes not part of this segment.")
		return

	if relations.size() == 2:
		push_error("Cannot add connection: Segment already has two relations.")
		return

	var relation = NetRelation.new()
	var relation_id = relations.size()

	relation.StartNode = start_node
	relation.EndNode = target_node
	relation.ConnectionInfo = connection_info

	relations.append(relation)

	var starts_from_end = relation.StartNode == nodes[1]
	
	for i in range(relation.ConnectionInfo.Lanes.size()):
		var lane_info = relation.ConnectionInfo.Lanes[i]
		var offset;
		if starts_from_end:
			offset = (i + 1) * -NetworkConstants.LANE_WIDTH + NetworkConstants.LANE_WIDTH / 2
		else:
			offset = (i + 1) * NetworkConstants.LANE_WIDTH - NetworkConstants.LANE_WIDTH / 2

		var lane = NET_LANE.instantiate()
		lane.setup(lanes.size(), self, lane_info, offset, relations.size() - 1)
		add_child(lane)
		lanes.append(lane)

	for i in range(relation.ConnectionInfo.Buildings.size()):
		var building_info = relation.ConnectionInfo.Buildings[i]
		var curve_offset = building_info.OffsetPosition
		var horizontal_offset;

		if starts_from_end:
			horizontal_offset = ((relation.ConnectionInfo.Lanes.size()) * -NetworkConstants.LANE_WIDTH + NetworkConstants.LANE_WIDTH / 2) - BuildingConstants.BUILDING_ROAD_OFFSET
			curve_offset = curve_shape.get_baked_length() - curve_offset
		else:
			horizontal_offset = ((relation.ConnectionInfo.Lanes.size()) * NetworkConstants.LANE_WIDTH - NetworkConstants.LANE_WIDTH / 2) + BuildingConstants.BUILDING_ROAD_OFFSET

		var building = buildings_manager.create_spawner_building(building_info)
		building.setup(relation_id, self, building_info)
		var point = line_helper.get_point_along_curve(curve_shape, curve_offset, horizontal_offset)

		building.position = point
		building.rotation = line_helper.rotate_along_curve(curve_shape, point)

		if not starts_from_end:
			building.rotation += PI

		buildings.append(building.id)
		add_child(building)

		


func update_visuals() -> void:
	if not curve_shape:
		return
	
	if not main_road_layer:
		return

	var max_lanes = 0

	for i in range(relations.size()):
		var connection = relations[i].ConnectionInfo
		if connection.Lanes.size() > max_lanes:
			max_lanes = connection.Lanes.size()
			max_lanes_relation_idx = i

		total_lanes += connection.Lanes.size()

	is_asymetric = max_lanes > total_lanes / float(relations.size())

	main_layer_curve = curve_shape

	if is_asymetric:
		var offset_direction = -1 if relations[max_lanes_relation_idx].StartNode == nodes[1] else 1
		var lane_diff = max_lanes - (total_lanes - max_lanes)
		main_layer_offset =  NetworkConstants.LANE_WIDTH / 2 * lane_diff * offset_direction
		main_layer_curve = line_helper.get_curve_with_offset(curve_shape, main_layer_offset)

	left_edge_curve = line_helper.get_curve_with_offset(main_layer_curve, total_lanes * -NetworkConstants.LANE_WIDTH / 2)
	right_edge_curve = line_helper.get_curve_with_offset(main_layer_curve, total_lanes * NetworkConstants.LANE_WIDTH / 2)

	main_road_layer.points = main_layer_curve.get_baked_points()
	main_road_layer.width = total_lanes * NetworkConstants.LANE_WIDTH

	_update_markings_layer()
	_update_debug_layer()

func late_update_visuals() -> void:
	_update_lanes_pathing_shape()
		
func get_lane(lane_id: int) -> NetLane:
	if lane_id < 0 or lane_id >= lanes.size():
		push_error("Invalid lane ID: " + str(lane_id))
		return null
	return lanes.filter(func(lane): return lane.id == lane_id)[0]

func get_other_node_id(node_id: int) -> int:
	if nodes[0].id == node_id:
		return nodes[1].id
	elif nodes[1].id == node_id:
		return nodes[0].id
	else:
		push_error("Node ID not part of this segment.")
		return -1

func get_relation_of_lane(lane_id: int) -> NetRelation:
	var lane = get_lane(lane_id)

	var relation_id = lane.relation_id
	if relation_id < 0 or relation_id >= relations.size():
		push_error("Invalid relation ID for lane: " + str(lane_id))
		return null

	return relations[relation_id]

func get_other_relation_idx(relation_idx: int) -> int:
	if relation_idx < 0 or relation_idx >= relations.size():
		push_error("Invalid relation index: " + str(relation_idx))
		return -1
	return 1 - relation_idx

func _update_lanes_pathing_shape() -> void:
	for lane in lanes:
		lane.update_trail_shape(curve_shape)
		endpoints_mappings[lane.from_endpoint] = lane.to_endpoint

func _update_markings_layer() -> void:
	for child in markings_layer.get_children():
		child.queue_free()

	if not curve_shape:
		return

	if relations.size() == 2:
		if total_lanes == 2:
			line_helper.draw_dash_line(curve_shape, markings_layer)
		else:
			line_helper.draw_solid_line(curve_shape, markings_layer)

	for relation in relations:
		var starts_from_end = relation.StartNode == nodes[1]
		var midline_side = -1 if starts_from_end else 1

		for i in range(relation.ConnectionInfo.Lanes.size() - 1):
			var offset = (i + 1) * NetworkConstants.LANE_WIDTH * midline_side
			var path = line_helper.get_curve_with_offset(curve_shape, offset)
			line_helper.draw_dash_line(path, markings_layer)

func _update_debug_layer() -> void:
	for child in debug_layer.get_children():
		child.queue_free()

	if not config_manager.DebugToggles.DrawNetworkConnections:
		return

	if not curve_shape:
		return

	line_helper.draw_solid_line(left_edge_curve, debug_layer, 2.0, Color.GREEN)
	line_helper.draw_solid_line(right_edge_curve, debug_layer, 2.0, Color.IVORY)

	var points = curve_shape.tessellate(5, 4.0)
	for j in range(1, points.size()):
		var line = Line2D.new()
		line.default_color = Color.BLUE
		line.width = 2.0
		line.antialiased = true
		line.points = [points[j-1], points[j]]
		debug_layer.add_child(line)
	
	var curve_length = curve_shape.get_baked_length()
	for i in range(relations.size()):
		var relation = relations[i]		
		var arrow_direction_vector
		var arrow_pos
		
		var starts_from_end = relation.StartNode == nodes[1]
		
		var t_arrow = 0.1 if starts_from_end else 0.9
		arrow_pos = curve_shape.sample_baked(curve_length * t_arrow)
		
		var pos_before = curve_shape.sample_baked(max(curve_length * t_arrow - 5.0, 0.0))
		arrow_direction_vector = (arrow_pos - pos_before).normalized()
		
		var arrow_size = 8.0
		var arrow_width = 5.0
		
		arrow_direction_vector = -arrow_direction_vector if starts_from_end else arrow_direction_vector
		
		var arrow_perpendicular = Vector2(-arrow_direction_vector.y, arrow_direction_vector.x).normalized()
		var arrow_back = arrow_pos - arrow_direction_vector * arrow_size
		var arrow_right = arrow_back + arrow_perpendicular * arrow_width
		var arrow_left = arrow_back - arrow_perpendicular * arrow_width
		
		var arrow_polygon = Polygon2D.new()
		arrow_polygon.color = Color.RED
		arrow_polygon.polygon = PackedVector2Array([arrow_pos, arrow_right, arrow_left])
		debug_layer.add_child(arrow_polygon)

func _on_debug_toggles_changed(_name, _state) -> void:
	_update_debug_layer()
