extends BaseMapTool

class_name IntersectionsMapTool

var road_node_scene: PackedScene = preload("res://game-objects/game-modes/map-editor-mode/objects/skeletons/road-node-skeleton/road_node_skeleton.tscn")
var segment_scene: PackedScene = preload("res://game-objects/game-modes/map-editor-mode/objects/skeletons/road-segment-skeleton/road_segment_skeleton.tscn")

enum IntersectionToolType {
	TRAFFIC_LIGHT,
	PRIORITY_SIGN,
}

var _type: IntersectionToolType

var _ghost_point: RoadNodeSkeleton = null
var _ghost_segment: RoadSegmentSkeleton = null
var _selected_node: RoadNode = null
var _hovered_node: RoadNode = null
var _hovered_segment: NetSegment = null

var _network_builder: NetworkBuilder = NetworkBuilder.new()


func setup() -> void:
	_ghost_point = road_node_scene.instantiate() as RoadNodeSkeleton
	_ghost_point.visible = false
	_ghost_point.mark_untrackable()

	_ghost_segment = segment_scene.instantiate() as RoadSegmentSkeleton
	_ghost_segment.visible = false

	_manager.add_skeleton(_ghost_point)
	_manager.add_skeleton(_ghost_segment)

	_type = IntersectionToolType.TRAFFIC_LIGHT


func handle_map_clicked(_world_position: Vector2) -> void:
	if _hovered_segment:
		_network_builder.toggle_intersection_priority_sign(_selected_node, _hovered_segment)
		return

	if not _selected_node:
		if not _hovered_node:
			return

		if _type == IntersectionToolType.TRAFFIC_LIGHT:
			_network_builder.change_intersection_to_traffic_light(_hovered_node)
			return

	_selected_node = _hovered_node
	_network_builder.change_intersection_to_priority_signs(_selected_node)


func handle_map_unclicked() -> void:
	if not _selected_node:
		_manager.set_active_tool(MapTools.MapEditorTool.NONE)
		return

	_network_builder.revalidate_intersection_priorities(_selected_node)

	_selected_node = null
	_hovered_node = null
	_hovered_segment = null


func handle_map_mouse_move(world_position: Vector2) -> void:
	if not _selected_node:
		_ghost_segment.visible = false
		var nodes_at_position = _manager.find_nodes_at_position(
			world_position,
			MapEditorConstants.MAP_SNAPPING_RADIUS,
			MapEditorConstants.MAP_NET_NODE_LAYER_ID,
		)
		var hovered_node: RoadNode = nodes_at_position[0] as RoadNode if nodes_at_position.size() > 0 else null

		if hovered_node:
			_ghost_point.position = hovered_node.position
			_ghost_point.visible = true
			_hovered_node = hovered_node
		else:
			_ghost_point.visible = false
			_hovered_node = null

		return

	var segments = _selected_node.get_connected_segments()

	var closest_segment: NetSegment = null
	var closest_distance = INF

	for segment in segments:
		var curve: Curve2D = segment.get_curve()
		var closest_point: Vector2 = curve.get_closest_point(world_position)
		var distance = world_position.distance_to(closest_point)

		if distance < closest_distance:
			closest_distance = distance
			closest_segment = segment

	if closest_segment:
		var lane_count = closest_segment.get_lane_count()
		_ghost_segment.update_line_width(lane_count * NetworkConstants.LANE_WIDTH)
		_ghost_segment.update_line(closest_segment.get_curve())
		_ghost_segment.visible = true
		_hovered_segment = closest_segment
	else:
		_ghost_segment.visible = false


func set_intersection_type(intersection_type: IntersectionToolType) -> void:
	_type = intersection_type
	_selected_node = null
	_hovered_node = null
	_hovered_segment = null


func get_intersection_type() -> IntersectionToolType:
	return _type


func reset_state() -> void:
	if _ghost_point:
		_ghost_point.queue_free()
		_ghost_point = null

	if _ghost_segment:
		_ghost_segment.queue_free()
		_ghost_segment = null

	_selected_node = null
	_hovered_node = null
	_hovered_segment = null
