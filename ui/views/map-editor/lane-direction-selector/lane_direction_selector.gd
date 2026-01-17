extends Panel

class_name LaneDirectionSelector

const VIEW_NAME: String = "LaneDirectionSelector"

enum ButtonType {
	MAIN,
	CAR,
	BUS,
}

var up_icon = preload("res://assets/ui_icons/chevron_up.png")
var down_icon = preload("res://assets/ui_icons/chevron_down.png")

@onready var expand_button: Button = $MarginContainer/MainWrapper/MainButtons/ExpandButton
@onready var left_button: Button = $MarginContainer/MainWrapper/MainButtons/LeftButton
@onready var forward_button: Button = $MarginContainer/MainWrapper/MainButtons/ForwardButton
@onready var right_button: Button = $MarginContainer/MainWrapper/MainButtons/RightButton

@onready var car_buttons_container: BoxContainer = $MarginContainer/MainWrapper/CarButtons
@onready var left_car_button: Button = $MarginContainer/MainWrapper/CarButtons/LeftButton
@onready var forward_car_button: Button = $MarginContainer/MainWrapper/CarButtons/ForwardButton
@onready var right_car_button: Button = $MarginContainer/MainWrapper/CarButtons/RightButton

@onready var bus_buttons_container: BoxContainer = $MarginContainer/MainWrapper/BusButtons
@onready var left_bus_button: Button = $MarginContainer/MainWrapper/BusButtons/LeftButton
@onready var forward_bus_button: Button = $MarginContainer/MainWrapper/BusButtons/ForwardButton
@onready var right_bus_button: Button = $MarginContainer/MainWrapper/BusButtons/RightButton

@onready var _ui_manager: UIManager = GDInjector.inject("UIManager") as UIManager
@onready var _map_interactions_manager: MapInteractionsManager = GDInjector.inject("MapInteractionsManager") as MapInteractionsManager
var _tool_instance: EditLaneMapTool

var _anchor_position: Vector2 = Vector2.ZERO
var _button_states: Dictionary = {
	ButtonType.MAIN: [],
	ButtonType.CAR: [],
	ButtonType.BUS: [],
}

var _expanded: bool = false

@onready var buttons = {
	ButtonType.MAIN: [left_button, forward_button, right_button],
	ButtonType.CAR: [left_car_button, forward_car_button, right_car_button],
	ButtonType.BUS: [left_bus_button, forward_bus_button, right_bus_button],
}


func _ready() -> void:
	visible = false
	_ui_manager.register_ui_view(VIEW_NAME, self)

	_tool_instance = _map_interactions_manager.get_tool_instance(MapTools.MapEditorTool.EDIT_LANE) as EditLaneMapTool

	expand_button.pressed.connect(_on_expand_button_pressed)

	_prepare_buttons(buttons[ButtonType.MAIN], ButtonType.MAIN)
	_prepare_buttons(buttons[ButtonType.CAR], ButtonType.CAR)
	_prepare_buttons(buttons[ButtonType.BUS], ButtonType.BUS)


func _exit_tree() -> void:
	_ui_manager.unregister_ui_view(VIEW_NAME)


func update(data: Dictionary) -> void:
	_anchor_position = data.get("anchor_position", Vector2.ZERO)
	_button_states = _coerce_initial_states(data.get("initial_states"))
	_normalize_states()
	_enforce_blocked_columns()
	_update_buttons()
	_expanded = true
	_on_expand_button_pressed()


func _process(_delta: float) -> void:
	if not visible:
		return

	_ui_manager.reanchor_to_world_position(self, _anchor_position, UIManager.AnchorPoint.CENTER, false)


func _prepare_buttons(target_buttons: Array, tag: ButtonType) -> void:
	for idx in range(target_buttons.size()):
		var button: Button = target_buttons[idx]
		button.set_meta("type", tag)

		match idx:
			EditLaneMapTool.LaneDirection.LEFT:
				button.pressed.connect(_on_left_button_pressed.bind(button))
			EditLaneMapTool.LaneDirection.FORWARD:
				button.pressed.connect(_on_forward_button_pressed.bind(button))
			EditLaneMapTool.LaneDirection.RIGHT:
				button.pressed.connect(_on_right_button_pressed.bind(button))


func _on_expand_button_pressed() -> void:
	_expanded = not _expanded

	expand_button.icon = up_icon if _expanded else down_icon

	car_buttons_container.visible = _expanded
	bus_buttons_container.visible = _expanded
	self.size = Vector2(155, 115) if _expanded else Vector2(155, 41)


func _on_left_button_pressed(button: Button) -> void:
	_handle_button_press(button.get_meta("type"), EditLaneMapTool.LaneDirection.LEFT)


func _on_forward_button_pressed(button: Button) -> void:
	_handle_button_press(button.get_meta("type"), EditLaneMapTool.LaneDirection.FORWARD)


func _on_right_button_pressed(button: Button) -> void:
	_handle_button_press(button.get_meta("type"), EditLaneMapTool.LaneDirection.RIGHT)


func _handle_button_press(type: ButtonType, direction: EditLaneMapTool.LaneDirection) -> void:
	if _is_blocked(type, direction):
		return

	if type == ButtonType.MAIN:
		_toggle_column(direction)
	else:
		_toggle_single(type, direction)
		_sync_main(direction)

	_update_buttons()
	_tool_instance.apply_lane_direction_changes(_button_states)


func _toggle_column(direction: int) -> void:
	var main_state = _button_states[ButtonType.MAIN][direction]
	var new_state: EditLaneMapTool.LaneDirectionState = (
		EditLaneMapTool.LaneDirectionState.ENABLED
		if main_state != EditLaneMapTool.LaneDirectionState.ENABLED
		else EditLaneMapTool.LaneDirectionState.DISABLED
	)

	for type in _get_button_types():
		if _is_blocked(type, direction):
			continue
		_button_states[type][direction] = new_state


func _toggle_single(type: ButtonType, direction: int) -> void:
	var state: EditLaneMapTool.LaneDirectionState = _button_states[type][direction]
	if state == EditLaneMapTool.LaneDirectionState.BLOCKED:
		return

	_button_states[type][direction] = (
		EditLaneMapTool.LaneDirectionState.ENABLED
		if state == EditLaneMapTool.LaneDirectionState.DISABLED
		else EditLaneMapTool.LaneDirectionState.DISABLED
	)


func _sync_main(direction: int) -> void:
	if _is_blocked(ButtonType.MAIN, direction):
		return

	var car_state = _button_states[ButtonType.CAR][direction]
	var bus_state = _button_states[ButtonType.BUS][direction]
	var any_enabled = car_state == EditLaneMapTool.LaneDirectionState.ENABLED or bus_state == EditLaneMapTool.LaneDirectionState.ENABLED

	_button_states[ButtonType.MAIN][direction] = (
		EditLaneMapTool.LaneDirectionState.ENABLED if any_enabled else EditLaneMapTool.LaneDirectionState.DISABLED
	)


func _normalize_states() -> void:
	for type in _get_button_types():
		var states: Array = _button_states.get(type, [])
		states = states.duplicate()
		while states.size() < EditLaneMapTool.LaneDirection.values().size():
			states.append(EditLaneMapTool.LaneDirectionState.DISABLED)
		_button_states[type] = states


func _coerce_initial_states(raw: Variant) -> Dictionary:
	var result: Dictionary = { }

	for type in _get_button_types():
		var states: Variant = (raw as Dictionary).get(type, [])
		result[type] = (states as Array).duplicate(true)

	return result


func _enforce_blocked_columns() -> void:
	for direction in range(EditLaneMapTool.LaneDirection.values().size()):
		if _column_has_blocked(direction):
			_set_column_blocked(direction)


func _column_has_blocked(direction: int) -> bool:
	for type in _get_button_types():
		if _button_states[type][direction] == EditLaneMapTool.LaneDirectionState.BLOCKED:
			return true
	return false


func _set_column_blocked(direction: int) -> void:
	for type in _get_button_types():
		_button_states[type][direction] = EditLaneMapTool.LaneDirectionState.BLOCKED


func _is_blocked(type: ButtonType, direction: int) -> bool:
	return _button_states[type][direction] == EditLaneMapTool.LaneDirectionState.BLOCKED


func _update_buttons() -> void:
	for type in _get_button_types():
		var states: Array = _button_states[type]
		for direction in range(EditLaneMapTool.LaneDirection.values().size()):
			_update_button_state(buttons[type][direction], states[direction])


func _update_button_state(button: Button, state: EditLaneMapTool.LaneDirectionState) -> void:
	match state:
		EditLaneMapTool.LaneDirectionState.ENABLED:
			button.disabled = false
			button.flat = false
		EditLaneMapTool.LaneDirectionState.DISABLED:
			button.disabled = false
			button.flat = true
		EditLaneMapTool.LaneDirectionState.BLOCKED:
			button.disabled = true
			button.flat = true


func _get_button_types() -> Array:
	return buttons.keys()
