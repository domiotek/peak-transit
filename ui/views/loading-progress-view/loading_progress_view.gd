extends Control

class_name LoadingProgressView

var ui_manager: UIManager
var game_manager: GameManager

const VIEW_NAME: String = "LoadingProgressView"

@onready var title_label: Label = $MarginContainer/MainFlowContainer/HeaderBoxContainer/TitleLabel
@onready var action_label = $MarginContainer/MainFlowContainer/MainContentContainer/ActionName as Label
@onready var progress_bar = $MarginContainer/MainFlowContainer/MainContentContainer/ActionProgress as ProgressBar


func _ready() -> void:
	ui_manager = GDInjector.inject("UIManager") as UIManager
	game_manager = GDInjector.inject("GameManager") as GameManager

	visible = false
	ui_manager.register_ui_view(VIEW_NAME, self)


func _exit_tree() -> void:
	ui_manager.unregister_ui_view(VIEW_NAME)


func update(data: Dictionary) -> void:
	var title = data.get("title", "Loading")
	title_label.text = title

	var show_progressbar = data.get("show_progress_bar", false)
	progress_bar.visible = show_progressbar

	var action = data.get("action", "")

	update_progress(action, 0.0)


func update_progress(action: String, progress: float = 0.0) -> void:
	action_label.text = action

	if progress_bar.visible and progress >= 0.0:
		progress_bar.value = progress * 100
