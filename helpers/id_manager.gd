class_name IDManager

var _next_id: int = 0
var _recycled_ids: Array[int] = []


func occupy_next_id() -> int:
	if _recycled_ids.size() > 0:
		return _recycled_ids.pop_back()

	var new_id = _next_id
	_next_id += 1
	return new_id


func release_id(id: int) -> void:
	_recycled_ids.append(id)


func reset() -> void:
	_next_id = 0
	_recycled_ids.clear()
