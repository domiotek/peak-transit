extends Panel

class_name RoadToolPanel

const VIEW_NAME: String = "RoadToolPanel"

@onready var straight_tool_button: Button = $MarginContainer/MainContent/TypesContainer/StraightToolButton
@onready var curve_tool_button: Button = $MarginContainer/MainContent/TypesContainer/CurveToolButton
@onready var hide_panel_button: Button = $MarginContainer/MainContent/HideButtonWrapper/HidePanelButton

var _ui_manager: UIManager = GDInjector.inject("UIManager") as UIManager
var _map_interactions_manager: MapInteractionsManager = GDInjector.inject("MapInteractionsManager") as MapInteractionsManager
var _tool_instance: PlaceRoadMapTool


func _ready() -> void:
	visible = false
	_ui_manager.register_ui_view(VIEW_NAME, self)

	_tool_instance = _map_interactions_manager.get_tool_instance(MapTools.MapEditorTool.PLACE_ROAD) as PlaceRoadMapTool

	straight_tool_button.pressed.connect(_on_straight_tool_button_pressed)
	curve_tool_button.pressed.connect(_on_curve_tool_button_pressed)
	hide_panel_button.pressed.connect(_on_hide_panel_button_pressed)


func _exit_tree() -> void:
	_ui_manager.unregister_ui_view(VIEW_NAME)


func update(_data: Dictionary) -> void:
	if not _is_tool_active():
		return

	match _tool_instance.get_tool_type():
		PlaceRoadMapTool.RoadToolType.STRAIGHT:
			straight_tool_button.flat = false
			curve_tool_button.flat = true
		PlaceRoadMapTool.RoadToolType.CURVED:
			curve_tool_button.flat = false
			straight_tool_button.flat = true


func _on_straight_tool_button_pressed() -> void:
	if not _is_tool_active():
		return

	_tool_instance.set_tool_type(PlaceRoadMapTool.RoadToolType.STRAIGHT)
	straight_tool_button.flat = false
	curve_tool_button.flat = true


func _on_curve_tool_button_pressed() -> void:
	if not _is_tool_active():
		return

	_tool_instance.set_tool_type(PlaceRoadMapTool.RoadToolType.CURVED)
	curve_tool_button.flat = false
	straight_tool_button.flat = true


func _on_hide_panel_button_pressed() -> void:
	_ui_manager.hide_ui_view(VIEW_NAME)


func _is_tool_active() -> bool:
	return _map_interactions_manager.get_active_tool() == MapTools.MapEditorTool.PLACE_ROAD
