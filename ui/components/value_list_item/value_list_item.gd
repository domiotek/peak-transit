extends BoxContainer

class_name ValueListItem

var id: String
var init_label_text: String
var init_value_text: String

@onready var label = $Label
@onready var value_label = $Value

func _ready() -> void:
	label.text = init_label_text
	set_value(init_value_text)


func init_item(_id: String, label_text: String, value_text: String) -> void:
	self.id = _id
	init_label_text = label_text+":"
	init_value_text = value_text

func set_value(value_text: String) -> void:
	var int_value: int = value_text.to_int()

	value_label.text = str(int_value) if int_value != 0 else value_text
