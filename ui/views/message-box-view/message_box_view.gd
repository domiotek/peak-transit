extends Control

class_name MessageBoxView

const VIEW_NAME = "MessageBoxView"

@onready var title: Label = $PanelContainer/MarginContainer/MainContainer/Title
@onready var content_text: Label = $PanelContainer/MarginContainer/MainContainer/ContentWrapper/MarginContainer/ScrollContainer/ContentText
@onready var confirm_button: Button = $PanelContainer/MarginContainer/MainContainer/ButtonsContainer/ConfirmButton

var ui_manager: UIManager


func _ready() -> void:
	ui_manager = GDInjector.inject("UIManager") as UIManager

	visible = false
	ui_manager.register_ui_view(VIEW_NAME, self)
	confirm_button.pressed.connect(_on_confirm_button_pressed)


func update(data: Dictionary) -> void:
	if data.has("message"):
		content_text.text = data["message"]
	else:
		content_text.text = "Unspecified message."

	if data.has("title"):
		title.text = data["title"]
	else:
		title.text = "Message"

func _on_confirm_button_pressed() -> void:
	ui_manager.hide_ui_view(VIEW_NAME)
