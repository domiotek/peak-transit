extends BaseGameController

class_name MapEditorGameController

var _map_interactions_manager: MapInteractionsManager = GDInjector.inject("MapInteractionsManager")


func _ready() -> void:
	super._ready()
	var layer = map.create_drawing_layer("SkeletonLayer")
	layer.z_index = 1000

	_map_interactions_manager.set_map(self.map)


func _exit_tree() -> void:
	_map_interactions_manager.reset_state()


func get_max_game_speed() -> Enums.GameSpeed:
	return Enums.GameSpeed.PAUSE


func _on_initialize_game(world: WorldDefinition) -> void:
	var network_grid = map.get_drawing_layer("RoadGrid") as NetworkGrid

	await network_grid.load_network_definition(world.network)


func _after_initialize_game() -> void:
	ui_manager.show_ui_view(MapEditorToolsBar.VIEW_NAME)


func _on_load_world(file_path: String):
	if file_path == "":
		var empty_world = world_manager.GetEmptyWorldDefinition()
		return WorldDefinition.deserialize(empty_world)

	return _load_world_from_file_path(file_path)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			var world_pos: Vector2 = get_global_mouse_position()

			if not map.is_within_map_bounds(world_pos):
				return

			_map_interactions_manager.handle_map_clicked(world_pos)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_map_interactions_manager.handle_map_unclicked()

	elif event is InputEventMouseMotion:
		var world_pos: Vector2 = get_global_mouse_position()

		if not map.is_within_map_bounds(world_pos):
			return

		_map_interactions_manager.handle_map_mouse_move(world_pos)
