class_name Brigade

var id: int
var line_id: int
var line_tag: int
var line_color: Color
var _schedule: BrigadeSchedule
var _index: int
var _start_time: TimeOfDay
var _end_time: TimeOfDay
var _last_scheduled_trip_index: int = 0
var _last_assigned_trip_index: int = -1

# vehicle_id -> trip_index
var _vehicles: Dictionary = { }

var _trips: Array = []

var clock_manager: ClockManager


func _init(_id: int, _transport_line_id: int, schedule: BrigadeSchedule, _line_tag: int, index: int, _line_color: Color) -> void:
	id = _id
	line_id = _transport_line_id
	line_tag = _line_tag
	line_color = _line_color
	_schedule = schedule
	_index = index

	_start_time = _schedule.trips[0].departure_time
	_end_time = _schedule.trips[_schedule.trips.size() - 1].arrival_time

	var game_manager = GDInjector.inject("GameManager") as GameManager

	clock_manager = game_manager.clock

	for trip_idx in range(_schedule.trips.size()):
		_trips.append(BrigadeTrip.new(trip_idx, line_id, _schedule.trips[trip_idx]))


func get_schedule() -> BrigadeSchedule:
	return _schedule


func get_trip(index: int) -> BrigadeTrip:
	return _trips[index]


func get_trips() -> Array:
	return _trips


func is_trip_assigned(trip_idx: int) -> bool:
	return trip_idx in _vehicles.values()


func get_identifier() -> String:
	return "%02d-%02d" % [line_tag, _index + 1]


func get_line_tag() -> int:
	return line_tag


func get_start_time() -> TimeOfDay:
	return _start_time


func get_end_time() -> TimeOfDay:
	return _end_time


func get_cycle_time() -> int:
	return _schedule.cycle_time


func get_trip_count() -> int:
	return _schedule.trips.size()


func get_vehicle_count() -> int:
	return _vehicles.size()


func assign_vehicle(vehicle_id: int) -> int:
	var current_time = clock_manager.get_time().to_time_of_day()

	var scheduled_trip_idx = _get_next_scheduled_trip_index(current_time)

	var trip_idx = 0
	if _vehicles.size() == 0:
		trip_idx = scheduled_trip_idx
	else:
		trip_idx = _get_next_trip_index(_last_assigned_trip_index)

	_vehicles.set(vehicle_id, trip_idx)
	_last_assigned_trip_index = trip_idx

	return trip_idx


func unassign_vehicle(vehicle_id: int) -> void:
	_vehicles.erase(vehicle_id)
	_last_assigned_trip_index = -1


func switch_trip(vehicle_id: int, new_trip_idx: int) -> bool:
	if vehicle_id not in _vehicles:
		return false

	if is_trip_assigned(new_trip_idx):
		return false

	_vehicles[vehicle_id] = new_trip_idx
	_last_assigned_trip_index = new_trip_idx

	return true


func assign_next_trip(vehicle_id: int, current_index: int) -> int:
	var next_index = _get_next_trip_index(current_index)

	if next_index < current_index:
		return -1

	_vehicles.set(vehicle_id, next_index)
	_last_assigned_trip_index = next_index

	return next_index


func _get_next_trip_index(current_index: int) -> int:
	var next_index = current_index + 1
	if next_index >= get_trip_count():
		next_index = 0

	return next_index


func _get_next_scheduled_trip_index(current_time: TimeOfDay) -> int:
	for i in range(_last_scheduled_trip_index, get_trip_count()):
		var trip = _schedule.trips[i]
		if trip.departure_time.to_minutes() >= current_time.to_minutes():
			_last_scheduled_trip_index = i
			return i

	return 0


func _get_next_unassigned_trip_index() -> int:
	var start_index = max(0, _last_assigned_trip_index)

	var assigned_trips = _vehicles.values()

	for i in range(start_index, get_trip_count()):
		if i not in assigned_trips:
			return i

	return -1
