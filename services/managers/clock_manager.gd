class_name ClockManager

var current_hour: int = 0
var current_minute: int = 0
var current_day: Enums.Day = Enums.Day.MONDAY
var accumulated_minutes: float = 0.0 # Track fractional minutes

signal time_changed(new_time: ClockTime)
signal day_night_changed(is_day: bool)
signal clock_reset()


func _init() -> void:
	reset()


func reset(preserve_day: bool = false) -> void:
	current_hour = 0
	current_minute = 0
	if not preserve_day:
		current_day = Enums.Day.MONDAY
	accumulated_minutes = 0.0
	emit_signal("time_changed", get_time())
	emit_signal("clock_reset")


func advance_time(delta: float) -> void:
	var was_day = is_day()
	var game_minutes_passed = delta / SimulationConstants.SIMULATION_REAL_SECONDS_PER_IN_GAME_MINUTE

	accumulated_minutes += game_minutes_passed
	var minutes_to_advance = int(accumulated_minutes)
	accumulated_minutes -= minutes_to_advance

	if minutes_to_advance == 0:
		return

	var total_minutes = current_hour * 60 + current_minute + minutes_to_advance
	var days_advanced = int(total_minutes / (24.0 * 60))
	total_minutes = total_minutes % (24 * 60)

	current_hour = int(total_minutes / 60.0)
	current_minute = total_minutes % 60

	if days_advanced > 0:
		current_day = (int(current_day) - 1 + days_advanced) % 7 + 1 as Enums.Day

	emit_signal("time_changed", get_time())

	if was_day != is_day():
		emit_signal("day_night_changed", not was_day)


func get_time() -> ClockTime:
	return ClockTime.create(current_hour, current_minute, current_day)


func get_day_progress_percentage() -> float:
	return (current_hour * 60 + current_minute + accumulated_minutes) / (24.0 * 60)


func is_day() -> bool:
	var day_progress = get_day_progress_percentage()
	return day_progress >= 0.25 and day_progress < 0.75
