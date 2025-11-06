extends BoxContainer

class_name ListItem

var init_main_text: String
var init_support_text: String
var init_value_text: String
var init_icon: Resource
var data: Dictionary = {}

@onready var label = $BoxContainer/MainLabel
@onready var support_label = $BoxContainer/SupportLabel
@onready var button = $Button

signal button_pressed(sender_self: ListItem, data: Dictionary)

func _ready() -> void:
	label.text = init_main_text
	support_label.text = init_support_text

	if init_icon:
		button.icon = init_icon
		button.visible = true
		button.focus_mode = FocusMode.FOCUS_NONE
		button.pressed.connect(_on_debug_button_pressed)


func init_item(main_text: String, support_text: String="") -> void:
	init_main_text = main_text
	init_support_text = support_text

func show_button(image: Resource) -> void:
	init_icon = image

func disable_button(disabled: bool) -> void:
	button.disabled = disabled

func set_data(data_dict: Dictionary) -> void:
	data = data_dict

func get_data() -> Dictionary:
	return data

func update_main_text(new_text: String="") -> void:
	if not label:
		return
	label.text = new_text

func update_support_text(new_text: String="") -> void:
	if not support_label:
		return
	support_label.text = new_text

func _on_debug_button_pressed() -> void:
	emit_signal("button_pressed", self, data)
