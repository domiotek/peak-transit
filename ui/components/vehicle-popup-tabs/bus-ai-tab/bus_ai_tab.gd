extends Control

class_name BusAiTab

var list_item = preload("res://ui/views/trip-view/trip-step-list-item/trip_step_list_item.tscn")

var _vehicle: Vehicle = null
var _brigades: Array = []
var _trip_selector_population_lock = -1
var _trip_steps_population_lock = -1

@onready var direction_prop: Label = $Wrapper/PropsContainer/DirectionProp
@onready var line_prop: ValueListItem = $Wrapper/PropsContainer/Line/LineProp
@onready var go_to_line_button: Button = $Wrapper/PropsContainer/Line/GoToLineButton
@onready var route_prop: ValueListItem = $Wrapper/PropsContainer/RouteProp
@onready var next_stop_prop: ValueListItem = $Wrapper/PropsContainer/NextStop/NextStopProp
@onready var go_to_stop_button: Button = $Wrapper/PropsContainer/NextStop/GoToStopButton
@onready var capacity: ValueListItem = $Wrapper/PropsContainer/Capacity
@onready var state_prop: Label = $Wrapper/PropsContainer/StateProp
@onready var brigade_selector: OptionButton = $Wrapper/BrigadeView/BrigadeSelect/BrigadeSelector
@onready var trip_selector: OptionButton = $Wrapper/BrigadeView/TripSelect/TripSelector
@onready var return_to_depot_button: Button = $Wrapper/PropsContainer/ButtonsBar/ReturnToDepotButton
@onready var steps_list: BoxContainer = $Wrapper/BrigadeView/ScrollContainer/TripStepList

@onready var transport_manager: TransportManager = GDInjector.inject("TransportManager") as TransportManager
@onready var game_manager: GameManager = GDInjector.inject("GameManager") as GameManager
@onready var ui_manager: UIManager = GDInjector.inject("UIManager") as UIManager


func _ready() -> void:
	brigade_selector.item_selected.connect(_on_brigade_selected)
	trip_selector.item_selected.connect(_on_trip_selected)
	return_to_depot_button.pressed.connect(_on_return_to_depot_button_pressed)
	go_to_line_button.pressed.connect(_on_go_to_line_button_pressed)


func bind(vehicle: Vehicle) -> void:
	_vehicle = vehicle
	_brigades = transport_manager.brigades.get_all()

	brigade_selector.clear()

	brigade_selector.add_item("Reserve", int(INF))
	for brigade in _brigades:
		brigade_selector.add_item(brigade.get_identifier(), brigade.id)

	var current_brigade = (_vehicle.ai as BusAI).get_brigade()

	if current_brigade == null:
		return

	var idx = brigade_selector.get_item_index(current_brigade.id)
	if idx > 0:
		brigade_selector.select(idx)
	else:
		brigade_selector.select(1)


func update_data() -> void:
	var ai = _vehicle.ai as BusAI

	state_prop.text = ai.get_state_name()

	var passenger_counts = ai.get_passenger_counts()
	capacity.set_value(str(passenger_counts["current_passengers"]) + " / " + str(passenger_counts["max_passengers"]))

	var brigade = ai.get_brigade()

	var current_trip = ai.get_current_trip()

	if current_trip == null:
		line_prop.set_value("N/A")
		route_prop.set_value("N/A")
		next_stop_prop.set_value("N/A")
		direction_prop.text = "In Reserve"
		go_to_line_button.disabled = true
		go_to_stop_button.disabled = true
		trip_selector.clear()
		_trip_selector_population_lock = -1

		for child in steps_list.get_children():
			child.queue_free()
		return

	go_to_line_button.disabled = false
	go_to_stop_button.disabled = false

	line_prop.set_value(str(brigade.get_line_tag()))
	direction_prop.text = "→ " + current_trip.get_destination_name()
	route_prop.set_value("Forward" if current_trip.is_forward() else "Return")
	var next_stop = ai.get_next_stop()
	if next_stop != null:
		next_stop_prop.set_value(next_stop.get_stop_name())

	_populate_trip_selector(brigade, current_trip.idx)
	var idx = trip_selector.get_item_index(current_trip.idx)
	trip_selector.select(idx)

	_populate_trip_view(current_trip)


func _on_brigade_selected(index: int) -> void:
	var ai = _vehicle.ai as BusAI
	if index == 0:
		ai.unassign_brigade()
		return

	var selected_brigade = brigade_selector.get_item_id(index)

	ai.assign_brigade(selected_brigade)


func _on_trip_selected(index: int) -> void:
	var ai = _vehicle.ai as BusAI
	var trip_idx = trip_selector.get_item_id(index)

	ai.set_current_trip(trip_idx)


func _populate_trip_selector(brigade: Brigade, current_trip_idx: int) -> void:
	if brigade.id == _trip_selector_population_lock:
		return

	_trip_selector_population_lock = brigade.id
	trip_selector.clear()

	var current_time = game_manager.clock.get_time().to_time_of_day()

	const MAX_ITEMS = 5

	var items_taken = 0

	for trip_idx in range(brigade.get_trip_count()):
		var trip = brigade.get_trip(trip_idx)

		if current_time.to_minutes() > trip.get_arrival_time().to_minutes() && trip_idx != current_trip_idx:
			continue

		if items_taken >= MAX_ITEMS:
			break

		items_taken += 1
		trip_selector.add_item("%d. %s → %s" % [trip_idx + 1, trip.get_departure_time().format(), trip.get_destination_name()], trip_idx)


func _populate_trip_view(trip: BrigadeTrip) -> void:
	if not trip:
		return

	if trip.idx == _trip_steps_population_lock:
		return

	for child in steps_list.get_children():
		child.queue_free()

	var actual_idx = 0
	var route = trip.get_route_steps()
	var stop_times = trip.get_stop_times()

	for step_idx in range(route.size()):
		var route_step = route[step_idx] as RouteStep

		if route_step.step_type == Enums.TransportRouteStepType.WAYPOINT:
			continue

		actual_idx += 1

		var step_item = list_item.instantiate() as TripStepListItem
		step_item.init_item(route_step.target_name)
		step_item.set_step_idx(actual_idx)
		step_item.set_departure_time(stop_times[step_idx])

		steps_list.add_child(step_item)


func _on_return_to_depot_button_pressed() -> void:
	if _vehicle:
		_vehicle.ai.return_to_depot()


func _on_go_to_line_button_pressed() -> void:
	if _vehicle:
		var ai = _vehicle.ai as BusAI
		var brigade = ai.get_brigade()
		if brigade:
			var line = transport_manager.get_line(brigade.line_id)
			ui_manager.show_ui_view_exclusively(ShortcutsView.SHORTCUTS_VIEW_GROUP, LinesView.VIEW_NAME, { "line": line })
