extends BaseBuilding

class_name Terminal

var terminal_id: int

var _terminal_data: TerminalDefinition


func setup_terminal(new_id: int, terminal_data: TerminalDefinition) -> void:
	terminal_id = new_id
	_terminal_data = terminal_data


func update_visuals() -> void:
	# Terminals might have specific visuals to update in the future
	pass


func get_terminal_name() -> String:
	return _terminal_data.name


func get_position_offset() -> float:
	return _terminal_data.position.offset


func get_incoming_node_id() -> int:
	return _terminal_data.position.segment[0]


func get_outgoing_node_id() -> int:
	return _terminal_data.position.segment[1]


func _get_connection_endpoints() -> Dictionary:
	return {
		"in": to_global(Vector2(10, -25)),
		"out": to_global(Vector2(-10, -25)),
	}
