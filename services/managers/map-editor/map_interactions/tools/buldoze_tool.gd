extends BaseMapTool

class_name BuldozeMapTool

var generic_skeleton_scene: PackedScene = preload("res://game-objects/game-modes/map-editor-mode/objects/skeletons/generic-skeleton/generic_skeleton.tscn")
var segment_scene: PackedScene = preload("res://game-objects/game-modes/map-editor-mode/objects/skeletons/road-segment-skeleton/road_segment_skeleton.tscn")

var _ghost_segment: RoadSegmentSkeleton = null
var _ghost_object: GenericSkeleton = null

var _target_object: Node2D = null
var _target_segment: NetSegment = null

var _network_builder: NetworkBuilder = NetworkBuilder.new()
var _transport_manager: TransportManager = GDInjector.inject("TransportManager") as TransportManager
var _buildings_manager: BuildingsManager = GDInjector.inject("BuildingsManager") as BuildingsManager


func _init(manager: MapInteractionsManager) -> void:
	super._init(manager)


func setup() -> void:
	_ghost_segment = segment_scene.instantiate() as RoadSegmentSkeleton
	_ghost_segment.visible = false
	_manager.add_skeleton(_ghost_segment)

	_ghost_object = generic_skeleton_scene.instantiate() as GenericSkeleton
	_ghost_object.visible = false
	_manager.add_skeleton(_ghost_object)


func handle_map_clicked(_world_position: Vector2) -> void:
	if _target_object:
		_remove_target_object()
		_target_object = null
		return

	if _target_segment:
		_network_builder.buldoze_segment(_target_segment)
		_target_segment = null
		return


func handle_map_mouse_move(world_position: Vector2) -> void:
	if not _ghost_segment:
		return

	var target_object = _manager.find_nodes_at_position(
		world_position,
		MapEditorConstants.MAP_SNAPPING_RADIUS / 4,
		MapEditorConstants.MAP_NET_ROADSIDE_OBJECT_LAYER_ID,
	)

	if target_object.size() > 0:
		_ghost_segment.visible = false
		_target_object = target_object[0] as Node2D
		_target_segment = null
		_ghost_object.transform = _target_object.transform
		_ghost_object.update_shape(_target_object.get_collision_polygon())
		_ghost_object.visible = true
		return

	_ghost_object.visible = false

	var road_segment: NetSegment = _find_closest_segment(world_position) as NetSegment

	if not road_segment:
		_ghost_segment.visible = false
		return

	_ghost_segment.visible = true
	_ghost_segment.update_line(road_segment.get_curve())
	_target_object = null
	_target_segment = road_segment


func reset_state() -> void:
	if _ghost_object:
		_ghost_object.queue_free()
		_ghost_object = null

	if _ghost_segment:
		_ghost_segment.queue_free()
		_ghost_segment = null

	_target_object = null
	_target_segment = null


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


func _remove_target_object() -> void:
	if not _target_object:
		return

	if _target_object is SpawnerBuilding:
		var building: SpawnerBuilding = _target_object as SpawnerBuilding
		building.segment.remove_spawner_building(building)
		_buildings_manager.destroy_building(building.id)
	elif _target_object is Terminal:
		var terminal: Terminal = _target_object as Terminal
		_transport_manager.unregister_terminal(terminal.terminal_id)
	elif _target_object is Depot:
		var depot: Depot = _target_object as Depot
		_transport_manager.unregister_depot(depot.depot_id)
	elif _target_object is Stop:
		var stop: Stop = _target_object as Stop
		_transport_manager.unregister_stop(stop.id)
