extends Control

class_name TripView

var list_item = preload("res://ui/views/trip-view/trip-step-list-item/trip_step_list_item.tscn")

@onready var transport_manager: TransportManager = GDInjector.inject("TransportManager") as TransportManager

@onready var trip_idx_label: Label = $MarginContainer/MainWrapper/Header/TripIdxLabel
@onready var relation_label: Label = $MarginContainer/MainWrapper/Header/RelationLabel
@onready var brigade_id_prop: ValueListItem = $MarginContainer/MainWrapper/TripDetailsMargin/TripDetailsContent/PropsContainer/BrigadeIdProp
@onready var service_time_prop: ValueListItem = $MarginContainer/MainWrapper/TripDetailsMargin/TripDetailsContent/PropsContainer/ServiceTimeProp
@onready var total_time_prop: ValueListItem = $MarginContainer/MainWrapper/TripDetailsMargin/TripDetailsContent/PropsContainer/TotalTimeProp
@onready var total_steps_prop: ValueListItem = $MarginContainer/MainWrapper/TripDetailsMargin/TripDetailsContent/PropsContainer/TotalStepsProp
@onready var steps_list: BoxContainer = $MarginContainer/MainWrapper/TripDetailsMargin/TripDetailsContent/ScrollContainer/StepsList

var _brigade: Brigade = null
var _trip_idx: int = -1


func setup(brigade: Brigade, trip_idx: int) -> void:
	for child in steps_list.get_children():
		child.queue_free()

	_brigade = brigade
	_trip_idx = trip_idx

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
