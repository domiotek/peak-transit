class_name PassengerBucketEntry

var _creation_time: TimeOfDay

# Passenger count per line ID
var _line_passenger_map: Dictionary[int, int] = { }


func _init(creation_time: TimeOfDay) -> void:
	_creation_time = creation_time


func add_passengers_for_line(line_id: int, count: int) -> void:
	if not _line_passenger_map.has(line_id):
		_line_passenger_map[line_id] = 0

	_line_passenger_map[line_id] += count


func get_passengers_for_line(line_id: int) -> int:
	if not _line_passenger_map.has(line_id):
		return 0

	return _line_passenger_map[line_id]


func take_passengers_for_line(line_id: int, count: int) -> int:
	if not _line_passenger_map.has(line_id):
		return 0

	var available_count = _line_passenger_map[line_id]
	var taken_count = min(available_count, count)

	_line_passenger_map[line_id] -= taken_count

	if _line_passenger_map[line_id] <= 0:
		_line_passenger_map.erase(line_id)

	return taken_count


func get_total_passengers() -> int:
	var total: int = 0

	for count in _line_passenger_map.values():
		total += count

	return total


func get_creation_time() -> TimeOfDay:
	return _creation_time
