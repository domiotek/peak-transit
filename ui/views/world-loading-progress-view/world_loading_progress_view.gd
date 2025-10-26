extends Control


var ui_manager: UIManager
var game_manager: GameManager

@onready var action_label = $MarginContainer/MainFlowContainer/MainContentContainer/ActionName as Label
@onready var progress_bar = $MarginContainer/MainFlowContainer/MainContentContainer/ActionProgress as ProgressBar


func _ready() -> void:
	ui_manager = GDInjector.inject("UIManager") as UIManager
	game_manager = GDInjector.inject("GameManager") as GameManager

	ui_manager.register_ui_view("WorldLoadingProgressView", self)
	visible = false
	game_manager.world_loading_progress.connect(update_progress)


func update_progress(action: String, progress: float) -> void:
	action_label.text = action
	progress_bar.value = progress * 100
