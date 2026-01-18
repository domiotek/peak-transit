class_name MapInteractionsManager

var _active_tool: MapTools.MapEditorTool = MapTools.MapEditorTool.NONE

var _tool_instances: Dictionary = { }
var _map: Map = null

signal tool_changed(new_tool: MapTools.MapEditorTool)


func _init() -> void:
	_tool_instances[MapTools.MapEditorTool.PLACE_ROAD] = PlaceRoadMapTool.new(self)
	_tool_instances[MapTools.MapEditorTool.EDIT_LANE] = EditLaneMapTool.new(self)
	_tool_instances[MapTools.MapEditorTool.PLACE_ROADSIDE] = PlaceRoadSideObjectMapTool.new(self)
	_tool_instances[MapTools.MapEditorTool.BULDOZE] = BuldozeMapTool.new(self)


func set_map(map: Map) -> void:
	_map = map


func reset_state() -> void:
	_active_tool = MapTools.MapEditorTool.NONE
	for tool_instance in _tool_instances.values():
		tool_instance.reset_state()


func set_active_tool(tool: MapTools.MapEditorTool) -> void:
	if _active_tool == tool:
		return

	var prev_instance = get_tool_instance(_active_tool)
	if prev_instance:
		prev_instance.reset_state()

	_active_tool = tool
	emit_signal("tool_changed", _active_tool)

	var new_instance = get_tool_instance(_active_tool)

	if new_instance:
		new_instance.setup()


func get_active_tool() -> MapTools.MapEditorTool:
	return _active_tool


func get_tool_instance(tool: MapTools.MapEditorTool) -> BaseMapTool:
	return _tool_instances.get(tool, null)


func handle_map_clicked(world_position: Vector2) -> void:
	var active_tool_instance = get_tool_instance(_active_tool)
	if active_tool_instance:
		active_tool_instance.handle_map_clicked(world_position)


func handle_map_unclicked() -> void:
	var active_tool_instance = get_tool_instance(_active_tool)
	if active_tool_instance:
		active_tool_instance.handle_map_unclicked()


func handle_map_mouse_move(world_position: Vector2) -> void:
	var active_tool_instance = get_tool_instance(_active_tool)
	if active_tool_instance:
		active_tool_instance.handle_map_mouse_move(world_position)


func find_nodes_at_position(
		world_position: Vector2,
		radius: float = 0.0,
		mask = MapEditorConstants.MAP_ALL_DETECTABLE_LAYERS,
		max_count: int = 10,
) -> Array:
	var space_state := _map.get_world_2d().direct_space_state

	var results = []

	if radius > 0.0:
		var circle_shape := CircleShape2D.new()
		circle_shape.radius = radius

		var params := PhysicsShapeQueryParameters2D.new()
		params.shape = circle_shape
		params.transform = Transform2D(0, world_position)
		params.collide_with_areas = true
		params.collide_with_bodies = false
		params.collision_mask = mask

		results = space_state.intersect_shape(params, max_count)
	else:
		var params := PhysicsPointQueryParameters2D.new()
		params.position = world_position
		params.collide_with_areas = true
		params.collide_with_bodies = false
		params.collision_mask = mask

		results = space_state.intersect_point(params, max_count)

	var seen_areas = { }

	return results.map(
		func(result):
			if seen_areas.has(result.collider_id):
				push_warning("Duplicate collider detected in find_nodes_at_position results.")

			return result.collider.get_parent() as Node2D
	)


func find_nodes_under_shape(shape: Shape2D, transform: Transform2D, mask = MapEditorConstants.MAP_ALL_DETECTABLE_LAYERS, max_count: int = 10) -> Array:
	var space_state := _map.get_world_2d().direct_space_state

	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = shape
	params.transform = transform
	params.collide_with_areas = true
	params.collide_with_bodies = false
	params.collision_mask = mask

	var results = space_state.intersect_shape(params, max_count)

	return results.map(
		func(result):
			return result.collider.get_parent() as Node2D
	)


func add_skeleton(node: Node2D) -> void:
	var skeleton_layer = _map.get_drawing_layer("SkeletonLayer")
	if skeleton_layer:
		skeleton_layer.add_child(node)


func add_network_object(node: Node2D) -> void:
	var network_layer = _map.get_drawing_layer("RoadGrid")
	if network_layer:
		network_layer.add_child(node)


func wait_for_next_frame() -> void:
	await _map.get_tree().process_frame
