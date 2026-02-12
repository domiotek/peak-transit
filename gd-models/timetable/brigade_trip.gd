class_name BrigadeTrip

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
	var current_time = _clock_manager.get_time().to_time_of_day()
	return _data.departure_time.to_minutes() > current_time.to_minutes() || is_past_trip()


func is_past_trip() -> bool:
	var current_time = _clock_manager.get_time().to_time_of_day()
	return _data.arrival_time.to_minutes() < current_time.to_minutes()


func is_ongoing_trip() -> bool:
	return not is_future_trip() and not is_past_trip()


func get_time_till_departure() -> int:
	var current_time = _clock_manager.get_time().to_time_of_day()
	var departure_time = _data.departure_time

	return departure_time.difference_in_minutes_sin_cos(current_time) as int


func check_if_can_wait_at_stop(stop_id: int) -> bool:
	var line_stops = _line.get_route_stops(_data.route_id)

	var target_line_stop = line_stops[stop_id] as LineStop

	return target_line_stop.can_wait


func find_next_stop_after_time(time: TimeOfDay) -> int:
	var stop_ids = _data.stop_times.keys()
	stop_ids.sort()
	var last_stop_id = stop_ids[stop_ids.size() - 1]

	for stop_id in stop_ids:
		var stop_time = _data.stop_times[stop_id] as TimeOfDay
		if stop_time.to_minutes() > time.to_minutes() and stop_id != last_stop_id:
			return stop_id

	return -1
