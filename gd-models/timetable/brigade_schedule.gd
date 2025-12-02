class_name BrigadeSchedule

var brigade_id: int
var trips: Array = []
var cycle_time: int #in minutes


static func deserialize(data: Dictionary) -> BrigadeSchedule:
	var schedule = BrigadeSchedule.new()

	schedule.brigade_id = data.get("brigade_id")
	schedule.cycle_time = data.get("cycle_time")

	var trips_data = data.get("trips", [])
	for trip_data in trips_data:
		var trip = Trip.deserialize(trip_data)
		schedule.trips.append(trip)

	return schedule


func serialize() -> Dictionary:
	var trips_data = []
	for trip in trips:
		trips_data.append(trip.serialize())

	return {
		"brigade_id": brigade_id,
		"cycle_time": cycle_time,
		"trips": trips_data,
	}
