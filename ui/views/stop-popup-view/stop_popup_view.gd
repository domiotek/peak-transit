extends Control

class_name StopPopupView

const LineTagScene = preload("res://ui/components/line-tag/line_tag.tscn")
const ListItemScene = preload("res://ui/components/departure-list-item/departure_list_item.tscn")
const JumpToSelectionResource = preload("res://assets/ui_icons/jump_to_element.png")

const VIEW_NAME: String = "StopPopupView"

var ui_manager: UIManager
var game_manager: GameManager

var selected_step: StopSelection = null

var is_pinned: bool = false

var data_items: Array = []

@onready var close_button: Button = $MarginContainer/MainFlowContainer/HeaderBoxContainer/CloseButton
@onready var pin_button: Button = $MarginContainer/MainFlowContainer/HeaderBoxContainer/PinButton

@onready var stop_name_label: Label = $MarginContainer/MainFlowContainer/HeaderBoxContainer/StopNameLabel

@onready var content_wrapper: BoxContainer = $MarginContainer/MainFlowContainer/MainContentContainer/MarginContainer/ContentWrapper
@onready var line_tags_container: BoxContainer = $MarginContainer/MainFlowContainer/MainContentContainer/MarginContainer/ContentWrapper/LineTagsContainer
@onready var departures_wrapper: ScrollContainer = $MarginContainer/MainFlowContainer/MainContentContainer/MarginContainer/\
													ContentWrapper/DeparturesWrapper/ScrollContainer
@onready var departures_container: BoxContainer = $MarginContainer/MainFlowContainer/MainContentContainer/MarginContainer/\
													ContentWrapper/DeparturesWrapper/ScrollContainer/DeparturesContainer
@onready var no_departures_label: Label = $MarginContainer/MainFlowContainer/MainContentContainer/MarginContainer/\
													ContentWrapper/DeparturesWrapper/NoDeparturesLabel

@onready var transport_manager: TransportManager = GDInjector.inject("TransportManager") as TransportManager
@onready var vehicle_manager: VehicleManager = GDInjector.inject("VehicleManager") as VehicleManager


func _ready() -> void:
	ui_manager = GDInjector.inject("UIManager") as UIManager
	game_manager = GDInjector.inject("GameManager") as GameManager

	visible = false
	ui_manager.register_ui_view(VIEW_NAME, self)

	close_button.pressed.connect(_on_close_button_pressed)
	pin_button.pressed.connect(_on_pin_button_toggled)


func update(_data: Dictionary) -> void:
	if game_manager.get_selection_type() != GameManager.SelectionType.TRANSPORT_STOP:
		_on_close_button_pressed()
		return

	selected_step = game_manager.get_selected_object() as StopSelection

	ui_manager.reanchor_to_world_object(self, selected_step.get_anchor(), UIManager.AnchorPoint.BOTTOM_LEFT, is_pinned)

	stop_name_label.text = selected_step.get_stop_name()

	for child in line_tags_container.get_children():
		child.queue_free()

	var departures = []

	var current_clock = game_manager.clock.get_time()
	var current_time_of_day = TimeOfDay.new(current_clock.hour, current_clock.minute)

	for line_id in selected_step.get_lines():
		var line_tag = LineTagScene.instantiate() as LineTag
		var line = transport_manager.get_line(line_id)
		line_tag.init(line.id, line.display_number, line.color_hex)
		line_tag.clicked.connect(_on_line_tag_clicked)
		line_tags_container.add_child(line_tag)
		departures += selected_step.get_departures(line, current_time_of_day)

	if departures.size() == 0:
		no_departures_label.visible = true
		departures_wrapper.visible = false
		return

	no_departures_label.visible = false
	departures_wrapper.visible = true

	departures.sort_custom(
		func(a, b):
			return a.departure_time.to_minutes() < b.departure_time.to_minutes()
	)

	for child in departures_container.get_children():
		child.queue_free()

	var departures_limit = min(departures.size(), 10)
	departures = departures.slice(0, departures_limit)

	for dep in departures:
		var item_scene = ListItemScene.instantiate() as DepartureListItem
		item_scene.init_item(dep["direction"], "Brigade " + str(dep["brigade_identifier"]))
		item_scene.setup(
			dep["line_id"],
			dep["line_display_number"],
			dep["line_color_hex"],
			dep.departure_time,
			0,
		)
		item_scene.set_data(
			{
				"brigade_id": dep["brigade_id"],
				"trip_id": dep["trip_idx"],
			},
		)
		item_scene.show_button(JumpToSelectionResource)
		item_scene.button_pressed.connect(_jump_to_trip)
		item_scene.line_tag_clicked.connect(_on_line_tag_clicked)
		departures_container.add_child(item_scene)


func _process(_delta: float) -> void:
	if not visible or not selected_step:
		return

	ui_manager.reanchor_to_world_object(self, selected_step.get_anchor(), UIManager.AnchorPoint.BOTTOM_LEFT, is_pinned)

	var current_clock = game_manager.clock.get_time()
	var current_time_of_day = TimeOfDay.new(current_clock.hour, current_clock.minute)

	for child in departures_container.get_children():
		var dep = child.get_data()
		var brigade = transport_manager.brigades.get_by_id(dep["brigade_id"])
		if not brigade:
			continue

		var vehicle_id = brigade.get_vehicle_of_trip(dep["trip_id"])
		var vehicle = vehicle_manager.get_vehicle(vehicle_id) if vehicle_id != -1 else null

		var delay_minutes = 0

		if vehicle and vehicle.ai.has_started_trip():
			delay_minutes = vehicle.ai.get_time_difference_to_schedule(current_time_of_day)

			if vehicle.ai.get_next_stop() == null:
				delay_minutes = 0

		child.update_delay(delay_minutes)


func _on_close_button_pressed() -> void:
	ui_manager.hide_ui_view(VIEW_NAME)
	_handle_pinned_button(false)


func _on_pin_button_toggled() -> void:
	_handle_pinned_button(not is_pinned)


func _handle_pinned_button(active: bool) -> void:
	is_pinned = active
	pin_button.icon = preload("res://assets/ui_icons/keep.png") if active else preload("res://assets/ui_icons/keep_off.png")


func _jump_to_trip(_sender: DepartureListItem, data: Dictionary) -> void:
	var brigade_id = data.get("brigade_id", -1)
	var brigade = transport_manager.brigades.get_by_id(brigade_id)
	var trip_id = data.get("trip_id", -1)

	if brigade:
		ui_manager.show_ui_view_exclusively(ShortcutsView.SHORTCUTS_VIEW_GROUP, BrigadesView.VIEW_NAME, { "brigade": brigade, "trip_id": trip_id })


func _on_line_tag_clicked(line_id: int) -> void:
	var line = transport_manager.get_line(line_id)
	if line:
		ui_manager.show_ui_view_exclusively(ShortcutsView.SHORTCUTS_VIEW_GROUP, LinesView.VIEW_NAME, { "line": line })
