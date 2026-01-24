extends Panel

class_name NewNameSaveDialog

const VIEW_NAME = "NewNameSaveDialog"

@onready var file_name: LineEdit = $Panel/MarginContainer/Wrapper/FileName
@onready var cancel_button: Button = $Panel/MarginContainer/Wrapper/Buttons/CancelButton
@onready var save_button: Button = $Panel/MarginContainer/Wrapper/Buttons/SaveButton

signal save_requested(new_file_name: String)
signal cancel_requested()

signal resolved()

@onready var ui_manager: UIManager = GDInjector.inject("UIManager") as UIManager


func _ready() -> void:
	visible = false
	ui_manager.register_ui_view(VIEW_NAME, self)
	cancel_button.pressed.connect(_on_cancel_button_pressed)
	save_button.pressed.connect(_on_save_button_pressed)


func _exit_tree() -> void:
	ui_manager.unregister_ui_view(VIEW_NAME)


func update(data: Dictionary) -> void:
	if data.has("file_name"):
		file_name.text = data["file_name"]


func _on_cancel_button_pressed() -> void:
	emit_signal("cancel_requested")
	emit_signal("resolved")


func _on_save_button_pressed() -> void:
	emit_signal("save_requested", file_name.text)
	emit_signal("resolved")
