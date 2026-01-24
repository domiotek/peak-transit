extends Panel

class_name ConfirmOverwriteDialog

const VIEW_NAME = "ConfirmOverwriteDialog"
@onready var cancel_button: Button = $Panel/MarginContainer/Wrapper/Buttons/CancelButton
@onready var overwrite_button: Button = $Panel/MarginContainer/Wrapper/Buttons/OverwriteButton

signal overwrite_confirmed()
signal overwrite_canceled()

signal resolved()

@onready var ui_manager: UIManager = GDInjector.inject("UIManager") as UIManager


func _ready() -> void:
	visible = false
	ui_manager.register_ui_view(VIEW_NAME, self)
	cancel_button.pressed.connect(_on_cancel_button_pressed)
	overwrite_button.pressed.connect(_on_overwrite_button_pressed)


func _exit_tree() -> void:
	ui_manager.unregister_ui_view(VIEW_NAME)


func _on_cancel_button_pressed() -> void:
	emit_signal("overwrite_canceled")
	emit_signal("resolved")


func _on_overwrite_button_pressed() -> void:
	emit_signal("overwrite_confirmed")
	emit_signal("resolved")
