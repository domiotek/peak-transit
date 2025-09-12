extends Control


@onready var toggle_button: Button = $CheckButton
@onready var label: Label = $Label


signal toggled(id: String, state: bool)


var init_label_text = ""
var init_toggle_state = false


func _ready() -> void:
	label.text = init_label_text
	toggle_button.button_pressed = init_toggle_state

	toggle_button.connect("toggled", Callable(self, "_on_toggle_button_toggled"))


func setup(caption: String, initial_value: bool) -> void:
	init_label_text = caption
	init_toggle_state = initial_value


func _on_toggle_button_toggled(button_pressed: bool) -> void:
	emit_signal("toggled", init_label_text, button_pressed)
