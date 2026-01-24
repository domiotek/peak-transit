extends BaseBuilding

class_name Depot

var depot_id: int

var _depot_data: DepotDefinition

var _current_bus_count: int = 0
var _current_articulated_bus_count: int = 0

var _buses: Array[int] = []

var _stop_tracks = []
var _vehicles_on_tracks: Dictionary = { }

var _known_bus_ids: Dictionary = {
	"regular": [],
	"articulated": [],
}
var _next_bus_number: int = 1

@onready var terrain: Polygon2D = $Terrain
@onready var click_area: Area2D = $ClickerArea
@onready var building: Node2D = $Building
@onready var in_stop_tracks_wrapper: Node2D = $StopInTracks
@onready var out_stop_tracks_wrapper: Node2D = $StopOutTracks

@onready var game_manager: GameManager = GDInjector.inject("GameManager") as GameManager
@onready var vehicle_manager: VehicleManager = GDInjector.inject("VehicleManager") as VehicleManager


func _ready() -> void:
	super._ready()
	click_area.connect("input_event", Callable(self, "_on_input_event"))
	_process_tracks()
	terrain.polygon = get_collision_polygon()

	if config_manager.AutoFillDepotStopsOnLoad and game_manager.get_game_mode() == Enums.GameMode.CHALLENGE:
		_fill_bus_stops()


func setup_depot(new_id: int, depot_data: DepotDefinition) -> void:
	depot_id = new_id
	_depot_data = depot_data
	_current_bus_count = depot_data.regular_bus_capacity
	_current_articulated_bus_count = depot_data.articulated_bus_capacity


func get_definition() -> DepotDefinition:
	return _depot_data


func update_visuals() -> void:
	# Depots might have specific visuals to update in the future
	pass


func get_popup_data() -> Dictionary:
	return {
	}


func get_depot_name() -> String:
	return _depot_data.name


func get_bus_prefix() -> String:
	return _depot_data.bus_id_prefix if _depot_data.bus_id_prefix != "" else get_depot_name().substr(0, 2).to_upper()


func get_position_offset() -> float:
	return _depot_data.position.offset


func get_incoming_node_id() -> int:
	return _depot_data.position.segment[0]


func get_outgoing_node_id() -> int:
	return _depot_data.position.segment[1]


func get_max_bus_capacity(is_articulated: bool = false) -> int:
	return _depot_data.articulated_bus_capacity if is_articulated else _depot_data.regular_bus_capacity


func get_current_bus_count(is_articulated: bool = false) -> int:
	return _current_articulated_bus_count if is_articulated else _current_bus_count


func get_anchor() -> Node2D:
	return building


func try_spawn(is_articulated: bool, ignore_constraints: bool = false) -> bool:
	if not ignore_constraints and not _check_spawn_constraints(is_articulated):
		return false

	var track_id = _get_free_track()
	if track_id == -1:
		return false

	_do_spawn(track_id, is_articulated)

	_current_articulated_bus_count = clamp(_current_articulated_bus_count - (1 if is_articulated else 0), 0, INF)
	_current_bus_count = clamp(_current_bus_count - (1 if not is_articulated else 0), 0, INF)

	return true


func try_enter(vehicle: Vehicle) -> Path2D:
	if vehicle.type != VehicleManager.VehicleType.BUS and vehicle.type != VehicleManager.VehicleType.ARTICULATED_BUS:
		return null

	var track_id = _get_free_track()
	if track_id == -1:
		return null

	_vehicles_on_tracks[track_id] = vehicle.id

	vehicle.trip_ended.connect(Callable(self, "_on_vehicle_left"), ConnectFlags.CONNECT_ONE_SHOT)

	var path = _stop_tracks[track_id]["in"]

	return path


func insta_return_bus(vehicle_id: int) -> void:
	if not vehicle_id in _buses:
		push_warning("Vehicle ID %d is not registered as belonging to depot ID %d." % [vehicle_id, depot_id])
		return

	_on_vehicle_entered(vehicle_id, true)


static func get_collision_polygon() -> PackedVector2Array:
	return BuildingConstants.DEPOT_COLLISION_POLYGON


func _do_spawn(track_id: int, is_articulated: bool) -> void:
	var veh_type = VehicleManager.VehicleType.ARTICULATED_BUS if is_articulated else VehicleManager.VehicleType.BUS

	var vehicle = vehicle_manager.create_vehicle(veh_type)

	_buses.append(vehicle.id)

	vehicle.ai.set_origin_depot(self)
	vehicle.ai.set_custom_identifier(_get_next_bus_identifier(is_articulated))

	var path = _stop_tracks[track_id]["out"]

	vehicle.navigator.set_custom_step(path, 0.0)

	_vehicles_on_tracks[track_id] = vehicle.id

	vehicle.trip_ended.connect(Callable(self, "_on_vehicle_left"), ConnectFlags.CONNECT_ONE_SHOT)


func _check_spawn_constraints(is_articulated: bool) -> bool:
	var should_check_constraints = config_manager.DebugToggles.IgnoreDepotConstraints == false

	if not should_check_constraints:
		return true

	if is_articulated:
		return _current_articulated_bus_count > 0

	return _current_bus_count > 0


func _get_connection_endpoints() -> Dictionary:
	return {
		"in": to_global(Vector2(10, -25)),
		"out": to_global(Vector2(-10, -25)),
	}


func _on_input_event(_viewport, event, _shape_idx) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		game_manager.set_selection(self, GameManager.SelectionType.DEPOT)


func _process_tracks() -> void:
	var children = in_stop_tracks_wrapper.get_children()

	for child in children:
		var path = child as Path2D
		_stop_tracks.append(
			{
				"in": path,
			},
		)
		_vehicles_on_tracks[_stop_tracks.size() - 1] = -1

	for i in range(_stop_tracks.size()):
		var out_path = out_stop_tracks_wrapper.get_child(i) as Path2D

		if not out_path:
			_stop_tracks.erase(_stop_tracks[i])
			push_error("Depot stop track %d is misconfigured: missing out path." % i)
			break

		_stop_tracks[i]["out"] = out_path


func _get_free_track() -> int:
	for track_id in range(_stop_tracks.size()):
		if not _vehicles_on_tracks.get(track_id) != -1:
			return track_id

	return -1


func _on_vehicle_left(vehicle_id: int, _completed: bool) -> void:
	_clear_vehicle_from_tracks(vehicle_id)


func _on_vehicle_entered(vehicle_id: int, _completed: bool) -> void:
	var vehicle = vehicle_manager.get_vehicle(vehicle_id)
	var is_articulated = vehicle.type == VehicleManager.VehicleType.ARTICULATED_BUS
	var custom_id = vehicle.ai.get_custom_identifier()

	_increase_bus_count(is_articulated)

	_known_bus_ids["articulated" if is_articulated else "regular"].append(custom_id)

	_clear_vehicle_from_tracks(vehicle_id)
	_buses.erase(vehicle_id)


func _clear_vehicle_from_tracks(vehicle_id: int) -> void:
	for track_id in _vehicles_on_tracks.keys():
		if _vehicles_on_tracks[track_id] == vehicle_id:
			_vehicles_on_tracks[track_id] = -1
			return


func _increase_bus_count(is_articulated: bool) -> void:
	if is_articulated:
		_current_articulated_bus_count = clamp(_current_articulated_bus_count + 1, 0, _depot_data.articulated_bus_capacity)
	else:
		_current_bus_count = clamp(_current_bus_count + 1, 0, _depot_data.regular_bus_capacity)


func _fill_bus_stops() -> void:
	var next_bus_is_articulated = false
	while try_spawn(next_bus_is_articulated, true):
		next_bus_is_articulated = not next_bus_is_articulated


func _get_next_bus_identifier(is_articulated: bool) -> String:
	var vehicle_type_key = "articulated" if is_articulated else "regular"
	var known_ids = _known_bus_ids[vehicle_type_key]

	if known_ids.size() > 0:
		var reused_id = known_ids.pop_front()
		return reused_id

	var prefix = get_bus_prefix()
	var bus_id = "%s-%03d" % [prefix, _next_bus_number]

	_next_bus_number += 1

	return bus_id
