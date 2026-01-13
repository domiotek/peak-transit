extends Panel

class_name MapEditorToolsBar

const VIEW_NAME: String = "MapEditorToolsBar"

@onready var road_tool_button: Button = $MarginContainer/BoxContainer/RoadToolButton
@onready var buldoze_tool_button: Button = $MarginContainer/BoxContainer/BuldozeToolButton

var _game_manager: GameManager = GDInjector.inject("GameManager") as GameManager
var _ui_manager: UIManager = GDInjector.inject("UIManager") as UIManager
var _map_interactions_manager = GDInjector.inject("MapInteractionsManager") as MapInteractionsManager

var _active_button: Button = null
var _active_panel_name: String = ""


func _ready() -> void:
	if _game_manager.get_game_mode() != Enums.GameMode.MAP_EDITOR:
		visible = false
		return
	visible = false

	_ui_manager.register_ui_view(VIEW_NAME, self)
	_map_interactions_manager.tool_changed.connect(Callable(self, "_on_active_tool_changed"))

	road_tool_button.pressed.connect(_on_road_tool_button_pressed)
	buldoze_tool_button.pressed.connect(_on_buldoze_tool_button_pressed)


func _exit_tree() -> void:
	_ui_manager.unregister_ui_view(VIEW_NAME)


func _on_active_tool_changed(new_tool: MapTools.MapEditorTool) -> void:
	if new_tool == MapTools.MapEditorTool.NONE:
		if _active_button:
			_active_button.flat = true

		if _active_panel_name != "":
			_ui_manager.hide_ui_view(_active_panel_name)
			_active_panel_name = ""

		_active_button = null


func _on_road_tool_button_pressed() -> void:
	if _is_active_tool(MapTools.MapEditorTool.PLACE_ROAD):
		if _ui_manager.is_ui_view_visible(RoadToolPanel.VIEW_NAME):
			_map_interactions_manager.set_active_tool(MapTools.MapEditorTool.NONE)
			return
		_ui_manager.show_ui_view(RoadToolPanel.VIEW_NAME)
		return

	_set_active_tool(MapTools.MapEditorTool.PLACE_ROAD, road_tool_button)


func _on_buldoze_tool_button_pressed() -> void:
	if _is_active_tool(MapTools.MapEditorTool.BULDOZE):
		_map_interactions_manager.set_active_tool(MapTools.MapEditorTool.NONE)
		return

	_set_active_tool(MapTools.MapEditorTool.BULDOZE, buldoze_tool_button)


func _set_active_tool(tool: MapTools.MapEditorTool, button: Button) -> void:
	_map_interactions_manager.set_active_tool(tool)
	button.flat = false

	if _active_button and _active_button != button:
		_active_button.flat = true

	if _active_panel_name != "":
		_ui_manager.hide_ui_view(_active_panel_name)
		_active_panel_name = ""

	_active_button = button

	match tool:
		MapTools.MapEditorTool.PLACE_ROAD:
			_ui_manager.show_ui_view(RoadToolPanel.VIEW_NAME)
			_active_panel_name = RoadToolPanel.VIEW_NAME
		_:
			pass


func _is_active_tool(tool: MapTools.MapEditorTool) -> bool:
	return _map_interactions_manager.get_active_tool() == tool
