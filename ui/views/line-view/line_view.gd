extends Control

class_name LineView

const VISIBLE_ICON: Resource = preload("res://assets/ui_icons/visibility.png")
const HIDDEN_ICON: Resource = preload("res://assets/ui_icons/visibility_off.png")

var _line_object: TransportLine
var _drawn_routes: Array = []

@onready var transport_manager: TransportManager = GDInjector.inject("TransportManager") as TransportManager
@onready var ui_manager: UIManager = GDInjector.inject("UIManager") as UIManager

@onready var toggle_line_visibility: Button = $MarginContainer/MainWrapper/Header/ToggleLineVisibility
@onready var line_color: ColorRect = $MarginContainer/MainWrapper/Header/LineColor
@onready var line_number: Label = $MarginContainer/MainWrapper/Header/LineNumber

@onready var route_0: RouteView = $"MarginContainer/MainWrapper/LineDetailsMargin/LineDetailsContent/TabContainer/Routes/RouteTabs/Forward"
@onready var route_1: RouteView = $"MarginContainer/MainWrapper/LineDetailsMargin/LineDetailsContent/TabContainer/Routes/RouteTabs/Return"

@onready var brigade_list: BrigadeList = $"MarginContainer/MainWrapper/LineDetailsMargin/LineDetailsContent/TabContainer/Brigades/BrigadeList"
@onready var service_time: ValueListItem = $"MarginContainer/MainWrapper/LineDetailsMargin/LineDetailsContent/PropsContainer/ServiceTimeProp"
@onready var frequency: ValueListItem = $"MarginContainer/MainWrapper/LineDetailsMargin/LineDetailsContent/PropsContainer/FrequencyProp"


func _ready() -> void:
	toggle_line_visibility.pressed.connect(Callable(self, "_on_toggle_line_visibility_pressed"))
	route_0.connect("route_visibility_toggled", Callable(self, "_on_route_visibility_toggled"))
	route_1.connect("route_visibility_toggled", Callable(self, "_on_route_visibility_toggled"))
	brigade_list.item_button_pressed.connect(Callable(self, "_on_brigade_list_item_button_pressed"))


func setup(line: TransportLine) -> void:
	_line_object = line
	line_color.color = _line_object.color_hex
	line_number.text = str(_line_object.display_number)

	service_time.set_value(
		"%s - %s" % [_line_object.get_start_time().format(), _line_object.get_end_time().format()],
		true,
	)
	frequency.set_value(
		"%d minutes" % _line_object.get_frequency_minutes(),
		true,
	)

	var drawn_routes = transport_manager.get_drawn_routes_for_line(_line_object.id)
	_drawn_routes = drawn_routes
	toggle_line_visibility.icon = VISIBLE_ICON if drawn_routes.size() > 0 else HIDDEN_ICON

	route_0.setup(_line_object)
	route_1.setup(_line_object)
	brigade_list.display_items(_line_object.get_brigades())


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


func _on_brigade_list_item_button_pressed(_sender: ListItem, data: Dictionary) -> void:
	var brigade = data.get("brigade", null) as Brigade
	if brigade:
		ui_manager.show_ui_view_exclusively(ShortcutsView.SHORTCUTS_VIEW_GROUP, BrigadesView.VIEW_NAME, { "brigade": brigade })
