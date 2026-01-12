extends BaseMapTool

class_name PlaceRoadMapTool

var road_node_scene: PackedScene = preload("res://game-objects/game-modes/map-editor-mode/objects/skeletons/road-node-skeleton/road_node_skeleton.tscn")
var segment_scene: PackedScene = preload("res://game-objects/game-modes/map-editor-mode/objects/skeletons/road-segment-skeleton/road_segment_skeleton.tscn")

enum RoadToolType {
	STRAIGHT,
	CURVED,
}

enum RoadSize {
	TWO_LANES = 1,
	FOUR_LANES = 2,
	SIX_LANES = 3,
}

var _tool_type: RoadToolType = RoadToolType.CURVED
var _road_size: RoadSize = RoadSize.TWO_LANES

var _ghost_point: RoadNodeSkeleton = null
var _start_point: RoadNodeSkeleton = null
var _start_node: RoadNode = null
var _angle_ref_point: RoadNodeSkeleton = null
var _connection_line: RoadSegmentSkeleton = null
var _target_node: RoadNode = null
var _is_error_state: bool = false
var _last_checked_curve_hash: int = 0
var _last_collision_result: Node2D = null

var _network_builder: NetworkBuilder = NetworkBuilder.new()
var _network_manager: NetworkManager = GDInjector.inject("NetworkManager") as NetworkManager
var _line_helper: LineHelper = GDInjector.inject("LineHelper") as LineHelper


func _init(manager: MapInteractionsManager) -> void:
	super._init(manager)


func setup() -> void:
	_ghost_point = road_node_scene.instantiate() as RoadNodeSkeleton
	_ghost_point.visible = false
	_ghost_point.mark_untrackable()

	_connection_line = segment_scene.instantiate() as RoadSegmentSkeleton
	_connection_line.visible = false

	_manager.add_skeleton(_ghost_point)
	_manager.add_skeleton(_connection_line)

	_tool_type = RoadToolType.STRAIGHT


func handle_map_clicked(world_position: Vector2) -> void:
	var nodes_at_position = _manager.find_nodes_at_position(world_position, MapEditorConstants.MAP_SNAPPING_RADIUS, MapEditorConstants.MAP_NET_NODE_LAYER_ID)
	var target_position: Vector2 = world_position
	var clicked_node: RoadNode = _find_first_road_node(nodes_at_position)

	if clicked_node != null:
		target_position = clicked_node.global_position

	if not _start_point:
		var new_node = road_node_scene.instantiate() as RoadNodeSkeleton
		new_node.position = target_position
		_start_point = new_node
		_start_node = clicked_node

		_manager.add_skeleton(new_node)
		return

	if _tool_type == RoadToolType.STRAIGHT:
		if _is_error_state:
			return

		_target_node = clicked_node
		_build_road_node_at_position(target_position)
		reset_state(true)
		return

	if _tool_type == RoadToolType.CURVED:
		if not _angle_ref_point and clicked_node == null:
			var ref_node = road_node_scene.instantiate() as RoadNodeSkeleton
			ref_node.position = target_position
			ref_node.mark_untrackable()
			_angle_ref_point = ref_node

			_manager.add_skeleton(ref_node)
			return

		if _is_error_state:
			return

		_target_node = clicked_node
		_build_road_node_at_position(target_position)
		reset_state(true)
		return


func handle_map_unclicked() -> void:
	if not _start_point:
		_manager.set_active_tool(MapTools.MapEditorTool.NONE)
		return

	if _angle_ref_point:
		_angle_ref_point.queue_free()
		_angle_ref_point = null
		return

	_start_point.queue_free()
	_start_point = null

	_connection_line.visible = false


func handle_map_mouse_move(world_position: Vector2) -> void:
	if not _ghost_point:
		return

	var should_be_error: bool = false

	var new_position: Vector2 = world_position

	var nodes_at_position = _manager.find_nodes_at_position(world_position, MapEditorConstants.MAP_SNAPPING_RADIUS)

	if nodes_at_position.size() > 0:
		var road_node = _find_first_road_node(nodes_at_position)
		if road_node != null:
			new_position = road_node.global_position

		if _start_point and road_node == null:
			_set_error_state(true)
			should_be_error = true
		else:
			_set_error_state(false)
	else:
		_set_error_state(false)

	_ghost_point.position = new_position
	_ghost_point.visible = true

	if _start_point:
		var direction = (_ghost_point.position - _start_point.position).normalized()
		var angle = direction.angle()
		_ghost_point.rotation = angle

		var curve: Curve2D
		var ref_position: Vector2 = Vector2.ZERO
		var ref_position_set: bool = false

		if not _angle_ref_point:
			curve = Curve2D.new()
			curve.add_point(_start_point.position)
			curve.add_point(_ghost_point.position)
		else:
			var curve_info = _get_curve_info()
			curve = _line_helper.calc_curve(
				_start_point.position,
				_ghost_point.position,
				curve_info["curve_strength"],
				curve_info["curve_direction"],
			)
			ref_position = _angle_ref_point.position
			ref_position_set = true

		_connection_line.update_line(curve, ref_position, ref_position_set)
		_connection_line.visible = true

		var colliding_node = _check_collision_along_curve(curve, MapEditorConstants.SKELETON_SIZE)

		if colliding_node and colliding_node != _start_point:
			_set_error_state(true)
			should_be_error = true

	if not should_be_error:
		_set_error_state(false)


func reset_state(preserve_objects: bool = false) -> void:
	if _ghost_point and not preserve_objects:
		_ghost_point.queue_free()
		_ghost_point = null

	if _connection_line:
		if preserve_objects:
			_connection_line.visible = false
		else:
			_connection_line.queue_free()
			_connection_line = null

	if _start_point:
		_start_point.queue_free()
		_start_point = null

	if _angle_ref_point:
		_angle_ref_point.queue_free()
		_angle_ref_point = null

	_is_error_state = false
	_last_checked_curve_hash = 0
	_last_collision_result = null
	_start_node = null
	_target_node = null


func set_tool_type(tool_type: RoadToolType) -> void:
	_tool_type = tool_type
	reset_state(true)


func set_road_size(road_size: RoadSize) -> void:
	_road_size = road_size


func get_tool_type() -> RoadToolType:
	return _tool_type


func get_road_size() -> RoadSize:
	return _road_size


func _set_error_state(is_error: bool) -> void:
	_is_error_state = is_error

	if _is_error_state:
		_ghost_point.render_error()
		_connection_line.render_error()

		if _start_point:
			_start_point.render_error()

		if _angle_ref_point:
			_angle_ref_point.render_error()
	else:
		_ghost_point.render_default()
		_connection_line.render_default()

		if _start_point:
			_start_point.render_default()

		if _angle_ref_point:
			_angle_ref_point.render_default()


func _check_collision_along_curve(curve: Curve2D, width: float) -> Node2D:
	var curve_hash = hash([_start_point.position, _ghost_point.position])

	if curve_hash == _last_checked_curve_hash:
		return _last_collision_result

	_last_checked_curve_hash = curve_hash

	var curve_length = curve.get_baked_length()

	if curve_length <= 0.0:
		_last_collision_result = null
		return null

	var end_tolerance = 130.0
	var sample_interval = max(10.0, curve_length / 10.0)
	var current_distance = end_tolerance
	var max_distance = curve_length - end_tolerance

	while current_distance <= max_distance:
		var point = curve.sample_baked(current_distance)
		var nodes = _manager.find_nodes_at_position(point, width * 0.5)

		var _is_only_start_or_ghost_point = nodes.size() == 1 and (nodes[0] == _start_point or nodes[0] == _ghost_point)

		if nodes.size() > 0 and not _is_only_start_or_ghost_point:
			_last_collision_result = nodes[0]
			return nodes[0]

		current_distance += sample_interval

	return null


func _find_first_road_node(nodes: Array) -> RoadNode:
	for node in nodes:
		if node is RoadNode:
			return node as RoadNode
	return null


func _build_road_node_at_position(position: Vector2) -> void:
	if _start_node == _target_node and _start_node != null:
		return

	var created_start_node: bool = false
	var created_target_node: bool = false

	if not _start_node:
		_start_node = _network_builder.create_node(_start_point.position)
		_manager.add_network_object(_start_node)
		_network_manager.register_node(_start_node)
		created_start_node = true

	if not _target_node:
		_target_node = _network_builder.create_node(position)
		_manager.add_network_object(_target_node)
		_network_manager.register_node(_target_node)
		created_target_node = true

	var curve_info = _get_curve_info()

	var segment_info = NetSegmentInfo.new()
	segment_info.nodes = [_start_node.id, _target_node.id] as Array[int]
	segment_info.curve_direction = curve_info["curve_direction"]
	segment_info.curve_strength = curve_info["curve_strength"]
	segment_info.relations = _network_builder.get_2way_relations(_road_size)

	_network_builder.build_road(
		_start_node,
		_target_node,
		segment_info,
		Callable(_manager, "add_network_object"),
		created_start_node,
		created_target_node,
	)


func _get_curve_info() -> Dictionary:
	var curve_direction: NetSegmentInfo.CurveDirection = NetSegmentInfo.CurveDirection.CLOCKWISE
	var curve_strength: float = 0.0

	if _tool_type == RoadToolType.CURVED and _angle_ref_point:
		var line_vector = _ghost_point.position - _start_point.position
		var line_length = line_vector.length()

		var perpendicular = Vector2(-line_vector.y, line_vector.x).normalized()
		var mid_point = (_start_point.position + _ghost_point.position) / 2.0

		var mid_to_ref = _angle_ref_point.position - mid_point
		var projection_distance = mid_to_ref.dot(perpendicular)

		if projection_distance > 0.0:
			curve_direction = NetSegmentInfo.CurveDirection.CLOCKWISE
		else:
			curve_direction = NetSegmentInfo.CurveDirection.COUNTER_CLOCKWISE

		curve_strength = abs(projection_distance) / line_length
		curve_strength = clamp(curve_strength, 0.0, 1.0)

	return {
		"curve_direction": curve_direction,
		"curve_strength": curve_strength,
	}
