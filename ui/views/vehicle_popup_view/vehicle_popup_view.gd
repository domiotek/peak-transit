extends Control


var ui_manager: UIManager
var game_manager: GameManager

var selected_vehicle: Vehicle = null
var is_pinned: bool = false
var draw_route: bool = false

var data_items: Array = []

var item_scene = preload("res://ui/components/value_list_item/value_list_item.tscn")


@onready var close_button: Button = $MarginContainer/MainFlowContainer/HeaderBoxContainer/CloseButton
@onready var pin_button: Button = $MarginContainer/MainFlowContainer/HeaderBoxContainer/PinButton
@onready var delete_button: Button = $MarginContainer/MainFlowContainer/ToolBoxPanel/DeleteButton
@onready var show_route_button: Button = $MarginContainer/MainFlowContainer/ToolBoxPanel/ShowRouteButton
@onready var debugger_button: Button = $MarginContainer/MainFlowContainer/ToolBoxPanel/DebuggerButton
@onready var reroute_button: Button = $MarginContainer/MainFlowContainer/ToolBoxPanel/RerouteButton

@onready var id_label: Label = $MarginContainer/MainFlowContainer/HeaderBoxContainer/IdLabel

@onready var properties_container: BoxContainer = $MarginContainer/MainFlowContainer/MainContentContainer/MarginContainer/PropertiesContainer
@onready var trip_progress_bar: ProgressBar = $MarginContainer/MainFlowContainer/MainContentContainer/TripProgressBar


func _ready() -> void:
	ui_manager = GDInjector.inject("UIManager") as UIManager
	game_manager = GDInjector.inject("GameManager") as GameManager

	ui_manager.register_ui_view("VehiclePopupView", self)
	visible = false

	close_button.pressed.connect(_on_close_button_pressed)
	delete_button.pressed.connect(_on_delete_button_pressed)
	show_route_button.pressed.connect(_on_show_route_button_pressed)
	debugger_button.pressed.connect(_on_debugger_button_pressed)
	pin_button.pressed.connect(_on_pin_button_toggled)
	reroute_button.pressed.connect(_on_reroute_button_pressed)

func update() -> void:
	if game_manager.get_selection_type() != GameManager.SelectionType.VEHICLE:
		_on_close_button_pressed()
		return

	selected_vehicle = game_manager.get_selected_object() as Vehicle

	id_label.text = "#" + str(selected_vehicle.id)

	if data_items.size() == 0:
		var data = selected_vehicle.get_popup_data()

		for key in data.keys():
			var value = data[key]
			var item = item_scene.instantiate() as ValueListItem
			item.init_item(key, key.capitalize(), str(value))
			properties_container.add_child(item)
			data_items.append(item)

	draw_route = not draw_route
	_on_show_route_button_pressed()

func _process(_delta: float) -> void:
	if visible and selected_vehicle:
		ui_manager.reanchor_to_world_object(self, selected_vehicle, UIManager.AnchorPoint.BOTTOM_LEFT, is_pinned)
		var data = selected_vehicle.get_popup_data()

		for i in range(data_items.size()):
			var item = data_items[i]
			item.set_value(str(data[item.id]))

		trip_progress_bar.value = selected_vehicle.get_total_progress() * 100

func _on_close_button_pressed() -> void:
	ui_manager.hide_ui_view("VehiclePopupView")
	selected_vehicle = null
	_handle_pinned_button(false)
	game_manager.clear_drawn_route()

func _on_delete_button_pressed() -> void:
	if selected_vehicle:
		selected_vehicle.navigator.abandon_trip()
		_on_close_button_pressed()

func _on_show_route_button_pressed() -> void:
	if selected_vehicle:
		draw_route = not draw_route
		show_route_button.flat = not draw_route
		game_manager.clear_drawn_route()

		if draw_route:
			game_manager.draw_vehicle_route(selected_vehicle)

func _on_debugger_button_pressed() -> void:
	game_manager.debug_selection = not game_manager.debug_selection

func _on_reroute_button_pressed() -> void:
	if selected_vehicle:
		selected_vehicle.navigator.reroute()

func _on_pin_button_toggled() -> void:
	_handle_pinned_button(not is_pinned)

func _handle_pinned_button(active: bool) -> void:
	is_pinned = active
	pin_button.icon = preload("res://assets/ui_icons/keep.png") if active else preload("res://assets/ui_icons/keep_off.png")
