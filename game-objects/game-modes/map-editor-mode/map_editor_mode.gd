extends BaseGameController

class_name MapEditorGameController

func _ready() -> void:
	super._ready()


func get_max_game_speed() -> Enums.GameSpeed:
	return Enums.GameSpeed.PAUSE


func _on_initialize_game(world: WorldDefinition) -> void:
	var network_grid = map.get_drawing_layer("RoadGrid") as NetworkGrid

	await network_grid.load_network_definition(world.network)


func _on_load_world(file_path: String):
	if file_path == "":
		var empty_world = world_manager.GetEmptyWorldDefinition()
		return WorldDefinition.deserialize(empty_world)

	return _load_world_from_file_path(file_path)
