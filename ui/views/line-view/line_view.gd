extends Control

class_name LineView

const VISIBLE_ICON: Resource = preload("res://assets/ui_icons/visibility.png")
const HIDDEN_ICON: Resource = preload("res://assets/ui_icons/visibility_off.png")

var _line_object: TransportLine
var _drawn_routes: Array = []

@onready var transport_manager: TransportManager = GDInjector.inject("TransportManager") as TransportManager

@onready var toggle_line_visibility: Button = $MarginContainer/MainWrapper/Header/ToggleLineVisibility
@onready var line_color: ColorRect = $MarginContainer/MainWrapper/Header/LineColor
@onready var line_number: Label = $MarginContainer/MainWrapper/Header/LineNumber

@onready var route_0: RouteView = $"MarginContainer/MainWrapper/LineDetailsMargin/LineDetailsContent/RoutesWrapper/Route 0"
@onready var route_1: RouteView = $"MarginContainer/MainWrapper/LineDetailsMargin/LineDetailsContent/RoutesWrapper/Route 1"


func _ready() -> void:
	toggle_line_visibility.pressed.connect(Callable(self, "_on_toggle_line_visibility_pressed"))
	route_0.connect("route_visibility_toggled", Callable(self, "_on_route_visibility_toggled"))
	route_1.connect("route_visibility_toggled", Callable(self, "_on_route_visibility_toggled"))


func setup(line: TransportLine) -> void:
	_line_object = line
	line_color.color = _line_object.color_hex
	line_number.text = str(_line_object.display_number)

	var drawn_routes = transport_manager.get_drawn_routes_for_line(_line_object.id)
	_drawn_routes = drawn_routes
	toggle_line_visibility.icon = VISIBLE_ICON if drawn_routes.size() > 0 else HIDDEN_ICON

	route_0.setup(_line_object)
	route_1.setup(_line_object)


func _on_toggle_line_visibility_pressed() -> void:
	if transport_manager.is_line_drawn(_line_object.id):
		transport_manager.hide_line_route_drawings(_line_object)
		toggle_line_visibility.icon = HIDDEN_ICON
	else:
		transport_manager.draw_line_routes(_line_object)
		toggle_line_visibility.icon = VISIBLE_ICON


func _on_route_visibility_toggled(route_idx: int, route_visible: bool) -> void:
	if route_visible:
		if not _drawn_routes.has(route_idx):
			_drawn_routes.append(route_idx)
	else:
		if _drawn_routes.has(route_idx):
			_drawn_routes.erase(route_idx)

	if _drawn_routes.size() > 0:
		toggle_line_visibility.icon = VISIBLE_ICON
	else:
		toggle_line_visibility.icon = HIDDEN_ICON
