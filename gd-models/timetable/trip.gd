class_name Trip

var route_id: int
var departure_time: TimeOfDay
var arrival_time: TimeOfDay
var duration: float #in minutes
var stop_times: Dictionary = { } #key: stop_id, value: TimeOfDay


static func deserialize(data: Dictionary) -> Trip:
	var trip = Trip.new()

	trip.route_id = data.get("routeId")
	trip.departure_time = TimeOfDay.deserialize(data.get("departureTime"))
	trip.arrival_time = TimeOfDay.deserialize(data.get("arrivalTime"))
	trip.duration = data.get("duration")
	var stop_times_dict = data.get("stopTimes", { }) as Dictionary

	for key in stop_times_dict.keys():
		var stop_id = int(key)
		var time_of_day_dict = stop_times_dict[key] as Dictionary
		trip.stop_times[stop_id] = TimeOfDay.deserialize(time_of_day_dict)

	return trip


func serialize() -> Dictionary:
	var serialized_stop_times = { }
	for stop_id in stop_times.keys():
		serialized_stop_times[str(stop_id)] = stop_times[stop_id].serialize()

	return {
		"routeId": route_id,
		"departureTime": departure_time.serialize(),
		"arrivalTime": arrival_time.serialize(),
		"duration": duration,
		"stopTimes": serialized_stop_times,
	}
