extends Control

class_name DepotPopupView

const VIEW_NAME = "DepotPopupView"

@onready var _ui_manager: UIManager = GDInjector.inject("UIManager") as UIManager
@onready var _game_manager: GameManager = GDInjector.inject("GameManager") as GameManager
@onready var _config_manager: ConfigManager = GDInjector.inject("ConfigManager") as ConfigManager

var _selected_depot: Depot = null
var _is_pinned: bool = false

var _data_items: Array = []

var _constraints_enabled: bool = true
var _max_bus_capacity = 0
var _max_articulated_bus_capacity = 0

var item_scene = preload("res://ui/components/value_list_item/value_list_item.tscn")

@onready var close_button: Button = $MarginContainer/MainFlowContainer/HeaderBoxContainer/CloseButton
@onready var pin_button: Button = $MarginContainer/MainFlowContainer/HeaderBoxContainer/PinButton
@onready var toggle_debug_button: Button = $MarginContainer/MainFlowContainer/ToolBoxPanel/ToggleDebugButton
@onready var debugger_button: Button = $MarginContainer/MainFlowContainer/ToolBoxPanel/DebuggerButton

@onready var id_label: Label = $MarginContainer/MainFlowContainer/HeaderBoxContainer/IdLabel

@onready var bus_counter_value: Label = $MarginContainer/MainFlowContainer/MainContentContainer/MarginContainer \
										/ContentWrapper/CountersWrapper/BusCounterWrapper/TopLine/Value
@onready var art_bus_counter_value: Label = $MarginContainer/MainFlowContainer/MainContentContainer/MarginContainer \
										/ContentWrapper/CountersWrapper/ArticulatedBusCounterWrapper/TopLine/Value

@onready var spawn_button: Button = $MarginContainer/MainFlowContainer/MainContentContainer/MarginContainer \
										/ContentWrapper/CountersWrapper/BusCounterWrapper/TopLine/SpawnButton
@onready var art_spawn_button: Button = $MarginContainer/MainFlowContainer/MainContentContainer/MarginContainer \
										/ContentWrapper/CountersWrapper/ArticulatedBusCounterWrapper/TopLine/SpawnButton

@onready var buses_counter: ProgressBar = $MarginContainer/MainFlowContainer/MainContentContainer/MarginContainer \
										/ContentWrapper/CountersWrapper/BusCounterWrapper/BusesCounter
@onready var articulated_buses_counter: ProgressBar = $MarginContainer/MainFlowContainer/MainContentContainer/MarginContainer \
										/ContentWrapper/CountersWrapper/ArticulatedBusCounterWrapper/ArticulatedBusesCounter

@onready var properties_container: BoxContainer = $MarginContainer/MainFlowContainer/MainContentContainer/MarginContainer/ContentWrapper/PropertiesContainer


func _ready() -> void:
	visible = false
	_ui_manager.register_ui_view(VIEW_NAME, self)

	close_button.pressed.connect(_on_close_button_pressed)
	toggle_debug_button.pressed.connect(_on_toggle_debug_button_pressed)
	debugger_button.pressed.connect(_on_debugger_button_pressed)
	pin_button.pressed.connect(_on_pin_button_toggled)
	_config_manager.DebugToggles.ToggleChanged.connect(_on_debug_toggle_changed)

	spawn_button.pressed.connect(_on_bus_spawn_button_pressed)
	art_spawn_button.pressed.connect(_on_articulated_bus_spawn_button_pressed)


func update(_data: Dictionary) -> void:
	if _game_manager.get_selection_type() != GameManager.SelectionType.DEPOT:
		_on_close_button_pressed()
		return

	_selected_depot = _game_manager.get_selected_object() as Depot
	_ui_manager.reanchor_to_world_object(self, _selected_depot, UIManager.AnchorPoint.BOTTOM_LEFT, _is_pinned)

	id_label.text = _selected_depot.get_depot_name()

	if _data_items.size() == 0:
		var data = _selected_depot.get_popup_data()
		for key in data.keys():
			var value = data[key]
			var item = item_scene.instantiate() as ValueListItem
			item.init_item(key, key.capitalize(), str(value))
			properties_container.add_child(item)
			_data_items.append(item)

	toggle_debug_button.flat = not _selected_depot.are_debug_visuals_enabled()

	_max_bus_capacity = _selected_depot.get_max_bus_capacity()
	_max_articulated_bus_capacity = _selected_depot.get_max_bus_capacity(true)

	buses_counter.max_value = _max_bus_capacity
	articulated_buses_counter.max_value = _max_articulated_bus_capacity


func _process(_delta: float) -> void:
	if visible and _selected_depot:
		var data = _selected_depot.get_popup_data()
		_ui_manager.reanchor_to_world_object(self, _selected_depot.get_anchor(), UIManager.AnchorPoint.BOTTOM_LEFT, _is_pinned)

		if _constraints_enabled:
			var current_bus_count = _selected_depot.get_current_bus_count()
			var current_articulated_bus_count = _selected_depot.get_current_bus_count(true)

			buses_counter.value = current_bus_count
			articulated_buses_counter.value = current_articulated_bus_count

			bus_counter_value.text = "%d / %d" % [current_bus_count, _max_bus_capacity]
			art_bus_counter_value.text = "%d / %d" % [current_articulated_bus_count, _max_articulated_bus_capacity]

			spawn_button.disabled = current_bus_count <= 0
			art_spawn_button.disabled = current_articulated_bus_count <= 0
		else:
			bus_counter_value.text = "∞ / ∞"
			art_bus_counter_value.text = "∞ / ∞"
			buses_counter.value = _max_bus_capacity
			articulated_buses_counter.value = _max_articulated_bus_capacity
			spawn_button.disabled = false
			art_spawn_button.disabled = false

		for i in range(_data_items.size()):
			var item = _data_items[i]
			item.set_value(str(data[item.id]))


func _on_close_button_pressed() -> void:
	_ui_manager.hide_ui_view(VIEW_NAME)
	_selected_depot = null
	_handle_pinned_button(false)


func _on_toggle_debug_button_pressed() -> void:
	_selected_depot.toggle_debug_visuals()
	toggle_debug_button.flat = not _selected_depot.are_debug_visuals_enabled()


func _on_debugger_button_pressed() -> void:
	_game_manager.debug_selection = not _game_manager.debug_selection


func _on_pin_button_toggled() -> void:
	_handle_pinned_button(not _is_pinned)


func _on_bus_spawn_button_pressed() -> void:
	if _selected_depot:
		_selected_depot.try_spawn(false)


func _on_articulated_bus_spawn_button_pressed() -> void:
	if _selected_depot:
		_selected_depot.try_spawn(true)


func _handle_pinned_button(active: bool) -> void:
	_is_pinned = active
	pin_button.icon = preload("res://assets/ui_icons/keep.png") if active else preload("res://assets/ui_icons/keep_off.png")


func _on_debug_toggle_changed(id: String, enabled: bool) -> void:
	if id == "IgnoreDepotConstraints":
		_constraints_enabled = not enabled
