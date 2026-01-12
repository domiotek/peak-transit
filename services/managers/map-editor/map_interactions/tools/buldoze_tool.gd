extends BaseMapTool

class_name BuldozeMapTool

var segment_scene: PackedScene = preload("res://game-objects/game-modes/map-editor-mode/objects/skeletons/road-segment-skeleton/road_segment_skeleton.tscn")

var _ghost_segment: RoadSegmentSkeleton = null

var _network_builder: NetworkBuilder = NetworkBuilder.new()


func _init(manager: MapInteractionsManager) -> void:
	super._init(manager)


func setup() -> void:
	_ghost_segment = segment_scene.instantiate() as RoadSegmentSkeleton
	_ghost_segment.visible = false
	_manager.add_skeleton(_ghost_segment)


func handle_map_clicked(_world_position: Vector2) -> void:
	var road_segment: NetSegment = _find_closest_segment(_world_position) as NetSegment

	if not road_segment:
		return

	_network_builder.destroy_road(road_segment)


func handle_map_mouse_move(world_position: Vector2) -> void:
	if not _ghost_segment:
		return

	var road_segment: NetSegment = _find_closest_segment(world_position) as NetSegment

	if not road_segment:
		_ghost_segment.visible = false
		return

	_ghost_segment.visible = true
	_ghost_segment.update_line(road_segment.get_curve())


func reset_state() -> void:
	if _ghost_segment:
		_ghost_segment.queue_free()
		_ghost_segment = null


func _find_closest_segment(
		world_position: Vector2,
) -> NetSegment:
	var segments = _manager.find_nodes_at_position(
		world_position,
		MapEditorConstants.MAP_SNAPPING_RADIUS,
		MapEditorConstants.MAP_NET_SEGMENT_LAYER_ID,
	)

	if segments.size() == 0:
		_ghost_segment.visible = false
		return

	var closest_segment: NetSegment = null
	var closest_distance: float = INF

	for segment_node in segments:
		var segment: NetSegment = segment_node as NetSegment
		if not segment:
			continue

		var curve: Curve2D = segment.get_curve()
		var closest_point: Vector2 = curve.get_closest_point(world_position)
		var distance: float = world_position.distance_to(closest_point)

		if distance < closest_distance:
			closest_distance = distance
			closest_segment = segment

	return closest_segment
