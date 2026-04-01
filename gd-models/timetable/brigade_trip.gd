class_name BrigadeTrip

enum TripStatus {
	PAST,
	ONGOING,
	FUTURE,
}

var idx: int
var _data: Trip
var _line: TransportLine

var _transport_manager: TransportManager
var _clock_manager: ClockManager


func _init(_idx: int, line_id: int, trip: Trip) -> void:
	idx = _idx
	_data = trip
	_transport_manager = GDInjector.inject("TransportManager") as TransportManager
	_clock_manager = (GDInjector.inject("GameManager") as GameManager).clock
	_line = _transport_manager.get_line(line_id)


func get_destination_stop_id() -> int:
	var stop_ids = _data.stop_times.keys()
	stop_ids.sort()
	return stop_ids[stop_ids.size() - 1]


func get_destination_name() -> String:
	return _line.get_route_destination_name(_data.route_id)


func get_departure_time() -> TimeOfDay:
	return _data.departure_time


func get_departure_time_at_stop(stop_idx: int) -> TimeOfDay:
	var stop_ids = _data.stop_times.keys()
	stop_ids.sort()
	var stop_id = stop_ids[stop_idx]
	return _data.stop_times[stop_id]


func get_departure_terminal() -> Terminal:
	return _line.get_departure_terminal_of_route(_data.route_id)


func get_arrival_time() -> TimeOfDay:
	return _data.arrival_time


func get_arrival_terminal() -> Terminal:
	return _line.get_arrival_terminal_of_route(_data.route_id)


func is_forward() -> bool:
	return _data.route_id == 0


func get_route_id() -> int:
	return _data.route_id


func get_stops() -> Array:
	return _line.get_route_stops(_data.route_id)


func get_stop(stop_idx: int) -> LineStop:
	var stops = _line.get_route_stops(_data.route_id)
	return stops[stop_idx] as LineStop


func get_path() -> Array:
	return _line.get_route_path(_data.route_id)


func get_stop_times() -> Dictionary:
	return _data.stop_times


func is_future_trip() -> bool:
	return get_status() == TripStatus.FUTURE


func is_past_trip() -> bool:
	return get_status() == TripStatus.PAST


func is_ongoing_trip() -> bool:
	return get_status() == TripStatus.ONGOING


func get_status(current_time: TimeOfDay = null) -> TripStatus:
	if current_time == null:
		current_time = _clock_manager.get_time().to_time_of_day()

	var departure_minutes = _normalize_minutes(_data.departure_time.to_minutes())
	var arrival_minutes = _normalize_minutes(_data.arrival_time.to_minutes())
	var current_minutes = _normalize_minutes(current_time.to_minutes())

	if _is_in_circular_interval(current_minutes, departure_minutes, arrival_minutes):
		return TripStatus.ONGOING

	var wraps_midnight = departure_minutes > arrival_minutes

	if wraps_midnight:
		if current_minutes > arrival_minutes and current_minutes < departure_minutes:
			return TripStatus.FUTURE

		return TripStatus.PAST

	if current_minutes < departure_minutes:
		return TripStatus.FUTURE

	return TripStatus.PAST


func get_time_till_departure() -> int:
	var current_time = _clock_manager.get_time().to_time_of_day()
	return current_time.minutes_until(_data.departure_time)


func get_time_till_arrival() -> int:
	var current_time = _clock_manager.get_time().to_time_of_day()
	return current_time.minutes_until(_data.arrival_time)


func check_if_can_wait_at_stop(stop_idx: int) -> bool:
	var line_stops = _line.get_route_stops(_data.route_id)

	var target_line_stop = line_stops[stop_idx] as LineStop

	return target_line_stop.can_wait


func find_next_stop_after_time(time: TimeOfDay) -> int:
	var stop_ids = _data.stop_times.keys()
	stop_ids.sort()
	var last_stop_index = stop_ids.size() - 1
	var current_minutes = _normalize_minutes(time.to_minutes())

	for stop_idx in range(stop_ids.size()):
		var stop_id = stop_ids[stop_idx]
		var stop_time = _data.stop_times[stop_id] as TimeOfDay
		var stop_minutes = _normalize_minutes(stop_time.to_minutes())
		var time_until_stop = _minutes_until(stop_minutes, current_minutes)

		if time_until_stop > 0 and stop_idx != last_stop_index:
			return stop_idx

	return -1


func _normalize_minutes(value: int) -> int:
	return posmod(value, 1440)


func _minutes_until(target_minutes: int, current_minutes: int) -> int:
	var delta = target_minutes - current_minutes
	if delta < 0:
		delta += 1440

	return delta


func _is_in_circular_interval(value: int, interval_start: int, interval_end: int) -> bool:
	if interval_start <= interval_end:
		return value >= interval_start and value <= interval_end

	return value >= interval_start or value <= interval_end
