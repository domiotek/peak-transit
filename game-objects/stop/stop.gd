extends Node2D

class_name Stop

var id: int

var _data: StopDefinition
var _demand_preset: DemandPresetDefinition
var _segment: NetSegment
var _relation_id: int
var _lines: Array[int] = []

var _passengers_spawner: StopPassengersSpawner
var _collision_shape: CollisionPolygon2D

@onready var road_marking = $RoadMarking
@onready var click_area: Area2D = $ClickArea
@onready var map_pickable_area: Area2D = $CollisionArea

@onready var game_manager: GameManager = GDInjector.inject("GameManager") as GameManager


func _ready() -> void:
	click_area.connect("input_event", Callable(self, "_on_input_event"))

	if game_manager.get_game_mode() == Enums.GameMode.MAP_EDITOR:
		_collision_shape = CollisionPolygon2D.new()
		_collision_shape.polygon = get_collision_polygon()
		_collision_shape.build_mode = CollisionPolygon2D.BUILD_SEGMENTS
		map_pickable_area.add_child(_collision_shape)


func _process(delta: float) -> void:
	_passengers_spawner.process(delta)


func setup(new_id: int, stop_data: StopDefinition, segment: NetSegment, relation_id: int, demand_preset: DemandPresetDefinition) -> void:
	id = new_id
	_data = stop_data
	_segment = segment
	_relation_id = relation_id
	_demand_preset = demand_preset


func passengers() -> StopPassengersSpawner:
	return _passengers_spawner


func update_visuals(show_road_marking: bool) -> void:
	road_marking.visible = _data.draw_stripes and show_road_marking


func late_setup() -> void:
	_passengers_spawner = StopPassengersSpawner.new(id, false, _lines, _demand_preset, TransportConstants.MAX_PASSENGER_AT_STOP)


func get_stop_name() -> String:
	return _data.name


func get_position_offset() -> float:
	return _data.position.offset


func get_incoming_node_id() -> int:
	return _data.position.segment[0]


func get_outgoing_node_id() -> int:
	return _data.position.segment[1]


func can_vehicle_wait() -> bool:
	return _data.can_wait


func get_segment() -> NetSegment:
	return _segment


func get_lane() -> NetLane:
	return _segment.get_lane(_segment.relations[_relation_id].get_rightmost_lane_id())


func get_anchor() -> Node2D:
	return self


func register_line(line_id: int) -> void:
	if not line_id in _lines:
		_lines.append(line_id)


func get_lines() -> Array[int]:
	return _lines


static func get_collision_polygon() -> PackedVector2Array:
	return PackedVector2Array(
		[
			Vector2(-9, -27),
			Vector2(9, -27),
			Vector2(9, 4),
			Vector2(68, 4),
			Vector2(68, 29),
			Vector2(-68, 29),
			Vector2(-68, 4),
			Vector2(-9, 4),
		],
	)


func _on_input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var selection = StopSelection.new(StopSelection.StopSelectionType.STOP, self)
		game_manager.set_selection(selection, GameManager.SelectionType.TRANSPORT_STOP)
