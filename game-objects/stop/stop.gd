extends Node2D

class_name Stop

var id: int

var _data: StopDefinition
var _segment: NetSegment


func setup(new_id: int, stop_data: StopDefinition, segment: NetSegment) -> void:
	id = new_id
	_data = stop_data
	_segment = segment


func update_visuals() -> void:
	print("Updating visuals for stop: %s" % _data.name)


func get_position_offset() -> float:
	return _data.position.offset


func get_incoming_node_id() -> int:
	return _data.position.segment[0]


func get_outgoing_node_id() -> int:
	return _data.position.segment[1]
