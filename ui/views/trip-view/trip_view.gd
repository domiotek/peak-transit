extends Control

class_name TripView

var list_item = preload("res://ui/views/trip-view/trip-step-list-item/trip_step_list_item.tscn")

@onready var transport_manager: TransportManager = GDInjector.inject("TransportManager") as TransportManager
@onready var vehicle_manager: VehicleManager = GDInjector.inject("VehicleManager") as VehicleManager
@onready var game_manager: GameManager = GDInjector.inject("GameManager") as GameManager

@onready var trip_idx_label: Label = $MarginContainer/MainWrapper/Header/TripIdxLabel
@onready var relation_label: Label = $MarginContainer/MainWrapper/Header/RelationLabel
@onready var brigade_id_prop: ValueListItem = $MarginContainer/MainWrapper/TripDetailsMargin/TripDetailsContent/WrapperBoxContainer/PropsContainer/BrigadeIdProp
@onready var service_time_prop: ValueListItem = $MarginContainer/MainWrapper/TripDetailsMargin/TripDetailsContent\
												/WrapperBoxContainer/PropsContainer/ServiceTimeProp
@onready var total_time_prop: ValueListItem = $MarginContainer/MainWrapper/TripDetailsMargin/TripDetailsContent/WrapperBoxContainer/PropsContainer/TotalTimeProp
@onready var total_steps_prop: ValueListItem = $MarginContainer/MainWrapper/TripDetailsMargin/TripDetailsContent\
												/WrapperBoxContainer/PropsContainer/TotalStepsProp
@onready var steps_list: BoxContainer = $MarginContainer/MainWrapper/TripDetailsMargin/TripDetailsContent/ScrollContainer/StepsList

@onready var bus_view: BoxContainer = $MarginContainer/MainWrapper/TripDetailsMargin/TripDetailsContent/WrapperBoxContainer/VehiclePanel/MarginContainer/BusView
@onready var no_bus_view: BoxContainer = $MarginContainer/MainWrapper/TripDetailsMargin/TripDetailsContent\
										 /WrapperBoxContainer/VehiclePanel/MarginContainer/NoBusView

@onready var bus_id_label: Label = $MarginContainer/MainWrapper/TripDetailsMargin/TripDetailsContent\
									/WrapperBoxContainer/VehiclePanel/MarginContainer/BusView/Headline/BusIdLabel
@onready var jump_to_bus_button: Button = $MarginContainer/MainWrapper/TripDetailsMargin/TripDetailsContent\
									/WrapperBoxContainer/VehiclePanel/MarginContainer/BusView/Headline/JumpToBusButton
@onready var state_label: ValueListItem = $MarginContainer/MainWrapper/TripDetailsMargin/TripDetailsContent\
									/WrapperBoxContainer/VehiclePanel/MarginContainer/BusView/StateLabel
@onready var passengers_count_label: ValueListItem = $MarginContainer/MainWrapper/TripDetailsMargin/TripDetailsContent\
									/WrapperBoxContainer/VehiclePanel/MarginContainer/BusView/PassengersCountLabel
@onready var prev_trip_button: Button = $MarginContainer/MainWrapper/Header/PrevTripButton
@onready var next_trip_button: Button = $MarginContainer/MainWrapper/Header/NextTripButton

var _brigade: Brigade = null
var _trip_idx: int = -1
var _assigned_vehicle: Vehicle = null


func _ready() -> void:
	jump_to_bus_button.pressed.connect(_on_jump_to_bus_button_pressed)
	prev_trip_button.pressed.connect(_on_prev_trip_button_pressed)
	next_trip_button.pressed.connect(_on_next_trip_button_pressed)


func setup(brigade: Brigade, trip_idx: int) -> void:
	if _brigade != null:
		_brigade.vehicle_assigned.disconnect(_on_vehicle_trip_changed)
		_brigade.vehicle_unassigned.disconnect(_on_vehicle_trip_changed)

	for child in steps_list.get_children():
		child.queue_free()

	_brigade = brigade
	_trip_idx = trip_idx

	_brigade.vehicle_assigned.connect(_on_vehicle_trip_changed)
	_brigade.vehicle_unassigned.connect(_on_vehicle_trip_changed)

	prev_trip_button.disabled = trip_idx <= 0
	next_trip_button.disabled = trip_idx >= _brigade.get_schedule().trips.size() - 1

	var trip = _brigade.get_schedule().trips[trip_idx] as Trip

	trip_idx_label.text = "#%d" % (trip_idx + 1)
	brigade_id_prop.set_value(str(_brigade.get_identifier()), true)
	service_time_prop.set_value("%s - %s" % [trip.departure_time.format(), trip.arrival_time.format()], true)
	total_time_prop.set_value("%d min" % trip.duration, true)
	total_steps_prop.set_value("%d" % trip.stop_times.size(), true)

	var line = transport_manager.get_line(_brigade.line_id)
	var route = line.get_route_steps(trip.route_id)

	var from_stop_name = route[0].target_name
	var to_stop_name = route[route.size() - 1].target_name
	relation_label.text = "%s → %s" % [from_stop_name, to_stop_name]

	var actual_idx = 0
	for step_idx in range(route.size()):
		var route_step = route[step_idx] as RouteStep

		if route_step.step_type == Enums.TransportRouteStepType.WAYPOINT:
			continue

		actual_idx += 1

		var step_item = list_item.instantiate() as TripStepListItem
		step_item.init_item(route_step.target_name)
		step_item.set_step_idx(actual_idx)
		step_item.set_departure_time(trip.stop_times[step_idx])

		steps_list.add_child(step_item)

	_render_assigned_vehicle_panel()


func _on_prev_trip_button_pressed() -> void:
	if _brigade == null:
		return

	var new_trip_idx = _trip_idx - 1

	if new_trip_idx < 0:
		return

	setup(_brigade, new_trip_idx)


func _on_next_trip_button_pressed() -> void:
	if _brigade == null:
		return
	var new_trip_idx = _trip_idx + 1

	if new_trip_idx >= _brigade.get_schedule().trips.size():
		return

	setup(_brigade, new_trip_idx)


func _process(_delta: float) -> void:
	if not _brigade:
		return

	var current_time = game_manager.clock.get_time().to_time_of_day()

	var vehicle_diff = 0
	var current_stop_idx = 0

	if _assigned_vehicle:
		vehicle_diff = (_assigned_vehicle.ai as BusAI).get_time_difference_to_schedule(current_time)
		var next_stop = _assigned_vehicle.ai.get_next_stop()
		current_stop_idx = next_stop.stop_idx - 1 if next_stop != null else 0

	for stop_idx in range(steps_list.get_child_count()):
		var child = steps_list.get_child(stop_idx)
		var step_item = child as TripStepListItem

		if stop_idx < current_stop_idx:
			step_item.mark_departed()
			continue

		step_item.update_schedule_diff(vehicle_diff, current_time)

		if not _assigned_vehicle:
			step_item.disable_diff()


func _on_vehicle_trip_changed(vehicle_id: int, trip_idx: int = 0) -> void:
	if (_assigned_vehicle and vehicle_id == _assigned_vehicle.id) or trip_idx == _trip_idx:
		_render_assigned_vehicle_panel()


func _on_jump_to_bus_button_pressed() -> void:
	game_manager.set_selection(_assigned_vehicle, GameManager.SelectionType.VEHICLE)
	game_manager.jump_to_selection()


func _render_assigned_vehicle_panel():
	var assigned_bus_id = _brigade.get_vehicle_of_trip(_trip_idx)
	var assigned_bus: Vehicle = vehicle_manager.get_vehicle(assigned_bus_id) if assigned_bus_id != -1 else null

	if assigned_bus == null:
		bus_view.visible = false
		no_bus_view.visible = true
		_assigned_vehicle = null
		return

	_assigned_vehicle = assigned_bus

	bus_view.visible = true
	no_bus_view.visible = false

	bus_id_label.text = assigned_bus.ai.get_custom_identifier()

	state_label.set_value(assigned_bus.ai.get_state_name(), true)

	var passenger_counts = assigned_bus.ai.get_passenger_counts()

	passengers_count_label.set_value("%d / %d" % [passenger_counts.current_passengers, passenger_counts.max_passengers], true)
