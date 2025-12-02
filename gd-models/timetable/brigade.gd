class_name Brigade

var id: int
var line_id: int
var line_tag: int
var _schedule: BrigadeSchedule
var _index: int
var _start_time: TimeOfDay
var _end_time: TimeOfDay


func _init(_id: int, _transport_line_id: int, schedule: BrigadeSchedule, _line_tag: int, index: int) -> void:
	id = _id
	line_id = _transport_line_id
	line_tag = _line_tag
	_schedule = schedule
	_index = index

	_start_time = _schedule.trips[0].departure_time
	_end_time = _schedule.trips[_schedule.trips.size() - 1].arrival_time


func get_schedule() -> BrigadeSchedule:
	return _schedule


func get_identifier() -> String:
	return "%02d-%02d" % [line_tag, _index + 1]


func get_start_time() -> TimeOfDay:
	return _start_time


func get_end_time() -> TimeOfDay:
	return _end_time


func get_cycle_time() -> int:
	return _schedule.cycle_time


func get_trip_count() -> int:
	return _schedule.trips.size()


func get_vehicle_count() -> int:
	return 0
