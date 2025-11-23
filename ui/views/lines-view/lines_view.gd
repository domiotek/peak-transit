extends PanelContainer

class_name LinesView

var item_scene = preload("res://ui/components/transport-line-list-item/transport_line_list_item.tscn")
const CHEVRON_RIGHT_ICON: Resource = preload("res://assets/ui_icons/chevron_right.png")
const VISIBLE_ICON: Resource = preload("res://assets/ui_icons/visibility.png")
const HIDDEN_ICON: Resource = preload("res://assets/ui_icons/visibility_off.png")

const VIEW_NAME = "LinesView"

var _selected_line_id: int = -1

var ui_manager: UIManager
var transport_manager: TransportManager

@onready var go_back_button: Button = $MainWrapper/HeaderMargins/HeaderFlex/GoBackButton
@onready var toggle_all_visibility_button: Button = $MainWrapper/HeaderMargins/HeaderFlex/ToggleAllVisibilityButton
@onready var main_list_wrapper: Control = $MainWrapper/MainScrollContainer
@onready var main_item_list: BoxContainer = $MainWrapper/MainScrollContainer/MarginContainer/ItemList
@onready var line_view: LineView = $MainWrapper/LineView


func _ready() -> void:
	ui_manager = GDInjector.inject("UIManager") as UIManager
	transport_manager = GDInjector.inject("TransportManager") as TransportManager

	visible = false
	ui_manager.register_ui_view(VIEW_NAME, self)

	go_back_button.pressed.connect(Callable(self, "_on_go_back_button_pressed"))
	toggle_all_visibility_button.pressed.connect(Callable(self, "_on_toggle_all_visibility_button_pressed"))


func load() -> void:
	var lines = transport_manager.get_lines()

	for line in lines:
		var item = item_scene.instantiate() as TransportLineListItem
		item.init_item(str(line.display_number))
		item.set_color(line.color_hex)
		item.set_data({ "line": line })
		item.show_button(CHEVRON_RIGHT_ICON)
		item.button_pressed.connect(Callable(self, "_on_item_button_pressed"))

		main_item_list.add_child(item)


func update(_data) -> void:
	if transport_manager.are_no_lines_drawn():
		toggle_all_visibility_button.icon = HIDDEN_ICON
	else:
		toggle_all_visibility_button.icon = VISIBLE_ICON

	for item in main_item_list.get_children():
		if item is TransportLineListItem:
			var line = item.get_data().get("line", null) as TransportLine
			if line:
				item.set_line_visibility(transport_manager.is_line_drawn(line.id))


func _on_item_button_pressed(_sender: ListItem, data: Dictionary) -> void:
	var line = data.get("line", null) as TransportLine
	if line:
		_selected_line_id = line.id
		line_view.visible = true
		main_list_wrapper.visible = false
		go_back_button.visible = true
		toggle_all_visibility_button.visible = false
		line_view.setup(line)


func _on_go_back_button_pressed() -> void:
	line_view.visible = false
	main_list_wrapper.visible = true
	go_back_button.visible = false
	toggle_all_visibility_button.visible = true
	_selected_line_id = -1
	update(null)


func _on_toggle_all_visibility_button_pressed() -> void:
	if transport_manager.are_all_lines_drawn():
		transport_manager.hide_all_line_drawings()
		toggle_all_visibility_button.icon = HIDDEN_ICON
		_set_all_lines_visibility(false)
	else:
		transport_manager.draw_all_lines()
		toggle_all_visibility_button.icon = VISIBLE_ICON
		_set_all_lines_visibility(true)


func _on_close_button_pressed() -> void:
	ui_manager.hide_ui_view(VIEW_NAME)


func _set_all_lines_visibility(line_visible: bool) -> void:
	for item in main_item_list.get_children():
		if item is TransportLineListItem:
			item.set_line_visibility(line_visible)
