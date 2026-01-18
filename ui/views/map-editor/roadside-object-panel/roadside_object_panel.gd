extends Panel

class_name RoadSideObjectPanel

const VIEW_NAME: String = "RoadSideObjectPanel"

var _ui_manager: UIManager = GDInjector.inject("UIManager") as UIManager
var _map_interactions_manager: MapInteractionsManager = GDInjector.inject("MapInteractionsManager") as MapInteractionsManager

var _tool_instance: PlaceRoadSideObjectMapTool

@onready var residential_button: Button = $MarginContainer/MainWrapper/Buttons/Residential
@onready var commercial_button: Button = $MarginContainer/MainWrapper/Buttons/Commercial
@onready var industrial_button: Button = $MarginContainer/MainWrapper/Buttons/Industrial
@onready var depot_button: Button = $MarginContainer/MainWrapper/Buttons/Depot
@onready var terminal_button: Button = $MarginContainer/MainWrapper/Buttons/Terminal
@onready var stop_button: Button = $MarginContainer/MainWrapper/Buttons/Stop

@onready var hide_panel_button: Button = $MarginContainer/MainWrapper/HideButtonWrapper/HidePanelButton

@onready var buttons = {
	PlaceRoadSideObjectMapTool.RoadSideObjectType.RESIDENTIAL_BUILDING: residential_button,
	PlaceRoadSideObjectMapTool.RoadSideObjectType.COMMERCIAL_BUILDING: commercial_button,
	PlaceRoadSideObjectMapTool.RoadSideObjectType.INDUSTRIAL_BUILDING: industrial_button,
	PlaceRoadSideObjectMapTool.RoadSideObjectType.DEPOT: depot_button,
	PlaceRoadSideObjectMapTool.RoadSideObjectType.TERMINAL: terminal_button,
	PlaceRoadSideObjectMapTool.RoadSideObjectType.STOP: stop_button,
}


func _ready() -> void:
	visible = false
	_ui_manager.register_ui_view(VIEW_NAME, self)

	_tool_instance = _map_interactions_manager.get_tool_instance(MapTools.MapEditorTool.PLACE_ROADSIDE) as PlaceRoadSideObjectMapTool

	_setup_buttons()

	hide_panel_button.pressed.connect(_on_hide_panel_button_pressed)


func _exit_tree() -> void:
	_ui_manager.unregister_ui_view(VIEW_NAME)


func update(_data: Dictionary) -> void:
	_update_ui_state()


func _setup_buttons() -> void:
	for object_type in buttons:
		var button = buttons[object_type]
		button.set_meta("object_type", object_type)
		button.flat = true
		button.pressed.connect(_on_button_pressed.bind(button))


func _update_ui_state() -> void:
	var active_object_type = _tool_instance.get_object_type()

	for object_type in buttons:
		var button = buttons[object_type]
		button.flat = active_object_type != object_type


func _on_button_pressed(button: Button) -> void:
	var object_type: PlaceRoadSideObjectMapTool.RoadSideObjectType = button.get_meta("object_type")
	_tool_instance.set_object_type(object_type)
	_update_ui_state()


func _on_hide_panel_button_pressed() -> void:
	_ui_manager.hide_ui_view(VIEW_NAME)
