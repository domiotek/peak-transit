class_name TimeOfDay

var hour: int
var minute: int


func _init(_hour: int = 0, _minute: int = 0) -> void:
	hour = _hour
	minute = _minute


static func deserialize(data: Dictionary) -> TimeOfDay:
	var time_of_day = TimeOfDay.new()

	time_of_day.hour = data.get("hour")
	time_of_day.minute = data.get("minute")

	return time_of_day


static func parse(time_str: String) -> TimeOfDay:
	if time_str == "":
		return null

	var parts = time_str.split(":")

	if parts.size() != 2:
		push_error("Invalid time string format: %s" % time_str)
		return null

	var _hour = int(parts[0])
	var _minute = int(parts[1])

	return TimeOfDay.new(_hour, _minute)


func serialize() -> Dictionary:
	return {
		"hour": hour,
		"minute": minute,
	}


func format() -> String:
	return "%02d:%02d" % [hour, minute]


func to_minutes() -> int:
	return hour * 60 + minute
