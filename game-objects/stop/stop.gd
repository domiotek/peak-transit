extends Node2D

class_name Stop

var id: int

var _data: StopDefinition
var _segment: NetSegment

@onready var road_marking = $RoadMarking


func setup(new_id: int, stop_data: StopDefinition, segment: NetSegment) -> void:
	id = new_id
	_data = stop_data
	_segment = segment


func update_visuals(show_road_marking: bool) -> void:
	road_marking.visible = _data.draw_stripes and show_road_marking


func get_position_offset() -> float:
	return _data.position.offset


func get_incoming_node_id() -> int:
	return _data.position.segment[0]


func get_outgoing_node_id() -> int:
	return _data.position.segment[1]
