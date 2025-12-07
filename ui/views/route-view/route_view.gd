extends BoxContainer

class_name RouteView

const VISIBLE_ICON: Resource = preload("res://assets/ui_icons/visibility.png")
const HIDDEN_ICON: Resource = preload("res://assets/ui_icons/visibility_off.png")
const RouteStepItemScene = preload("res://ui/components/route-step-item/route_step_item.tscn")

var _line: TransportLine
@export var route_index: int

@onready var _route_visibility_button: Button = $Header/RouteVisibilityButton
@onready var steps_container: BoxContainer = $ScrollContainer/MarginContainer/StepsContainer
@onready var include_waypoints: CheckButton = $Header/IncludeWaypoints

@onready var _transport_manager: TransportManager = GDInjector.inject("TransportManager") as TransportManager
@onready var _game_manager: GameManager = GDInjector.inject("GameManager") as GameManager
@onready var _network_manager: NetworkManager = GDInjector.inject("NetworkManager") as NetworkManager

signal route_visibility_toggled(route_idx: int, is_visible: bool)


func _ready() -> void:
	_route_visibility_button.pressed.connect(Callable(self, "_on_route_visibility_button_pressed"))
	include_waypoints.toggled.connect(Callable(self, "_on_include_waypoints_toggled"))


func setup(transport_line: TransportLine) -> void:
	_route_visibility_button.icon = VISIBLE_ICON if _transport_manager.is_line_route_drawn(transport_line.id, route_index) else HIDDEN_ICON
	_line = transport_line
	_load_route_steps()


func _on_route_visibility_button_pressed() -> void:
	if _transport_manager.is_line_route_drawn(_line.id, route_index):
		_transport_manager.hide_line_route_drawing(_line, route_index)
		_route_visibility_button.icon = HIDDEN_ICON
		emit_signal("route_visibility_toggled", route_index, false)
	else:
		_transport_manager.draw_line_route(_line, route_index)
		_route_visibility_button.icon = VISIBLE_ICON
		emit_signal("route_visibility_toggled", route_index, true)


func _on_include_waypoints_toggled(_pressed: bool) -> void:
	_load_route_steps()


func _load_route_steps() -> void:
	for child in steps_container.get_children():
		child.queue_free()

	var route_steps = _line.get_route_steps(route_index)
	var should_include_waypoints = include_waypoints.button_pressed
	var accumulated_length: float = 0.0
	var accumulated_time: float = 0.0

	for i in range(route_steps.size()):
		var step = route_steps[i] as RouteStep

		if step.step_type == Enums.TransportRouteStepType.WAYPOINT and not should_include_waypoints:
			accumulated_length += step.length
			accumulated_time += step.time_for_step
			continue

		if i > 0:
			var spacer_item = RouteStepItemScene.instantiate() as RouteStepItem
			spacer_item.setup_as_spacer(
				_line.color_hex,
				accumulated_length + step.length,
				accumulated_time + step.time_for_step,
			)
			steps_container.add_child(spacer_item)

		var step_item = RouteStepItemScene.instantiate() as RouteStepItem
		step_item.setup(step.step_type, step.target_name, step.target_id, _line.color_hex)
		step_item.jump_to_target.connect(Callable(self, "_on_jump_to_button_pressed"))

		steps_container.add_child(step_item)

		if step.step_type != Enums.TransportRouteStepType.WAYPOINT:
			accumulated_length = 0.0
			accumulated_time = 0.0


func _on_jump_to_button_pressed(target_id: int, step_type: Enums.TransportRouteStepType) -> void:
	var selection_type = GameManager.SelectionType.NONE
	var selected_object: Object = null

	match step_type:
		Enums.TransportRouteStepType.STOP:
			var stop = _transport_manager.get_stop(target_id)
			if stop:
				var stop_selection = StopSelection.new(StopSelection.StopSelectionType.STOP, stop)
				selected_object = stop_selection
				selection_type = GameManager.SelectionType.TRANSPORT_STOP
		Enums.TransportRouteStepType.TERMINAL:
			var terminal = _transport_manager.get_terminal(target_id)
			if terminal:
				var terminal_peron = TerminalPeron.new(terminal, terminal.get_peron_for_line(_line.id))
				var stop_selection = StopSelection.new(StopSelection.StopSelectionType.TERMINAL_PERON, terminal_peron)
				selected_object = stop_selection
				selection_type = GameManager.SelectionType.TRANSPORT_STOP
		Enums.TransportRouteStepType.WAYPOINT:
			var node = _network_manager.get_node(target_id)
			if node:
				selected_object = node
				selection_type = GameManager.SelectionType.NODE

	_game_manager.set_selection(selected_object, selection_type)
	_game_manager.jump_to_selection()
