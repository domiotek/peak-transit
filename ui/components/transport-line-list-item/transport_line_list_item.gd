extends ListItem

class_name TransportLineListItem

const VISIBLE_ICON: Resource = preload("res://assets/ui_icons/visibility.png")
const HIDDEN_ICON: Resource = preload("res://assets/ui_icons/visibility_off.png")

var _line_color: Color = Color.WHITE

var transport_manager: TransportManager = GDInjector.inject("TransportManager") as TransportManager

@onready var line_color_rect: ColorRect = $LineColor
@onready var visibility_button: Button = $LineVisibilityButton


func _ready() -> void:
	super._ready()
	line_color_rect.color = _line_color

	visibility_button.pressed.connect(Callable(self, "_on_visibility_button_pressed"))


func set_color(color: Color) -> void:
	_line_color = color


func set_line_visibility(line_visible: bool) -> void:
	visibility_button.icon = VISIBLE_ICON if line_visible else HIDDEN_ICON


func _on_visibility_button_pressed() -> void:
	var item_data = get_data()
	var line = item_data.get("line", null) as TransportLine
	if line:
		if transport_manager.is_line_drawn(line.id):
			transport_manager.hide_line_route_drawings(line)
			visibility_button.icon = HIDDEN_ICON
		else:
			transport_manager.draw_line_routes(line)
			visibility_button.icon = VISIBLE_ICON
