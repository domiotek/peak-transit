extends BoxContainer

class_name RouteStepItem

const StopIcon: Resource = preload("res://assets/ui_icons/route_step.png")
const TerminalIcon: Resource = preload("res://assets/ui_icons/terminal.png")
const SpacerIcon: Resource = preload("res://assets/ui_icons/route_arrow.png")
const WaypointIcon: Resource = preload("res://assets/ui_icons/route_middle.png")

var _set: bool = false
var _step_type: Enums.TransportRouteStepType
var _name: String
var _target_id: int
var _color: Color = Color.WHITE
var _length: float = 0.0
var _time: float = 0.0

@onready var _texture_rect: TextureRect = $TextureRect
@onready var _element_name: Label = $BoxContainer/Name
@onready var _element_type: Label = $BoxContainer/Type
@onready var _jump_to_button: Button = $JumpToButton
@onready var _trip_props_label: Label = $Spacer/TripPropertiesLabel

signal jump_to_target(target_id: int, step_type: Enums.TransportRouteStepType)


func _ready() -> void:
	if not _set:
		_jump_to_button.visible = false
		_texture_rect.texture = SpacerIcon
	else:
		_jump_to_button.pressed.connect(Callable(self, "_on_jump_to_button_pressed"))
		_texture_rect.texture = _select_icon_texture(_step_type)
		_element_type.text = _get_step_type_name(_step_type)

	_element_name.text = _name
	_texture_rect.modulate = _color

	if _length > 0.0:
		_trip_props_label.text = "%.1f px - %d min" % [_length, _time]


func setup(step_type: Enums.TransportRouteStepType, title: String, id: int, color: Color) -> void:
	_set = true
	_step_type = step_type
	_name = title
	_target_id = id
	_color = color


func setup_as_spacer(color: Color, length: float, time: float) -> void:
	_color = color
	_length = length
	_time = time


func _on_jump_to_button_pressed() -> void:
	emit_signal("jump_to_target", _target_id, _step_type)


func _select_icon_texture(step_type: int) -> Resource:
	match step_type:
		Enums.TransportRouteStepType.STOP:
			return StopIcon
		Enums.TransportRouteStepType.TERMINAL:
			return TerminalIcon
		Enums.TransportRouteStepType.WAYPOINT:
			return WaypointIcon
		_:
			return SpacerIcon


func _get_step_type_name(step_type: int) -> String:
	match step_type:
		Enums.TransportRouteStepType.STOP:
			return "Stop"
		Enums.TransportRouteStepType.TERMINAL:
			return "Terminal"
		Enums.TransportRouteStepType.WAYPOINT:
			return "Waypoint"
		_:
			return ""
