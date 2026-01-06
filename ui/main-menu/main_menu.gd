extends Control

@onready var quick_start_button: Button = $MarginContainer/BoxContainer/BoxContainer/QuickStartButton
@onready var load_world_button: Button = $MarginContainer/BoxContainer/BoxContainer/LoadWorldButton
@onready var map_editor_button: Button = $MarginContainer/BoxContainer/BoxContainer/MapEditorButton
@onready var exit_button: Button = $MarginContainer/BoxContainer/BoxContainer/ExitButton

@onready var select_world_view: Panel = $SelectWorldView
@onready var launch_map_editor_view: Panel = $LaunchMapEditorView

@onready var game_manager: GameManager = GDInjector.inject("GameManager") as GameManager

var _is_launching_map_editor: bool = false


func _ready() -> void:
	quick_start_button.connect("pressed", Callable(self, "_on_start_button_pressed"))
	load_world_button.connect("pressed", Callable(self, "_on_load_world_button_pressed"))
	map_editor_button.connect("pressed", Callable(self, "_on_map_editor_button_pressed"))
	exit_button.connect("pressed", Callable(self, "_on_exit_button_pressed"))
	select_world_view.connect("world_selected", Callable(self, "_on_world_selected"))

	launch_map_editor_view.connect("new_world_launch_requested", Callable(self, "_on_editor_create_new_world_requested"))
	launch_map_editor_view.connect("load_existing_world_requested", Callable(self, "_on_editor_load_existing_world_requested"))


func _on_start_button_pressed() -> void:
	game_manager.initialize_game(Enums.GameMode.CHALLENGE)
	_is_launching_map_editor = false


func _on_load_world_button_pressed() -> void:
	select_world_view.init()
	_is_launching_map_editor = false


func _on_map_editor_button_pressed() -> void:
	launch_map_editor_view.init()
	_is_launching_map_editor = true


func _on_exit_button_pressed() -> void:
	get_tree().quit()


func _on_world_selected(world_file_path: String) -> void:
	if _is_launching_map_editor:
		game_manager.initialize_game(Enums.GameMode.MAP_EDITOR, world_file_path)
		return

	game_manager.initialize_game(Enums.GameMode.CHALLENGE, world_file_path)


func _on_editor_create_new_world_requested() -> void:
	if not _is_launching_map_editor:
		return

	game_manager.initialize_game(Enums.GameMode.MAP_EDITOR)


func _on_editor_load_existing_world_requested() -> void:
	if not _is_launching_map_editor:
		return

	select_world_view.init()
