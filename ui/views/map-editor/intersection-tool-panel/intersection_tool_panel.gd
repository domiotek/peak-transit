extends Panel

class_name IntersectionToolPanel

const VIEW_NAME: String = "IntersectionToolPanel"

var _ui_manager: UIManager = GDInjector.inject("UIManager") as UIManager
var _map_interactions_manager: MapInteractionsManager = GDInjector.inject("MapInteractionsManager") as MapInteractionsManager

var _tool_instance: IntersectionsMapTool

@onready var traffic_lights_button: Button = $MarginContainer/MainWrapper/Buttons/TrafficLightsButton
@onready var traffic_signs_button: Button = $MarginContainer/MainWrapper/Buttons/TrafficSignsButton

@onready var hide_panel_button: Button = $MarginContainer/MainWrapper/HideButtonWrapper/HidePanelButton

@onready var buttons = {
	IntersectionsMapTool.IntersectionToolType.TRAFFIC_LIGHT: traffic_lights_button,
	IntersectionsMapTool.IntersectionToolType.PRIORITY_SIGN: traffic_signs_button,
}


func _ready() -> void:
	visible = false
	_ui_manager.register_ui_view(VIEW_NAME, self)

	_tool_instance = _map_interactions_manager.get_tool_instance(MapTools.MapEditorTool.INTERSECTIONS) as IntersectionsMapTool

	_setup_buttons()

	hide_panel_button.pressed.connect(_on_hide_panel_button_pressed)


func _exit_tree() -> void:
	_ui_manager.unregister_ui_view(VIEW_NAME)


func update(_data: Dictionary) -> void:
	_update_ui_state()


func _setup_buttons() -> void:
	for intersection_type in buttons:
		var button = buttons[intersection_type]
		button.set_meta("intersection_type", intersection_type)
		button.flat = true
		button.pressed.connect(_on_button_pressed.bind(button))


func _update_ui_state() -> void:
	var active_intersection_type = _tool_instance.get_intersection_type()

	for intersection_type in buttons:
		var button = buttons[intersection_type]
		button.flat = active_intersection_type != intersection_type


func _on_button_pressed(button: Button) -> void:
	var intersection_type: IntersectionsMapTool.IntersectionToolType = button.get_meta("intersection_type")
	_tool_instance.set_intersection_type(intersection_type)
	_update_ui_state()


func _on_hide_panel_button_pressed() -> void:
	_ui_manager.hide_ui_view(VIEW_NAME)
