class_name HashSet

var _data: Dictionary = { }


func add(value):
	_data[value] = true


func remove(value):
	_data.erase(value)


func contains(value) -> bool:
	return _data.has(value)


func size() -> int:
	return _data.size()


func clear():
	_data.clear()


func to_array() -> Array:
	return _data.keys()


func is_empty() -> bool:
	return _data.size() == 0


func duplicate() -> HashSet:
	var new_set = HashSet.new()
	for key in _data.keys():
		new_set.add(key)
	return new_set
