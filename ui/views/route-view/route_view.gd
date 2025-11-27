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

	for i in range(route_steps.size()):
		var step = route_steps[i]

		if step.step_type == Enums.TransportRouteStepType.WAYPOINT and not should_include_waypoints:
			continue

		var step_item = RouteStepItemScene.instantiate() as RouteStepItem
		step_item.setup(step.step_type, step.target_name, step.target_id, _line.color_hex)

		steps_container.add_child(step_item)

		if i < route_steps.size() - 1:
			var spacer_item = RouteStepItemScene.instantiate() as RouteStepItem
			spacer_item.setup_as_spacer(_line.color_hex)
			steps_container.add_child(spacer_item)
