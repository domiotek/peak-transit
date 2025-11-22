extends SpawnerBuilding

class_name IndustrialBuilding

func _get_starting_vehicles_pool() -> int:
	return 1


func _get_shape_color() -> Color:
	return Color(0.8, 0.5, 0.2)


func _get_spawn_chance(time_of_day: float) -> float:
	if _is_morning_rush_hour(time_of_day):
		return 0.1
	if _is_midday(time_of_day):
		return 0.1
	if _is_evening_rush_hour(time_of_day):
		return 0.7
	if _is_late_evening(time_of_day):
		return 0.45
	if _is_night_time(time_of_day):
		return 0.1

	return 0.0


func _get_target_building_roll_weights() -> Dictionary:
	return {
		BuildingInfo.BuildingType.RESIDENTIAL: 3,
		BuildingInfo.BuildingType.COMMERCIAL: 2,
	}
