class_name Brigade

var id: int
var line_id: int
var line_tag: int
var line_color: Color
var _schedule: BrigadeSchedule
var _index: int
var _start_time: TimeOfDay
var _end_time: TimeOfDay
var _last_arrival_minutes: int = 0
var _service_exhausted_today: bool = false
var _last_clock_minute_seen: int = -1
var _last_scheduled_trip_index: int = 0
var _last_assigned_trip_index: int = -1

# vehicle_id -> trip_index
var _vehicles: Dictionary = { }

var _trips: Array = []

var clock_manager: ClockManager

signal vehicle_assigned(vehicle_id: int, trip_idx: int)
signal vehicle_unassigned(vehicle_id: int)


func _init(_id: int, _transport_line_id: int, schedule: BrigadeSchedule, _line_tag: int, index: int, _line_color: Color) -> void:
	id = _id
	line_id = _transport_line_id
	line_tag = _line_tag
	line_color = _line_color
	_schedule = schedule
	_index = index

	_start_time = _schedule.trips[0].departure_time
	_end_time = _schedule.trips[_schedule.trips.size() - 1].arrival_time
	_last_arrival_minutes = _normalize_day_minutes(_end_time.to_minutes())

	var game_manager = GDInjector.inject("GameManager") as GameManager
	var vehicle_manager = GDInjector.inject("VehicleManager") as VehicleManager

	vehicle_manager.connect("vehicle_destroyed", Callable(self, "_on_vehicle_destroyed"))

	clock_manager = game_manager.clock
	clock_manager.time_changed.connect(Callable(self, "_on_clock_time_changed"))
	_on_clock_time_changed(clock_manager.get_time())

	for trip_idx in range(_schedule.trips.size()):
		_trips.append(BrigadeTrip.new(trip_idx, line_id, _schedule.trips[trip_idx]))


func get_schedule() -> BrigadeSchedule:
	return _schedule


func get_trip(index: int) -> BrigadeTrip:
	return _trips[index]


func get_ongoing_trip(current_time: TimeOfDay) -> BrigadeTrip:
	for trip in _trips:
		if trip.get_status(current_time) == BrigadeTrip.TripStatus.ONGOING:
			return trip

	return null


func get_next_trip(current_time: TimeOfDay) -> BrigadeTrip:
	var current_trip = get_ongoing_trip(current_time)

	if current_trip != null:
		var current_index = current_trip.idx
		var next_index = current_index + 1

		if next_index >= _trips.size():
			next_index = 0

		return _trips[next_index]

	var current_minutes = current_time.to_minutes()
	for trip in _trips:
		if trip.get_departure_time().to_minutes() >= current_minutes:
			return trip

	return _trips[0]


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
	_update_service_day_state(current_time)

	var scheduled_trip_idx = _get_next_scheduled_trip_index(current_time)
	if _service_exhausted_today:
		scheduled_trip_idx = 0

	var trip_idx = 0
	if _service_exhausted_today:
		trip_idx = 0
	elif _vehicles.size() == 0:
		trip_idx = scheduled_trip_idx
	else:
		trip_idx = _find_next_non_past_trip_index(_last_assigned_trip_index, true)
		if trip_idx == -1:
			trip_idx = scheduled_trip_idx

	_vehicles.set(vehicle_id, trip_idx)
	_last_assigned_trip_index = trip_idx

	emit_signal("vehicle_assigned", vehicle_id, trip_idx)

	return trip_idx


func unassign_vehicle(vehicle_id: int) -> void:
	_vehicles.erase(vehicle_id)
	_last_assigned_trip_index = -1

	emit_signal("vehicle_unassigned", vehicle_id)


func switch_trip(vehicle_id: int, new_trip_idx: int) -> bool:
	if vehicle_id not in _vehicles:
		return false

	if is_trip_assigned(new_trip_idx):
		return false

	_vehicles[vehicle_id] = new_trip_idx
	_last_assigned_trip_index = new_trip_idx

	emit_signal("vehicle_assigned", vehicle_id, new_trip_idx)

	return true


func assign_next_trip(vehicle_id: int, current_index: int, departure_terminal_id: int = -1) -> int:
	_update_service_day_state(clock_manager.get_time().to_time_of_day())
	if _service_exhausted_today:
		return -1

	var next_index = _find_next_non_past_trip_index(current_index, false, departure_terminal_id)
	if next_index == -1:
		return -1

	if _vehicles.values().has(next_index):
		return -1

	_vehicles.set(vehicle_id, next_index)
	_last_assigned_trip_index = next_index

	emit_signal("vehicle_assigned", vehicle_id, next_index)
	return next_index


func get_vehicle_of_trip(trip_idx: int) -> int:
	for vehicle_id in _vehicles.keys():
		if _vehicles[vehicle_id] == trip_idx:
			return vehicle_id

	return -1

func reset_state() -> void:
	_vehicles.clear()
	_last_assigned_trip_index = -1
	_last_scheduled_trip_index = 0
	_service_exhausted_today = false
	_last_clock_minute_seen = -1


func is_exhausted_for_day() -> bool:
	_update_service_day_state(clock_manager.get_time().to_time_of_day())
	return _service_exhausted_today


func _get_next_trip_index(current_index: int) -> int:
	var next_index = current_index + 1
	if next_index >= get_trip_count():
		next_index = 0

	return next_index


func _get_next_scheduled_trip_index(current_time: TimeOfDay) -> int:
	for i in range(_last_scheduled_trip_index, get_trip_count()):
		var trip = _schedule.trips[i]
		var trip_status = (_trips[i] as BrigadeTrip).get_status(current_time)

		if trip.departure_time.to_minutes() >= current_time.to_minutes() and trip_status != BrigadeTrip.TripStatus.PAST:
			_last_scheduled_trip_index = i
			return i

	for i in range(0, get_trip_count()):
		var trip_status = (_trips[i] as BrigadeTrip).get_status(current_time)
		if trip_status != BrigadeTrip.TripStatus.PAST:
			_last_scheduled_trip_index = i
			return i

	return 0

func _is_trip_past_for_sequence(trip: BrigadeTrip, current_time: TimeOfDay) -> bool:
	return trip.get_status(current_time) == BrigadeTrip.TripStatus.PAST


func _update_service_day_state(current_time: TimeOfDay) -> void:
	var minute_of_day = _normalize_day_minutes(current_time.to_minutes())

	if _last_clock_minute_seen != -1 and minute_of_day < _last_clock_minute_seen:
		_service_exhausted_today = false

	if minute_of_day >= _last_arrival_minutes:
		_service_exhausted_today = true

	_last_clock_minute_seen = minute_of_day


func _on_clock_time_changed(new_time: ClockTime) -> void:
	if new_time == null:
		return

	_update_service_day_state(new_time.to_time_of_day())


func _normalize_day_minutes(minutes: int) -> int:
	return posmod(minutes, 1440)


func _find_next_non_past_trip_index(current_index: int, allow_wrap: bool, departure_terminal_id: int = -1) -> int:
	var start_index = current_index + 1
	if start_index < 0:
		start_index = 0

	var current_time = clock_manager.get_time().to_time_of_day()

	for i in range(start_index, get_trip_count()):
		var trip = _trips[i] as BrigadeTrip
		if not _is_trip_past_for_sequence(trip, current_time) and _trip_matches_departure_terminal(i, departure_terminal_id):
			return i

	if not allow_wrap:
		return -1

	for i in range(0, start_index):
		var trip = _trips[i] as BrigadeTrip
		if not _is_trip_past_for_sequence(trip, current_time) and _trip_matches_departure_terminal(i, departure_terminal_id):
			return i

	return -1


func _trip_matches_departure_terminal(trip_idx: int, departure_terminal_id: int) -> bool:
	if departure_terminal_id == -1:
		return true

	var trip = _trips[trip_idx] as BrigadeTrip
	var departure_terminal = trip.get_departure_terminal()
	if departure_terminal == null:
		return false

	return departure_terminal.terminal_id == departure_terminal_id


func _get_next_unassigned_trip_index() -> int:
	var start_index = max(0, _last_assigned_trip_index)

	var assigned_trips = _vehicles.values()

	for i in range(start_index, get_trip_count()):
		if i not in assigned_trips:
			return i

	return -1


func _on_vehicle_destroyed(vehicle_id: int, vehicle_type: VehicleManager.VehicleType) -> void:
	if vehicle_type != VehicleManager.VehicleType.BUS and vehicle_type != VehicleManager.VehicleType.ARTICULATED_BUS:
		return

	if _vehicles.erase(vehicle_id):
		vehicle_unassigned.emit(vehicle_id)
