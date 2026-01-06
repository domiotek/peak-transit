extends Node2D

class_name GameWindow

@onready var game_viewport: GameController = $Game
@onready var main_menu_ui: Control = $UI/MainMenu


func _ready() -> void:
	var ui_manager = GDInjector.inject("UIManager") as UIManager
	var config_manager: ConfigManager = GDInjector.inject("ConfigManager") as ConfigManager
	var game_manager: GameManager = GDInjector.inject("GameManager") as GameManager

	ui_manager.initialize(main_menu_ui, game_viewport)

	if config_manager.AutoQuickLoad:
		game_manager.initialize_game()
