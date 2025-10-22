extends Control


var ui_manager: UIManager
var game_manager: GameManager

var selected_building: SpawnerBuilding = null
var is_pinned: bool = false

var data_items: Array = []

var item_scene = preload("res://ui/components/value_list_item/value_list_item.tscn")


@onready var close_button: Button = $MarginContainer/MainFlowContainer/HeaderBoxContainer/CloseButton
@onready var pin_button: Button = $MarginContainer/MainFlowContainer/HeaderBoxContainer/PinButton
@onready var toggle_debug_button: Button = $MarginContainer/MainFlowContainer/ToolBoxPanel/ToggleDebugButton
@onready var spawn_car_button: Button = $MarginContainer/MainFlowContainer/ToolBoxPanel/SpawnCarButton
@onready var debugger_button: Button = $MarginContainer/MainFlowContainer/ToolBoxPanel/DebuggerButton

@onready var id_label: Label = $MarginContainer/MainFlowContainer/HeaderBoxContainer/IdLabel

@onready var properties_container: BoxContainer = $MarginContainer/MainFlowContainer/MainContentContainer/MarginContainer/PropertiesContainer


func _ready() -> void:
	ui_manager = GDInjector.inject("UIManager") as UIManager
	game_manager = GDInjector.inject("GameManager") as GameManager

	ui_manager.register_ui_view("SpawnerBuildingPopupView", self)
	visible = false

	close_button.pressed.connect(_on_close_button_pressed)
	toggle_debug_button.pressed.connect(_on_toggle_debug_button_pressed)
	spawn_car_button.pressed.connect(_on_spawn_car_button_pressed)
	debugger_button.pressed.connect(_on_debugger_button_pressed)
	pin_button.pressed.connect(_on_pin_button_toggled)

func update() -> void:
	if game_manager.get_selection_type() != GameManager.SelectionType.SPAWNER_BUILDING:
		_on_close_button_pressed()
		return

	selected_building = game_manager.get_selected_object() as SpawnerBuilding

	id_label.text = "#" + str(selected_building.id)

	if data_items.size() == 0:
		var data = selected_building.get_popup_data()
		for key in data.keys():
			var value = data[key]
			var item = item_scene.instantiate() as ValueListItem
			item.init_item(key, key.capitalize(), str(value))
			properties_container.add_child(item)
			data_items.append(item)
			
	toggle_debug_button.flat = not selected_building.are_debug_visuals_enabled()

func _process(_delta: float) -> void:
	if visible and selected_building:
		ui_manager.reanchor_to_world_object(self, selected_building, UIManager.AnchorPoint.BOTTOM_LEFT, is_pinned)
		var data = selected_building.get_popup_data()

		for i in range(data_items.size()):
			var item = data_items[i]
			item.set_value(str(data[item.id]))

func _on_close_button_pressed() -> void:
	ui_manager.hide_ui_view("SpawnerBuildingPopupView")
	selected_building = null
	_handle_pinned_button(false)

func _on_toggle_debug_button_pressed() -> void:
	selected_building.toggle_debug_visuals()
	toggle_debug_button.flat = not selected_building.are_debug_visuals_enabled()

func _on_spawn_car_button_pressed() -> void:
	selected_building.spawn_vehicle()

func _on_debugger_button_pressed() -> void:
	game_manager.debug_selection = not game_manager.debug_selection

func _on_pin_button_toggled() -> void:
	_handle_pinned_button(not is_pinned)

func _handle_pinned_button(active: bool) -> void:
	is_pinned = active
	pin_button.icon = preload("res://assets/ui_icons/keep.png") if active else preload("res://assets/ui_icons/keep_off.png")
