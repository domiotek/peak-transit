extends Control

class_name GameMenuView

const VIEW_NAME = "GameMenuView"

var ui_manager: UIManager
var game_manager: GameManager

@onready var resume_button: Button = $PanelContainer/MarginContainer/MainContainer/ButtonsContainer/ResumeButton
@onready var main_menu_button: Button = $PanelContainer/MarginContainer/MainContainer/ButtonsContainer/MainMenuButton
@onready var exit_button: Button = $PanelContainer/MarginContainer/MainContainer/ButtonsContainer/ExitButton

@onready var game_mode_buttons: BoxContainer = $PanelContainer/MarginContainer/MainContainer/ButtonsContainer/GameModeButtonsContainer


func _ready() -> void:
	ui_manager = GDInjector.inject("UIManager") as UIManager
	game_manager = GDInjector.inject("GameManager") as GameManager

	visible = false
	ui_manager.register_ui_view(GameMenuView.VIEW_NAME, self)

	resume_button.pressed.connect(_on_resume_button_pressed)
	main_menu_button.pressed.connect(_on_main_menu_button_pressed)
	exit_button.pressed.connect(_on_exit_button_pressed)


func update(_data) -> void:
	for child in game_mode_buttons.get_children():
		child.queue_free()

	var buttons = game_manager.get_game_controller().get_game_menu_buttons()
	for button_data in buttons:
		var button = Button.new()
		button.text = button_data.label
		button.focus_mode = Control.FOCUS_NONE
		button.disabled = button_data.disabled
		button.custom_minimum_size = Vector2(0, 40)
		button.pressed.connect(button_data.action)
		game_mode_buttons.add_child(button)

	game_mode_buttons.visible = buttons.size() > 0


func set_interaction_enabled(state: bool) -> void:
	resume_button.disabled = not state
	main_menu_button.disabled = not state
	exit_button.disabled = not state

	for child in game_mode_buttons.get_children():
		if child is Button:
			child.disabled = not state


func _exit_tree() -> void:
	ui_manager.unregister_ui_view(GameMenuView.VIEW_NAME)


func _on_resume_button_pressed() -> void:
	game_manager.hide_game_menu()


func _on_main_menu_button_pressed() -> void:
	game_manager.dispose_game()


func _on_exit_button_pressed() -> void:
	get_tree().quit()
