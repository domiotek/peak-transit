class_name StopSelection

enum StopSelectionType {
	STOP,
	TERMINAL_PERON,
}

var selection_type: StopSelectionType
var terminal_peron: TerminalPeron
var stop: Stop


func _init(type: StopSelectionType, obj: Object) -> void:
	selection_type = type
	match selection_type:
		StopSelectionType.TERMINAL_PERON:
			terminal_peron = obj as TerminalPeron
		StopSelectionType.STOP:
			stop = obj as Stop


func get_anchor() -> Node2D:
	match selection_type:
		StopSelectionType.TERMINAL_PERON:
			return terminal_peron.get_anchor()
		StopSelectionType.STOP:
			return stop.get_anchor()
		_:
			return null


func get_stop_name() -> String:
	match selection_type:
		StopSelectionType.TERMINAL_PERON:
			return terminal_peron.terminal.get_terminal_name() + " (%d)" % terminal_peron.peron_index
		StopSelectionType.STOP:
			return stop.get_stop_name()

	return ""


func get_lines() -> Array:
	match selection_type:
		StopSelectionType.TERMINAL_PERON:
			return terminal_peron.get_lines()
		StopSelectionType.STOP:
			return stop.get_lines()

	return []


func get_departures(line: TransportLine, current_time_of_day: TimeOfDay) -> Array:
	match selection_type:
		StopSelectionType.TERMINAL_PERON:
			return line.get_departures_at_terminal(terminal_peron.terminal.terminal_id, current_time_of_day, 10, false)
		StopSelectionType.STOP:
			return line.get_departures_at_stop(stop.id, current_time_of_day, 10, false)

	return []
