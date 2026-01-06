extends Control

class_name BrigadeView

var list_item = preload("res://ui/components/trip-list-item/trip_list_item.tscn")
const CHEVRON_RIGHT_ICON: Resource = preload("res://assets/ui_icons/chevron_right.png")

@onready var transport_manager: TransportManager = GDInjector.inject("TransportManager") as TransportManager
@onready var vehicle_manager: VehicleManager = GDInjector.inject("VehicleManager") as VehicleManager
@onready var brigade_identifier_label: Label = $MarginContainer/MainWrapper/Header/BrigadeIdentifierLabel
@onready var trips_list: BoxContainer = $MarginContainer/MainWrapper/BrigadeDetailsMargin/BrigadeDetailsContent/ScrollContainer/TripsList

@onready var service_time_prop: ValueListItem = $MarginContainer/MainWrapper/BrigadeDetailsMargin/BrigadeDetailsContent/PropsContainer/ServiceTimeProp
@onready var frequency_prop: ValueListItem = $MarginContainer/MainWrapper/BrigadeDetailsMargin/BrigadeDetailsContent/PropsContainer/FrequencyProp
@onready var min_layover_prop: ValueListItem = $MarginContainer/MainWrapper/BrigadeDetailsMargin/BrigadeDetailsContent/PropsContainer/MinLayoverProp
@onready var total_trips_prop: ValueListItem = $MarginContainer/MainWrapper/BrigadeDetailsMargin/BrigadeDetailsContent/PropsContainer/TotalTripsProp

var _brigade: Brigade = null
var _route_info: Dictionary = { }

signal trip_selected(trip_idx: int)


func setup(brigade: Brigade) -> void:
	if _brigade != null:
		_brigade.vehicle_assigned.disconnect(_on_trip_vehicle_changed)
		_brigade.vehicle_unassigned.disconnect(_on_trip_vehicle_changed)

	_brigade = brigade

	_brigade.vehicle_assigned.connect(_on_trip_vehicle_changed)
	_brigade.vehicle_unassigned.connect(_on_trip_vehicle_changed)

	brigade_identifier_label.text = _brigade.get_identifier()

	var line = transport_manager.get_line(_brigade.line_id)

	service_time_prop.set_value("%s - %s" % [_brigade.get_start_time().format(), _brigade.get_end_time().format()], true)
	frequency_prop.set_value("%d min" % line.get_frequency_minutes(), true)
	min_layover_prop.set_value("%d min" % line.get_min_layover_minutes(), true)
	total_trips_prop.set_value("%d" % _brigade.get_schedule().trips.size())

	var routes = line.get_routes()

	for route_id in range(routes.size()):
		var route_steps = routes[route_id] as Array[RouteStep]
		_route_info[route_id] = {
			"from": route_steps[0].target_name,
			"to": route_steps[route_steps.size() - 1].target_name,
		}

	_render_trip_list()


func _render_trip_list() -> void:
	for child in trips_list.get_children():
		child.queue_free()

	var trips = _brigade.get_schedule().trips as Array[Trip]

	for trip_idx in range(trips.size()):
		var trip = trips[trip_idx] as Trip
		var target_route_info = _route_info[trip.route_id]
		var trip_item = list_item.instantiate() as TripListItem

		var assigned_vehicle_id = _brigade.get_vehicle_of_trip(trip_idx)
		var assigned_vehicle = vehicle_manager.get_vehicle(assigned_vehicle_id) if assigned_vehicle_id != -1 else null
		var bus_identifier = ""

		if assigned_vehicle != null:
			bus_identifier = assigned_vehicle.ai.get_custom_identifier()

		trip_item.init_item("%s → %s" % [target_route_info["from"], target_route_info["to"]], bus_identifier)
		trip_item.set_idx(trip_idx + 1)
		trip_item.set_service_time(trip.departure_time, trip.arrival_time)
		trip_item.show_button(CHEVRON_RIGHT_ICON)
		trip_item.set_data({ "trip_idx": trip_idx })

		trip_item.button_pressed.connect(Callable(self, "_on_trip_item_button_pressed"))

		trips_list.add_child(trip_item)


func _on_trip_item_button_pressed(_sender: ListItem, data: Dictionary) -> void:
	var trip_idx = data.get("trip_idx", -1) as int
	if trip_idx != -1:
		emit_signal("trip_selected", _brigade, trip_idx)


func _on_trip_vehicle_changed(_vehicle_id: int, _trip_id: int = -1) -> void:
	_render_trip_list()
