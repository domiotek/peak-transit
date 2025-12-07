extends ColorRect

class_name LineTag

@onready var label = $Label

var _line_id: int = 0
var _line_number = 0
var _line_color: Color = Color.TRANSPARENT

signal clicked(line_number: int)


func _ready() -> void:
	color = _line_color
	label.text = str(_line_number)
	var luminance = 0.299 * _line_color.r + 0.587 * _line_color.g + 0.114 * _line_color.b
	var contrast_color = Color.WHITE if luminance < 0.5 else Color.BLACK
	label.label_settings.font_color = contrast_color


func init(line_id: int, line_number: int, line_color: Color) -> void:
	_line_id = line_id
	_line_number = line_number
	_line_color = line_color


func update(line_id: int, line_number: int, line_color: Color) -> void:
	_line_id = line_id
	_line_number = line_number
	_line_color = line_color
	_ready()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton \
	and event.button_index == MOUSE_BUTTON_LEFT \
	and event.pressed:
		emit_signal("clicked", _line_id)
