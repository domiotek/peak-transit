extends Node2D

class_name GameWindow

@onready var main_menu_ui: Control = $UI/MainMenu


func _ready() -> void:
	var ui_manager = GDInjector.inject("UIManager") as UIManager
	var config_manager: ConfigManager = GDInjector.inject("ConfigManager") as ConfigManager
	var game_manager: GameManager = GDInjector.inject("GameManager") as GameManager

	game_manager.game_controller_registration.connect(Callable(self, "_on_game_registration_requested"))

	ui_manager.initialize(main_menu_ui)

	if config_manager.AutoQuickLoad:
		game_manager.initialize_game(Enums.GameMode.CHALLENGE)


func _on_game_registration_requested(game_controller: BaseGameController) -> void:
	self.add_child(game_controller)
