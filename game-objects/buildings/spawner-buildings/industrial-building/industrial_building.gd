extends SpawnerBuilding


class_name IndustrialBuilding

func _get_starting_vehicles_pool() -> int:
	return 15

func _get_shape_color() -> Color:
	return Color(0.8, 0.5, 0.2)