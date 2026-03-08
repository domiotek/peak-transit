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


func reserve_id(id: int) -> void:
	if id < 0:
		return

	var recycled_idx = _recycled_ids.find(id)
	if recycled_idx != -1:
		_recycled_ids.remove_at(recycled_idx)
		return

	if id >= _next_id:
		_next_id = id + 1


func reset() -> void:
	_next_id = 0
	_recycled_ids.clear()
