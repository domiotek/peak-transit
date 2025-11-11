extends MarginContainer

class_name TrafficLightsView

var DEBUG_ICON: Resource = preload("res://assets/ui_icons/debugger.png")
var ITEM_SCENE = preload("res://ui/components/list_item/list_item.tscn")


@onready var id_label: Label = $BoxContainer/HeaderContainer/IdLabel
@onready var debug_button: Button = $BoxContainer/HeaderContainer/DebugButton

@onready var stoppers_list_container: BoxContainer = $BoxContainer/ScrollContainer/MarginContainer/Content/StoppersList/BoxContainer
@onready var phases_list_container: BoxContainer = $BoxContainer/ScrollContainer/MarginContainer/Content/PhasesList/BoxContainer


var node: RoadNode = null

var game_manager: GameManager = null

var is_bound: bool = false

func _ready() -> void:
	game_manager = GDInjector.inject("GameManager") as GameManager
	debug_button.pressed.connect(_on_debug_button_pressed)


func bind(node_to_bind: RoadNode) -> void:
	if not node_to_bind:
		push_error("Invalid RoadNode provided to bind")
		return

	node = node_to_bind
	is_bound = true
	id_label.text = "#%d" % node.id

	var stoppers = node.intersection_manager.get_stoppers_list()
	var custom_data = node.intersection_manager.get_custom_data()

	for stopper in stoppers:
		var item = ITEM_SCENE.instantiate() as ListItem
		item.init_item("#%d" % stopper.endpoint.Id, "Is blocking: %s" % stopper.is_active())
		item.set_data({"stopper": stopper})
		item.show_button(DEBUG_ICON)
		item.button_pressed.connect(Callable(self, "_on_stopper_debug_button_pressed"))
		stoppers_list_container.add_child(item)

	for phase_id in range(custom_data.get("phases", []).size()):
		var phase = custom_data["phases"][phase_id]
		var item = ITEM_SCENE.instantiate() as ListItem
		item.init_item("Phase #%d" % phase_id, "Duration: %ds (min %ds); Stoppers: %s; Directions: %s" % [phase.get("duration", 0), phase.get("min_duration", 0), _get_stoppers_string(phase.get("stoppers", []), phase.get("exception_stoppers", [])), _get_directions_string(phase.get("directions", []))])
		item.set_data({"phase_id": phase_id})
		phases_list_container.add_child(item)

func unbind() -> void:
	is_bound = false
	node = null
	_clear_list(stoppers_list_container)
	_clear_list(phases_list_container)

func _process(_delta: float) -> void:
	if not is_bound or not node:
		return

	for child in stoppers_list_container.get_children():
		var stopper = child.get_data().get("stopper", null)
		child.update_support_text("Is blocking: %s" % stopper.is_active())


	var custom_data = node.intersection_manager.get_custom_data()
	var active_phase = custom_data.get("current_phase_index", -1)
	for child in phases_list_container.get_children():
		var phase_id = child.get_data().get("phase_id", -1)
		var main_text = "Phase #%d" % phase_id
		if phase_id == active_phase:
			main_text += " (Active - %ds; Flow: %.2f)" % [custom_data.get("phase_timer", 0), custom_data.get("current_flow_ratio", 0)]
		child.update_main_text(main_text)

func _on_debug_button_pressed() -> void:
	if not is_bound or not node:
		return
	game_manager.set_selection(node, GameManager.SelectionType.NODE)
	game_manager.debug_selection = true

func _on_stopper_debug_button_pressed(_sender: ListItem, data: Dictionary) -> void:
	if not is_bound or not node:
		return

	game_manager.set_selection(data["stopper"], GameManager.SelectionType.STOPPER)
	game_manager.debug_selection = true


func _clear_list(container: BoxContainer) -> void:
	for child in container.get_children():
		child.queue_free()

func _get_stoppers_string(stoppers: Array, exception_stoppers: Array) -> String:
	var parts = []
	for stopper in stoppers:
		var part = str(stopper)
		parts.append(part)

	for ex_stopper in exception_stoppers:
		var part = "^" + str(ex_stopper)
		parts.append(part)

	return ", ".join(parts)

func _get_directions_string(directions: Array) -> String:
	var parts = []
	for direction in directions:
		parts.append(Enums.Direction.keys()[direction])
	return ", ".join(parts)
