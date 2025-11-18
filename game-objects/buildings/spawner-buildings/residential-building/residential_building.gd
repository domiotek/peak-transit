extends SpawnerBuilding

class_name ResidentialBuilding

func _get_starting_vehicles_pool() -> int:
	return 15


func _get_shape_color() -> Color:
	return Color(0.2, 0.6, 0.2)


func _get_spawn_chance(time_of_day: float) -> float:
	if _is_morning_rush_hour(time_of_day):
		return 0.75
	if _is_midday(time_of_day):
		return 0.4
	if _is_evening_rush_hour(time_of_day):
		return 0.6
	if _is_late_evening(time_of_day):
		return 0.4
	if _is_night_time(time_of_day):
		return 0.05

	return 0.0
