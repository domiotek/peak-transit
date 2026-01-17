extends BaseMapTool

class_name EditLaneMapTool

var segment_scene: PackedScene = preload("res://game-objects/game-modes/map-editor-mode/objects/skeletons/road-segment-skeleton/road_segment_skeleton.tscn")

enum EditLaneToolType {
	ADD_LANE,
	REMOVE_LANE,
	CHANGE_SPEED_LIMIT,
	CHANGE_DIRECTIONS,
}

enum LaneDirection {
	LEFT,
	FORWARD,
	RIGHT,
}

enum LaneDirectionState {
	BLOCKED,
	DISABLED,
	ENABLED,
}

var _tool_type: EditLaneToolType
var _ghost_lane: RoadSegmentSkeleton = null
var _target_lane: NetLane = null
var _selected_lane: NetLane = null
var _selected_speed_limit: int = 20

var _network_builder: NetworkBuilder = NetworkBuilder.new()

var _ui_manager: UIManager = GDInjector.inject("UIManager") as UIManager
var _network_manager: NetworkManager = GDInjector.inject("NetworkManager") as NetworkManager
var _connection_helper: ConnectionsHelper = GDInjector.inject("ConnectionsHelper") as ConnectionsHelper
var _config_manager: ConfigManager


func _init(manager: MapInteractionsManager) -> void:
	super._init(manager)


func setup() -> void:
	_config_manager = GDInjector.inject("ConfigManager") as ConfigManager
	_tool_type = EditLaneToolType.ADD_LANE
	_ghost_lane = segment_scene.instantiate() as RoadSegmentSkeleton
	_ghost_lane.visible = false
	_manager.add_skeleton(_ghost_lane)
	_ghost_lane.update_line_width(NetworkConstants.LANE_WIDTH)


func handle_map_clicked(_world_position: Vector2) -> void:
	if not _target_lane:
		return

	match _tool_type:
		EditLaneToolType.ADD_LANE:
			_network_builder.add_lane_to_road(_target_lane.get_parent_segment(), _target_lane.get_segment_relation_id())
		EditLaneToolType.REMOVE_LANE:
			_network_builder.remove_lane_from_road(_target_lane.get_parent_segment(), _target_lane)
		EditLaneToolType.CHANGE_DIRECTIONS:
			if _selected_lane == null:
				_selected_lane = _target_lane
				_show_lane_direction_selector(_selected_lane)
		EditLaneToolType.CHANGE_SPEED_LIMIT:
			_network_builder.change_lane_speed_limit(_target_lane, _selected_speed_limit)
		_:
			pass


func handle_map_unclicked() -> void:
	if _selected_lane:
		_selected_lane = null
		_ui_manager.hide_ui_view(LaneDirectionSelector.VIEW_NAME)
		return

	_manager.set_active_tool(MapTools.MapEditorTool.NONE)
	_toggle_speed_limit_layer(false)


func handle_map_mouse_move(world_position: Vector2) -> void:
	if not _ghost_lane or _selected_lane:
		return

	var road_lane: NetLane = _find_closest_lane(world_position) as NetLane

	if not road_lane:
		_ghost_lane.visible = false
		return

	if _should_be_edge_lane():
		var edge_lane: NetLane = _get_edge_lane(road_lane)
		if not edge_lane:
			_ghost_lane.visible = false
			return
		_target_lane = edge_lane
	else:
		_target_lane = road_lane

	_ghost_lane.visible = true
	_ghost_lane.render_color(_get_target_color())
	_ghost_lane.update_line(_target_lane.get_curve())


func reset_state() -> void:
	if _ghost_lane:
		_ghost_lane.queue_free()
		_ghost_lane = null

	_target_lane = null
	_selected_lane = null
	_ui_manager.hide_ui_view(LaneDirectionSelector.VIEW_NAME)


func set_tool_type(tool_type: EditLaneToolType) -> void:
	_tool_type = tool_type
	_selected_lane = null
	_target_lane = null
	_ui_manager.hide_ui_view(LaneDirectionSelector.VIEW_NAME)

	if _tool_type == EditLaneToolType.CHANGE_SPEED_LIMIT:
		_toggle_speed_limit_layer(true)
	else:
		_selected_speed_limit = 20
		_toggle_speed_limit_layer(false)


func get_tool_type() -> EditLaneToolType:
	return _tool_type


func set_speed_limit(speed_limit: int) -> void:
	set_tool_type(EditLaneToolType.CHANGE_SPEED_LIMIT)
	_selected_speed_limit = speed_limit


func apply_lane_direction_changes(states: Dictionary) -> void:
	if not _selected_lane or _tool_type != EditLaneToolType.CHANGE_DIRECTIONS:
		return

	var direction = _convert_direction_state_to_lane_direction(states[LaneDirectionSelector.ButtonType.MAIN])
	var allowed_vehicles = _convert_direction_state_to_allowed_vehicles(states)

	_network_builder.change_lane_directions(_selected_lane, direction, allowed_vehicles)


func _should_be_edge_lane() -> bool:
	return _tool_type == EditLaneToolType.ADD_LANE or _tool_type == EditLaneToolType.REMOVE_LANE


func _get_edge_lane(lane: NetLane) -> NetLane:
	var segment = lane.get_parent_segment()
	var relation: NetRelation = segment.get_relation_of_lane(lane.id)

	var edge_lane_id = relation.get_rightmost_lane_id()

	return segment.get_lane(edge_lane_id)


func _get_target_color() -> Color:
	match _tool_type:
		EditLaneToolType.ADD_LANE:
			return MapEditorConstants.SKELETON_POSITIVE_COLOR
		EditLaneToolType.REMOVE_LANE:
			return MapEditorConstants.SKELETON_ERROR_COLOR
		_:
			return MapEditorConstants.SKELETON_DEFAULT_COLOR


func _find_closest_lane(
		world_position: Vector2,
) -> NetLane:
	var lanes = _manager.find_nodes_at_position(
		world_position,
		MapEditorConstants.MAP_SNAPPING_RADIUS,
		MapEditorConstants.MAP_NET_LANE_LAYER_ID,
	)

	if lanes.size() == 0:
		_ghost_lane.visible = false
		return

	var closest_lane: NetLane = null
	var closest_distance: float = INF

	for lane_node in lanes:
		var lane: NetLane = lane_node as NetLane
		if not lane:
			continue

		var curve: Curve2D = lane.get_curve()
		var closest_point: Vector2 = curve.get_closest_point(world_position)
		var distance: float = world_position.distance_to(closest_point)

		if distance < closest_distance:
			closest_distance = distance
			closest_lane = lane

	return closest_lane


func _show_lane_direction_selector(lane: NetLane) -> void:
	var target_endpoint = _network_manager.get_lane_endpoint(lane.to_endpoint)

	var anchor_position: Vector2 = target_endpoint.Position
	var direction = lane.direction
	var target_node = lane.get_segment_relation().end_node
	var initial_states = { }
	var allowed_vehicles_per_direction = lane.data.allowed_vehicles
	var possible_directions = target_node.get_segment_directions(lane.get_parent_segment().id)

	initial_states[LaneDirectionSelector.ButtonType.MAIN] = _convert_lane_direction_to_direction_state(direction)
	initial_states.merge(
		_convert_allowed_vehicles_to_direction_state(allowed_vehicles_per_direction, initial_states[LaneDirectionSelector.ButtonType.MAIN]),
	)

	initial_states[LaneDirectionSelector.ButtonType.MAIN] = _block_impossible_directions(
		initial_states[LaneDirectionSelector.ButtonType.MAIN],
		possible_directions,
	)

	var data: Dictionary = {
		"anchor_position": anchor_position,
		"initial_states": initial_states,
	}

	_ui_manager.show_ui_view(LaneDirectionSelector.VIEW_NAME, data)


func _convert_direction_state_to_lane_direction(states: Array) -> Enums.Direction:
	var has_left = states[LaneDirection.LEFT] == LaneDirectionState.ENABLED
	var has_forward = states[LaneDirection.FORWARD] == LaneDirectionState.ENABLED
	var has_right = states[LaneDirection.RIGHT] == LaneDirectionState.ENABLED

	return _connection_helper.construct_direction(has_left, has_forward, has_right)


func _convert_lane_direction_to_direction_state(direction: Enums.Direction) -> Array:
	var result = _connection_helper.deconstruct_direction(direction)

	var states = [
		LaneDirectionState.ENABLED if result["has_left"] else LaneDirectionState.DISABLED,
		LaneDirectionState.ENABLED if result["has_forward"] else LaneDirectionState.DISABLED,
		LaneDirectionState.ENABLED if result["has_right"] else LaneDirectionState.DISABLED,
	]

	return states


func _convert_allowed_vehicles_to_direction_state(allowed_vehicles: Dictionary, general_states: Array) -> Dictionary:
	var left_list = allowed_vehicles.get(Enums.BaseDirection.LEFT, [])
	var forward_list = allowed_vehicles.get(Enums.BaseDirection.FORWARD, [])
	var right_list = allowed_vehicles.get(Enums.BaseDirection.RIGHT, [])

	var results = { }

	for vehicle_type in VehicleManager.VehicleCategory.values():
		var states = []
		states.append(_resolve_vehicle_direction_state(general_states[LaneDirection.LEFT], left_list, vehicle_type))
		states.append(_resolve_vehicle_direction_state(general_states[LaneDirection.FORWARD], forward_list, vehicle_type))
		states.append(_resolve_vehicle_direction_state(general_states[LaneDirection.RIGHT], right_list, vehicle_type))

		# to LaneDirectionSelector.ButtonType indexing
		results[vehicle_type + 1] = states

	return results


func _resolve_vehicle_direction_state(
		general_state: LaneDirectionState,
		allowed_list: Array,
		vehicle_type: VehicleManager.VehicleCategory,
) -> LaneDirectionState:
	if general_state == LaneDirectionState.BLOCKED:
		return LaneDirectionState.BLOCKED
	if general_state == LaneDirectionState.DISABLED:
		return LaneDirectionState.DISABLED

	# General direction is enabled. If no specific list was provided, allow all vehicles.
	if allowed_list.is_empty():
		return LaneDirectionState.ENABLED

	return LaneDirectionState.ENABLED if allowed_list.has(vehicle_type) else LaneDirectionState.DISABLED


func _convert_direction_state_to_allowed_vehicles(
		states: Dictionary,
) -> Dictionary:
	var allowed_vehicles: Dictionary = {
		Enums.BaseDirection.LEFT: [],
		Enums.BaseDirection.FORWARD: [],
		Enums.BaseDirection.RIGHT: [],
	}

	for vehicle_type in VehicleManager.VehicleCategory.values():
		var vehicle_states = states.get(vehicle_type + 1, [])

		if vehicle_states.size() != 3:
			continue

		if vehicle_states[LaneDirection.LEFT] == LaneDirectionState.ENABLED:
			allowed_vehicles[Enums.BaseDirection.LEFT].append(vehicle_type)
		if vehicle_states[LaneDirection.FORWARD] == LaneDirectionState.ENABLED:
			allowed_vehicles[Enums.BaseDirection.FORWARD].append(vehicle_type)
		if vehicle_states[LaneDirection.RIGHT] == LaneDirectionState.ENABLED:
			allowed_vehicles[Enums.BaseDirection.RIGHT].append(vehicle_type)

	for direction in allowed_vehicles.keys():
		if allowed_vehicles[direction].size() == VehicleManager.VehicleCategory.values().size():
			allowed_vehicles.erase(direction)

	return allowed_vehicles


func _block_impossible_directions(current_directions: Array, possible_directions: Array) -> Array:
	for direction in range(current_directions.size()):
		match direction:
			LaneDirection.LEFT:
				if not possible_directions.has(Enums.BaseDirection.LEFT):
					current_directions[direction] = LaneDirectionState.BLOCKED
			LaneDirection.FORWARD:
				if not possible_directions.has(Enums.BaseDirection.FORWARD):
					current_directions[direction] = LaneDirectionState.BLOCKED
			LaneDirection.RIGHT:
				if not possible_directions.has(Enums.BaseDirection.RIGHT):
					current_directions[direction] = LaneDirectionState.BLOCKED

	return current_directions


func _toggle_speed_limit_layer(enabled: bool) -> void:
	_config_manager.DebugToggles.SetToggle("DrawLaneSpeedLimits", enabled)
