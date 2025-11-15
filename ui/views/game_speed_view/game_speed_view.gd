extends Control

class_name GameSpeedView


var ui_manager: UIManager
var game_manager: GameManager

static var VIEW_NAME = "GameSpeedView"

@onready var pause_button: Button = $BoxContainer/PauseButton
@onready var low_button: Button = $BoxContainer/LowButton
@onready var medium_button: Button = $BoxContainer/MediumButton
@onready var high_button: Button = $BoxContainer/HighButton
@onready var turbo_button: Button = $BoxContainer/TurboButton


func _ready() -> void:
	ui_manager = GDInjector.inject("UIManager") as UIManager
	game_manager = GDInjector.inject("GameManager") as GameManager

	ui_manager.register_ui_view(VIEW_NAME, self)

	game_manager.game_speed_changed.connect(_on_game_speed_changed)

	pause_button.pressed.connect(_on_pause_button_pressed)
	low_button.pressed.connect(_on_low_button_pressed)
	medium_button.pressed.connect(_on_medium_button_pressed)
	high_button.pressed.connect(_on_high_button_pressed)
	turbo_button.pressed.connect(_on_turbo_button_pressed)

func _on_game_speed_changed(_new_speed: Enums.GameSpeed) -> void:
	_update_buttons()


func _on_pause_button_pressed() -> void:
	game_manager.set_game_speed(Enums.GameSpeed.PAUSE)

func _on_low_button_pressed() -> void:
	game_manager.set_game_speed(Enums.GameSpeed.LOW)

func _on_medium_button_pressed() -> void:
	game_manager.set_game_speed(Enums.GameSpeed.MEDIUM)

func _on_high_button_pressed() -> void:
	game_manager.set_game_speed(Enums.GameSpeed.HIGH)

func _on_turbo_button_pressed() -> void:
	game_manager.set_game_speed(Enums.GameSpeed.TURBO)

func _update_buttons() -> void:
	var game_speed = game_manager.get_game_speed()
	pause_button.flat = game_speed != Enums.GameSpeed.PAUSE
	low_button.flat = game_speed != Enums.GameSpeed.LOW
	medium_button.flat = game_speed != Enums.GameSpeed.MEDIUM
	high_button.flat = game_speed != Enums.GameSpeed.HIGH
	turbo_button.flat = game_speed != Enums.GameSpeed.TURBO
