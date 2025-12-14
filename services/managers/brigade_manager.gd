class_name BrigadeManager

var _brigades: Array = [] # Array of Brigade


func register(schedule: BrigadeSchedule, line_id: int, line_tag: int, index_in_line: int, line_color: Color) -> int:
	var new_id = _brigades.size()
	var brigade = Brigade.new(new_id, line_id, schedule, line_tag, index_in_line, line_color)
	_brigades.append(brigade)

	return new_id


func get_by_id(brigade_id: int) -> Brigade:
	if brigade_id >= 0 and brigade_id < _brigades.size():
		return _brigades[brigade_id] as Brigade

	push_error("Brigade ID %d is out of bounds." % brigade_id)
	return null


func get_all() -> Array:
	return _brigades


func get_count() -> int:
	return _brigades.size()


# Prefer using TransportLine.get_all() where possible
func get_for_line(line_id: int) -> Array:
	var result: Array = []

	for brigade in _brigades:
		if brigade.transport_line_id == line_id:
			result.append(brigade)

	return result


func clear_state() -> void:
	_brigades.clear()
