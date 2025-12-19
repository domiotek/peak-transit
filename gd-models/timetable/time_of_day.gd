class_name TimeOfDay

var hour: int
var minute: int
var total_minutes: int


func _init(_hour: int = 0, _minute: int = 0, _total_minutes: int = 0) -> void:
	hour = _hour
	minute = _minute
	total_minutes = _hour * 60 + _minute if _total_minutes == 0 else _total_minutes


static func deserialize(data: Dictionary) -> TimeOfDay:
	var time_of_day = TimeOfDay.new()

	time_of_day.hour = data.get("hour")
	time_of_day.minute = data.get("minute")
	time_of_day.total_minutes = data.get("totalMinutes", time_of_day.hour * 60 + time_of_day.minute)

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
	return total_minutes


func add_minutes(minutes_to_add: int) -> TimeOfDay:
	var new_total_minutes = total_minutes + minutes_to_add
	var new_hour = int(new_total_minutes / 60.0) % 24
	var new_minute = new_total_minutes % 60
	return TimeOfDay.new(new_hour, new_minute, new_total_minutes)


func subtract_minutes(minutes_to_subtract: int) -> TimeOfDay:
	var new_total_minutes = total_minutes - minutes_to_subtract
	if new_total_minutes < 0:
		new_total_minutes = 0
	var new_hour = int(new_total_minutes / 60.0) % 24
	var new_minute = new_total_minutes % 60
	return TimeOfDay.new(new_hour, new_minute, new_total_minutes)


func difference_in_minutes(other: TimeOfDay) -> int:
	return total_minutes - other.total_minutes


func as_next_day() -> TimeOfDay:
	return TimeOfDay.new(hour, minute, total_minutes + 1440)
