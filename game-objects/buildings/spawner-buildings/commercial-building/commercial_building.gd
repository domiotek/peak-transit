extends SpawnerBuilding

class_name CommercialBuilding

func _get_shape_color() -> Color:
	return Color(0.2, 0.2, 0.8)


func _get_spawn_chance(time_of_day: float) -> float:
	if _is_morning_rush_hour(time_of_day):
		return 0.2
	if _is_midday(time_of_day):
		return 0.3
	if _is_evening_rush_hour(time_of_day):
		return 0.4
	if _is_late_evening(time_of_day):
		return 0.7
	if _is_night_time(time_of_day):
		return 0.9

	return 0.0


func _get_target_building_roll_weights() -> Dictionary:
	return {
		BuildingInfo.BuildingType.RESIDENTIAL: 3,
		BuildingInfo.BuildingType.INDUSTRIAL: 1,
	}
