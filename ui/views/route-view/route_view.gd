extends BoxContainer

class_name RouteView

const VISIBLE_ICON: Resource = preload("res://assets/ui_icons/visibility.png")
const HIDDEN_ICON: Resource = preload("res://assets/ui_icons/visibility_off.png")

var _line: TransportLine
@export var route_index: int

@onready var _route_visibility_button: Button = $Header/RouteVisibilityButton
@onready var _transport_manager: TransportManager = GDInjector.inject("TransportManager") as TransportManager

signal route_visibility_toggled(route_idx: int, is_visible: bool)


func _ready() -> void:
	_route_visibility_button.pressed.connect(Callable(self, "_on_route_visibility_button_pressed"))


func setup(transport_line: TransportLine) -> void:
	_route_visibility_button.icon = VISIBLE_ICON if _transport_manager.is_line_route_drawn(transport_line.id, route_index) else HIDDEN_ICON
	_line = transport_line


func _on_route_visibility_button_pressed() -> void:
	if _transport_manager.is_line_route_drawn(_line.id, route_index):
		_transport_manager.hide_line_route_drawing(_line, route_index)
		_route_visibility_button.icon = HIDDEN_ICON
		emit_signal("route_visibility_toggled", route_index, false)
	else:
		_transport_manager.draw_line_route(_line, route_index)
		_route_visibility_button.icon = VISIBLE_ICON
		emit_signal("route_visibility_toggled", route_index, true)
