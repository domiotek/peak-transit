class_name TripStep

var step_id: int
var travel_time: int #in minutes


static func deserialize(data: Dictionary) -> TripStep:
	var trip_step = TripStep.new()

	trip_step.step_id = data.get("step_id")
	trip_step.travel_time = data.get("travel_time")

	return trip_step


func serialize() -> Dictionary:
	return {
		"step_id": step_id,
		"travel_time": travel_time,
	}
