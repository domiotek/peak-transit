extends Control


@onready var start_button: Button = $MarginContainer/BoxContainer/BoxContainer/StartButton
@onready var exit_button: Button = $MarginContainer/BoxContainer/BoxContainer/ExitButton


@onready var game_manager: GameManager = GDInjector.inject("GameManager") as GameManager

func _ready() -> void:
	start_button.connect("pressed", Callable(self, "_on_start_button_pressed"))
	exit_button.connect("pressed", Callable(self, "_on_exit_button_pressed"))

func _on_start_button_pressed() -> void:
	game_manager.initialize_game()


func _on_exit_button_pressed() -> void:
	get_tree().quit()
