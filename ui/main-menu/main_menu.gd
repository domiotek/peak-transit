extends Control


@onready var quick_start_button: Button = $MarginContainer/BoxContainer/BoxContainer/QuickStartButton
@onready var load_world_button: Button = $MarginContainer/BoxContainer/BoxContainer/LoadWorldButton
@onready var exit_button: Button = $MarginContainer/BoxContainer/BoxContainer/ExitButton

@onready var select_world_view: Panel = $SelectWorldView


@onready var game_manager: GameManager = GDInjector.inject("GameManager") as GameManager

func _ready() -> void:
	quick_start_button.connect("pressed", Callable(self, "_on_start_button_pressed"))
	load_world_button.connect("pressed", Callable(self, "_on_load_world_button_pressed"))
	exit_button.connect("pressed", Callable(self, "_on_exit_button_pressed"))
	select_world_view.connect("world_selected", Callable(self, "_on_world_selected"))

func _on_start_button_pressed() -> void:
	game_manager.initialize_game()


func _on_load_world_button_pressed() -> void:
	select_world_view.init()

func _on_exit_button_pressed() -> void:
	get_tree().quit()

func _on_world_selected(world_file_path: String) -> void:
	game_manager.initialize_game(world_file_path)
