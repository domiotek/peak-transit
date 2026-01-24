extends BaseMapTool

class_name PlaceRoadSideObjectMapTool

var skeleton_scene: PackedScene = preload("res://game-objects/game-modes/map-editor-mode/objects/skeletons/generic-skeleton/generic_skeleton.tscn")

enum RoadSideObjectType {
	RESIDENTIAL_BUILDING = BuildingInfo.BuildingType.RESIDENTIAL,
	COMMERCIAL_BUILDING = BuildingInfo.BuildingType.COMMERCIAL,
	INDUSTRIAL_BUILDING = BuildingInfo.BuildingType.INDUSTRIAL,
	TERMINAL = BuildingInfo.BuildingType.TERMINAL,
	DEPOT = BuildingInfo.BuildingType.DEPOT,
	STOP,
}

var _object_type: RoadSideObjectType
var _is_error: bool = false

var _ghost_object: GenericSkeleton = null
var _target_lane: NetLane = null
var _target_offset: float = 0.0

var _segment_helper: SegmentHelper = GDInjector.inject("SegmentHelper") as SegmentHelper
var _buildings_manager: BuildingsManager = GDInjector.inject("BuildingsManager") as BuildingsManager
var _transport_manager: TransportManager = GDInjector.inject("TransportManager") as TransportManager


func setup() -> void:
	_object_type = RoadSideObjectType.RESIDENTIAL_BUILDING

	_ghost_object = skeleton_scene.instantiate() as GenericSkeleton
	_ghost_object.visible = false
	_manager.add_skeleton(_ghost_object)


func handle_map_clicked(_world_position: Vector2) -> void:
	if _is_error or not _target_lane:
		return

	_create_object_instance()


func handle_map_unclicked() -> void:
	_manager.set_active_tool(MapTools.MapEditorTool.NONE)


func handle_map_mouse_move(world_position: Vector2) -> void:
	if not _ghost_object:
		return

	var road_lane: NetLane = _find_edge_lane(world_position) as NetLane

	if not road_lane:
		_ghost_object.visible = false
		return

	var curve = road_lane.get_curve()
	var offset = curve.get_closest_offset(world_position)
	_segment_helper.position_along_the_edge(road_lane.get_parent_segment(), _ghost_object, offset, road_lane.get_segment_relation_id())
	_ghost_object.visible = true
	var polygon_data: Dictionary = _get_collision_polygon()
	_ghost_object.update_shape(polygon_data["collision"], polygon_data.get("visual", PackedVector2Array()))

	var transform := Transform2D.IDENTITY
	transform.origin = _ghost_object.global_position

	var shape_2d: Shape2D = ConvexPolygonShape2D.new()
	shape_2d.set_points(polygon_data["collision"])

	var collision_objects = _manager.find_nodes_under_shape(
		shape_2d,
		transform,
		MapEditorConstants.MAP_NET_SEGMENT_LAYER_ID | MapEditorConstants.MAP_NET_ROADSIDE_OBJECT_LAYER_ID,
	)

	if collision_objects.size() > 0:
		var first_non_target_segment_index = collision_objects.find_custom(
			func(obj):
				if obj is NetSegment:
					var segment: NetSegment = obj as NetSegment
					return segment != road_lane.get_parent_segment()
				return true
		)

		if first_non_target_segment_index >= 0:
			_is_error = true
			_ghost_object.render_error()
			return

	_ghost_object.render_default()
	_is_error = false
	_target_offset = offset
	_target_lane = road_lane


func get_object_type() -> RoadSideObjectType:
	return _object_type


func set_object_type(object_type: RoadSideObjectType) -> void:
	_object_type = object_type


func reset_state() -> void:
	if _ghost_object:
		_ghost_object.queue_free()
		_ghost_object = null

	_target_lane = null
	_is_error = false
	_target_offset = 0.0


func _find_edge_lane(
		world_position: Vector2,
) -> NetLane:
	var lanes = _manager.find_nodes_at_position(
		world_position,
		MapEditorConstants.MAP_SNAPPING_RADIUS,
		MapEditorConstants.MAP_NET_LANE_LAYER_ID,
	)

	if lanes.size() == 0:
		_ghost_object.visible = false
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

	var segment = closest_lane.get_parent_segment()
	var relation: NetRelation = segment.get_relation_of_lane(closest_lane.id)

	var edge_lane_id = relation.get_rightmost_lane_id()

	return segment.get_lane(edge_lane_id)


func _get_collision_polygon() -> Dictionary:
	match _object_type:
		RoadSideObjectType.RESIDENTIAL_BUILDING, RoadSideObjectType.COMMERCIAL_BUILDING, RoadSideObjectType.INDUSTRIAL_BUILDING:
			return {
				"collision": SpawnerBuilding.get_collision_polygon(),
			}
		RoadSideObjectType.TERMINAL:
			return {
				"collision": Terminal.get_collision_polygon(),
				"visual": Terminal.get_visual_polygon(),
			}
		RoadSideObjectType.DEPOT:
			return {
				"collision": Depot.get_collision_polygon(),
			}
		RoadSideObjectType.STOP:
			return {
				"collision": Stop.get_collision_polygon(),
				"visual": Stop.get_visual_polygon(),
			}
		_:
			return {
				"collision": PackedVector2Array(),
			}


func _create_object_instance() -> void:
	var target_segment = _target_lane.get_parent_segment()
	var relation_idx = _target_lane.get_segment_relation_id()
	var relation = _target_lane.get_segment_relation()

	var position = SegmentPosDefinition.new()
	position.segment = [relation.start_node.id, relation.end_node.id]
	position.offset = _target_offset

	match _object_type:
		RoadSideObjectType.RESIDENTIAL_BUILDING, RoadSideObjectType.COMMERCIAL_BUILDING, RoadSideObjectType.INDUSTRIAL_BUILDING:
			var building_info = BuildingInfo.new()
			building_info.type = int(_object_type)
			building_info.offset_position = _target_offset

			var building = _buildings_manager.create_spawner_building(building_info)
			target_segment.place_spawner_building(building, relation_idx)
			building.setup_connections()
		RoadSideObjectType.TERMINAL:
			var terminal_def = TerminalDefinition.new()
			terminal_def.position = position
			_transport_manager.register_terminal(terminal_def)
		RoadSideObjectType.DEPOT:
			var depot_def = DepotDefinition.new()
			depot_def.position = position
			depot_def.articulated_bus_capacity = TransportConstants.DEFAULT_DEPOT_ARTICULATED_BUS_CAPACITY
			depot_def.regular_bus_capacity = TransportConstants.DEFAULT_DEPOT_STANDARD_BUS_CAPACITY

			_transport_manager.register_depot(depot_def)
		RoadSideObjectType.STOP:
			var stop_def = StopDefinition.new()
			stop_def.position = position
			stop_def.draw_stripes = true

			_transport_manager.register_stop(stop_def)
