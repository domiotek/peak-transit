class_name ClockTime

var hour: int = 0
var minute: int = 0
var day: Enums.Day = Enums.Day.MONDAY


static func create(_hour: int, _minute: int, _day: Enums.Day) -> ClockTime:
	var time = ClockTime.new()
	time.hour = _hour
	time.minute = _minute
	time.day = _day
	return time


func day_progress_percentage() -> float:
	return (hour * 60 + minute) / (24.0 * 60)


func get_formatted() -> String:
	return "%s, %02d:%02d" % [day_to_string(day), hour, minute]


func to_time_of_day() -> TimeOfDay:
	return TimeOfDay.new(hour, minute)


static func day_to_string(_day: Enums.Day) -> String:
	match _day:
		Enums.Day.MONDAY:
			return "MON"
		Enums.Day.TUESDAY:
			return "TUE"
		Enums.Day.WEDNESDAY:
			return "WED"
		Enums.Day.THURSDAY:
			return "THU"
		Enums.Day.FRIDAY:
			return "FRI"
		Enums.Day.SATURDAY:
			return "SAT"
		Enums.Day.SUNDAY:
			return "SUN"
		_:
			return "???"
