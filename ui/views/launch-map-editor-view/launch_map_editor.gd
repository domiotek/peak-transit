extends Panel

@onready var go_back_button: Button = $PanelContainer/MarginContainer/MainContainer/ButtonsContainer/GoBackButton
@onready var create_new_button: Button = $PanelContainer/MarginContainer/MainContainer/ButtonsContainer/CreateNewButton
@onready var load_button: Button = $PanelContainer/MarginContainer/MainContainer/ButtonsContainer/LoadExistingButton

signal new_world_launch_requested()
signal load_existing_world_requested()


func _ready() -> void:
	go_back_button.connect("pressed", Callable(self, "_on_go_back_button_pressed"))
	create_new_button.connect("pressed", Callable(self, "_on_create_new_button_pressed"))
	load_button.connect("pressed", Callable(self, "_on_open_folder_button_pressed"))


func init() -> void:
	visible = true


func _on_go_back_button_pressed() -> void:
	visible = false


func _on_create_new_button_pressed() -> void:
	emit_signal("new_world_launch_requested")
	visible = false


func _on_open_folder_button_pressed() -> void:
	emit_signal("load_existing_world_requested")
	visible = false
