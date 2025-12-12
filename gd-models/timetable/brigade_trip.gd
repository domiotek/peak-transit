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


func get_departure_terminal() -> Terminal:
	return _line.get_departure_terminal_of_route(_data.route_id)


func get_arrival_time() -> TimeOfDay:
	return _data.arrival_time


func get_arrival_terminal() -> Terminal:
	return _line.get_arrival_terminal_of_route(_data.route_id)


func is_forward() -> bool:
	return _data.route_id == 0


func get_route_steps() -> Array:
	return _line.get_route_steps(_data.route_id)


func get_stop_times() -> Dictionary:
	return _data.stop_times
