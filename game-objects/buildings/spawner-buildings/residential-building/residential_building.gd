extends SpawnerBuilding

class_name ResidentialBuilding


func _get_starting_vehicles_pool() -> int:
	return 15

func _get_shape_color() -> Color:
	return Color(0.2, 0.6, 0.2)