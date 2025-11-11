extends Node2D

class_name GameWindow

@onready var game_viewport: GameController = $Game
@onready var main_menu_ui: Control = $UI/MainMenu


func _ready() -> void:
	var ui_manager = GDInjector.inject("UIManager") as UIManager
	ui_manager.initialize(main_menu_ui, game_viewport)
