class_name TerminalPeron

var terminal: Terminal
var peron_index: int


func _init(_terminal: Terminal, _peron_index: int) -> void:
	terminal = _terminal
	peron_index = _peron_index


func get_anchor() -> Node2D:
	return terminal.get_peron_anchor(peron_index)


func get_lines() -> Array:
	return terminal.get_lines_at_peron(peron_index)
