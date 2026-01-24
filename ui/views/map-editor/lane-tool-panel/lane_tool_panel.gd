extends Panel

class_name LaneToolPanel

const VIEW_NAME: String = "LaneToolPanel"

var _ui_manager: UIManager = GDInjector.inject("UIManager") as UIManager
var _map_interactions_manager: MapInteractionsManager = GDInjector.inject("MapInteractionsManager") as MapInteractionsManager
var _tool_instance: EditLaneMapTool
var _active_speed_limit_button: Button = null

@onready var add_lane_tool_button: Button = $MarginContainer/MainContent/TypesContainer/AddLaneToolButton
@onready var remove_lane_tool_button: Button = $MarginContainer/MainContent/TypesContainer/RemoveLaneToolButton
@onready var directions_tool_button: Button = $MarginContainer/MainContent/TypesContainer/DirectionsToolButton

@onready var speed_limit_buttons: GridContainer = $MarginContainer/MainContent/SpeedContainer

@onready var hide_panel_button: Button = $MarginContainer/MainContent/HideButtonWrapper/HidePanelButton

@onready var _buttons = {
	EditLaneMapTool.EditLaneToolType.ADD_LANE: add_lane_tool_button,
	EditLaneMapTool.EditLaneToolType.REMOVE_LANE: remove_lane_tool_button,
	EditLaneMapTool.EditLaneToolType.CHANGE_DIRECTIONS: directions_tool_button,
}


func _ready() -> void:
	visible = false
	_ui_manager.register_ui_view(VIEW_NAME, self)

	_tool_instance = _map_interactions_manager.get_tool_instance(MapTools.MapEditorTool.EDIT_LANE) as EditLaneMapTool

	add_lane_tool_button.pressed.connect(_on_add_lane_tool_button_pressed)
	remove_lane_tool_button.pressed.connect(_on_remove_lane_tool_button_pressed)
	directions_tool_button.pressed.connect(_on_directions_tool_button_pressed)
	hide_panel_button.pressed.connect(_on_hide_panel_button_pressed)

	_setup_speed_limit_buttons()


func _exit_tree() -> void:
	_ui_manager.unregister_ui_view(VIEW_NAME)


func update(_data: Dictionary) -> void:
	if not _is_tool_active():
		return

	_update_ui_state()
	_reset_speed_limit_buttons()


func _on_add_lane_tool_button_pressed() -> void:
	_tool_instance.set_tool_type(EditLaneMapTool.EditLaneToolType.ADD_LANE)
	_update_ui_state()


func _on_remove_lane_tool_button_pressed() -> void:
	_tool_instance.set_tool_type(EditLaneMapTool.EditLaneToolType.REMOVE_LANE)
	_update_ui_state()


func _on_directions_tool_button_pressed() -> void:
	_tool_instance.set_tool_type(EditLaneMapTool.EditLaneToolType.CHANGE_DIRECTIONS)
	_update_ui_state()


func _on_hide_panel_button_pressed() -> void:
	_ui_manager.hide_ui_view(VIEW_NAME)


func _update_ui_state() -> void:
	var tool_type = _tool_instance.get_tool_type()

	if _active_speed_limit_button and tool_type != EditLaneMapTool.EditLaneToolType.CHANGE_SPEED_LIMIT:
		_active_speed_limit_button.flat = true
		_active_speed_limit_button = null

	for key in _buttons.keys():
		var button: Button = _buttons[key]
		if key == tool_type:
			button.flat = false
		else:
			button.flat = true


func _is_tool_active() -> bool:
	return _map_interactions_manager.get_active_tool() == MapTools.MapEditorTool.EDIT_LANE


func _setup_speed_limit_buttons() -> void:
	var button: Button
	var speed_limit = 20

	for child in speed_limit_buttons.get_children():
		if child is Button:
			button = child as Button
			button.set_meta("speed_limit", speed_limit)
			button.flat = true
			button.pressed.connect(_on_speed_limit_button_pressed.bind(button))

		speed_limit += 10

	button.set_meta("speed_limit", INF)


func _reset_speed_limit_buttons() -> void:
	if _active_speed_limit_button:
		_active_speed_limit_button.flat = true
		_active_speed_limit_button = null


func _on_speed_limit_button_pressed(button: Button) -> void:
	var speed_limit = button.get_meta("speed_limit") as int
	_tool_instance.set_speed_limit(speed_limit)

	if _active_speed_limit_button:
		_active_speed_limit_button.flat = true

	_active_speed_limit_button = button
	_active_speed_limit_button.flat = false

	_update_ui_state()
