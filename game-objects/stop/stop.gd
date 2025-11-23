extends Node2D

class_name Stop

var id: int

var _data: StopDefinition
var _segment: NetSegment
var _relation_id: int

@onready var road_marking = $RoadMarking


func setup(new_id: int, stop_data: StopDefinition, segment: NetSegment, relation_id: int) -> void:
	id = new_id
	_data = stop_data
	_segment = segment
	_relation_id = relation_id


func update_visuals(show_road_marking: bool) -> void:
	road_marking.visible = _data.draw_stripes and show_road_marking


func get_position_offset() -> float:
	return _data.position.offset


func get_incoming_node_id() -> int:
	return _data.position.segment[0]


func get_outgoing_node_id() -> int:
	return _data.position.segment[1]


func get_lane() -> NetLane:
	return _segment.get_lane(_segment.relations[_relation_id].get_rightmost_lane_id())
