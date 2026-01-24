extends BaseGameController

class_name MapEditorGameController

var _map_interactions_manager: MapInteractionsManager = GDInjector.inject("MapInteractionsManager")
var transport_manager: TransportManager = GDInjector.inject("TransportManager") as TransportManager


func _ready() -> void:
	super._ready()
	var layer = map.create_drawing_layer("SkeletonLayer")
	layer.z_index = 1000

	_map_interactions_manager.set_map(self.map)


func _exit_tree() -> void:
	_map_interactions_manager.reset_state()


func get_max_game_speed() -> Enums.GameSpeed:
	return Enums.GameSpeed.PAUSE


func get_game_menu_buttons() -> Array[GameMenuButton]:
	var is_current_world_built_in = game_manager.world_definition.built_in

	var buttons: Array[GameMenuButton] = []

	var save_action = Callable(self, "_on_save_button_pressed")
	var save_button = GameMenuButton.new()
	save_button.label = "Save world"
	save_button.action = save_action
	save_button.disabled = is_current_world_built_in
	buttons.append(save_button)

	var save_as_action = Callable(self, "_on_save_as_button_pressed")
	var save_as_button = GameMenuButton.new()
	save_as_button.label = "Save world as..."
	save_as_button.action = save_as_action
	buttons.append(save_as_button)

	return buttons


func get_world_details() -> Dictionary:
	return {
		"name": _world_definition.name,
		"description": _world_definition.description,
		"created_at": _world_definition.created_at,
		"file_path": _world_definition.file_path,
		"map_size": _world_definition.map.size,
		"camera_initial_pos": _world_definition.map.initial_pos,
		"camera_initial_zoom": _world_definition.map.initial_zoom,
	}


func set_world_name(world_name: String) -> void:
	_world_definition.name = world_name


func set_world_description(description: String) -> void:
	_world_definition.description = description


func set_map_size(new_size: Vector2) -> void:
	_world_definition.map.size = new_size
	map.set_map_size(new_size)
	camera_bounds = Rect2(-new_size / 2, new_size)
	camera.update_camera_bounds(camera_bounds)


func set_camera_initial_pos(new_pos: Vector2) -> void:
	_world_definition.map.initial_pos = new_pos


func set_camera_initial_zoom(new_zoom: float) -> void:
	_world_definition.map.initial_zoom = new_zoom


func _on_initialize_game(world: WorldDefinition) -> void:
	var network_grid = map.get_drawing_layer("RoadGrid") as NetworkGrid

	await network_grid.load_network_definition(world.network)

	await TransportHelper.load_transport_definition(world.transport, true, false)


func _after_initialize_game() -> void:
	ui_manager.show_ui_view(MapEditorToolsBar.VIEW_NAME)
	ui_manager.show_ui_view(ObjectConfigurationPanel.VIEW_NAME)


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


func _on_save_button_pressed() -> void:
	var definition_data = _prepare_definition_data()

	var is_new_world = definition_data["new_world"] as bool

	if is_new_world:
		await _on_save_as_button_pressed()
		return

	var save_result = _save_world(
		definition_data["file_name"] as String,
		definition_data["definition"] as Dictionary,
		true,
	)

	if save_result["success"] as bool:
		_on_success(save_result)
		return

	_on_error(save_result.get("error", "Unknown error."))


func _on_save_as_button_pressed() -> void:
	var definition_data = _prepare_definition_data()

	var new_file_name_response = await _take_file_name_input(definition_data["file_name"] as String)

	if new_file_name_response["canceled"] as bool:
		return

	var new_file_name = new_file_name_response["file_name"] as String

	var save_result = _save_world(
		new_file_name,
		definition_data["definition"] as Dictionary,
		false,
	)

	if save_result["success"] as bool:
		_on_success(save_result)
		return

	var error_code = save_result.get("error_code", "")

	match error_code:
		"FILE_ALREADY_EXISTS":
			var overwrite = await _ask_for_overwrite_confirmation()
			if overwrite:
				var overwrite_result = _save_world(
					new_file_name,
					definition_data["definition"] as Dictionary,
					true,
				)

				if overwrite_result["success"] as bool:
					_on_success(overwrite_result)
					return

				_on_error(overwrite_result.get("error", "Unknown error."))
		_:
			_on_error(save_result.get("error", "Unknown error."))


func _prepare_definition_data() -> Dictionary:
	var definition_builder = DefinitionBuilder.new()

	var world_definition = definition_builder.collect_world_definition()

	var file_name = (world_definition.file_path.get_file()
		if world_definition.file_path != ""
		else world_manager.SanitizeWorldFileName(world_definition.name) + ".json"
	)

	return {
		"definition": world_definition.serialize(),
		"file_name": file_name,
		"new_world": world_definition.file_path == "",
	}


func _save_world(file_name: String, definition: Dictionary, overwrite: bool) -> Dictionary:
	var result = world_manager.SaveWorldDefinition(definition, file_name, overwrite)

	if result["success"] as bool:
		print("World saved successfully.")
		return {
			"success": true,
			"file_path": result["filePath"],
		}

	var error_message = result.get("savingError", "Unknown error occurred while saving the world.")
	push_error("Failed to save world: %s" % error_message)

	return {
		"success": false,
		"error": error_message,
		"error_code": result.get("errorCode", ""),
	}


func _take_file_name_input(file_name: String) -> Dictionary:
	game_manager.toggle_game_menu_interaction(false)
	ui_manager.show_ui_view(
		NewNameSaveDialog.VIEW_NAME,
		{ "file_name": file_name },
	)

	var dialog = ui_manager.get_ui_view(NewNameSaveDialog.VIEW_NAME) as NewNameSaveDialog

	var response = {
		"handled": false,
		"file_name": "",
		"canceled": false,
	}

	var save_callback = func(new_file_name: String) -> void:
		response["handled"] = true
		if new_file_name.ends_with(".json"):
			response["file_name"] = new_file_name
		else:
			response["file_name"] = "%s.json" % new_file_name

	var cancel_callback = func() -> void:
		response["handled"] = true
		response["canceled"] = true

	dialog.save_requested.connect(save_callback, ConnectFlags.CONNECT_ONE_SHOT)
	dialog.cancel_requested.connect(cancel_callback, ConnectFlags.CONNECT_ONE_SHOT)

	await dialog.resolved

	if dialog.save_requested.is_connected(save_callback):
		dialog.save_requested.disconnect(save_callback)

	if dialog.cancel_requested.is_connected(cancel_callback):
		dialog.cancel_requested.disconnect(cancel_callback)

	ui_manager.hide_ui_view(NewNameSaveDialog.VIEW_NAME)
	game_manager.toggle_game_menu_interaction(true)

	return response


func _ask_for_overwrite_confirmation() -> bool:
	game_manager.toggle_game_menu_interaction(false)
	ui_manager.show_ui_view(ConfirmOverwriteDialog.VIEW_NAME)

	var dialog = ui_manager.get_ui_view(ConfirmOverwriteDialog.VIEW_NAME) as ConfirmOverwriteDialog

	var response = {
		"overwrite": false,
	}

	var overwrite_callback = func() -> void:
		response["overwrite"] = true

	var cancel_callback = func() -> void:
		response["overwrite"] = false

	dialog.overwrite_confirmed.connect(overwrite_callback, ConnectFlags.CONNECT_ONE_SHOT)
	dialog.overwrite_canceled.connect(cancel_callback, ConnectFlags.CONNECT_ONE_SHOT)

	await dialog.resolved

	if dialog.overwrite_confirmed.is_connected(overwrite_callback):
		dialog.overwrite_confirmed.disconnect(overwrite_callback)

	if dialog.overwrite_canceled.is_connected(cancel_callback):
		dialog.overwrite_canceled.disconnect(cancel_callback)

	ui_manager.hide_ui_view(ConfirmOverwriteDialog.VIEW_NAME)
	game_manager.toggle_game_menu_interaction(true)

	return response["overwrite"]


func _show_message_box(title: String, message: String) -> void:
	ui_manager.show_ui_view(
		MessageBoxView.VIEW_NAME,
		{
			"title": title,
			"message": message,
		},
	)


func _on_error(error_message: String) -> void:
	_show_message_box("Error Saving World", error_message)


func _on_success(result: Dictionary) -> void:
	_world_definition.file_path = result["file_path"] as String
	game_manager.hide_game_menu()
