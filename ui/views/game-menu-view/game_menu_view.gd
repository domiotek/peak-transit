extends Control


var ui_manager: UIManager
var game_manager: GameManager

@onready var resume_button: Button = $PanelContainer/MarginContainer/MainContainer/ButtonsContainer/ResumeButton
@onready var main_menu_button: Button = $PanelContainer/MarginContainer/MainContainer/ButtonsContainer/MainMenuButton
@onready var exit_button: Button = $PanelContainer/MarginContainer/MainContainer/ButtonsContainer/ExitButton


func _ready() -> void:
	ui_manager = GDInjector.inject("UIManager") as UIManager
	game_manager = GDInjector.inject("GameManager") as GameManager

	visible = false
	ui_manager.register_ui_view("GameMenuView", self)

	resume_button.pressed.connect(_on_resume_button_pressed)
	main_menu_button.pressed.connect(_on_main_menu_button_pressed)
	exit_button.pressed.connect(_on_exit_button_pressed)

func _on_resume_button_pressed() -> void:
	game_manager.hide_game_menu()

func _on_main_menu_button_pressed() -> void:
	game_manager.dispose_game()

func _on_exit_button_pressed() -> void:
	get_tree().quit()
