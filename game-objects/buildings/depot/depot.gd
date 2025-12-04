extends BaseBuilding

class_name Depot

var depot_id: int

var _depot_data: DepotDefinition

var _current_bus_count: int = 0
var _current_articulated_bus_count: int = 0

var _buses: Array[int] = []

var _stop_tracks = []
var _vehicles_on_tracks: Dictionary = { }

@onready var click_area: Area2D = $ClickerArea
@onready var stop_tracks_wrapper: Node2D = $StopTracks

@onready var game_manager: GameManager = GDInjector.inject("GameManager") as GameManager
@onready var vehicle_manager: VehicleManager = GDInjector.inject("VehicleManager") as VehicleManager


func _ready() -> void:
	super._ready()
	click_area.connect("input_event", Callable(self, "_on_input_event"))
	_process_tracks()


func setup_depot(new_id: int, depot_data: DepotDefinition) -> void:
	depot_id = new_id
	_depot_data = depot_data
	_current_bus_count = depot_data.regular_bus_capacity
	_current_articulated_bus_count = depot_data.articulated_bus_capacity


func update_visuals() -> void:
	# Depots might have specific visuals to update in the future
	pass


func get_popup_data() -> Dictionary:
	return {
	}


func get_depot_name() -> String:
	return _depot_data.name


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


func try_spawn(is_articulated: bool, ignore_constraints: bool = false) -> bool:
	if not ignore_constraints and _check_spawn_constraints(is_articulated):
		return false

	_do_spawn(is_articulated)

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

	vehicle.trip_ended.connect(Callable(self, "_on_vehicle_entered"), ConnectFlags.CONNECT_ONE_SHOT)

	var path = _stop_tracks[track_id]["in"]

	return path


func _do_spawn(is_articulated: bool) -> void:
	var veh_type = VehicleManager.VehicleType.ARTICULATED_BUS if is_articulated else VehicleManager.VehicleType.BUS

	var vehicle = vehicle_manager.create_vehicle(veh_type)

	_buses.append(vehicle.id)

	vehicle.navigator.abandon_trip()


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
	var children = stop_tracks_wrapper.get_children()

	for child in children:
		var path = child as Path2D

		var reverse_curve = line_helper.reverse_curve(path.curve)
		var reverse_path = Path2D.new()
		reverse_path.curve = reverse_curve

		stop_tracks_wrapper.add_child(reverse_path)

		_stop_tracks.append(
			{
				"in": path,
				"out": reverse_path,
			},
		)
		_vehicles_on_tracks[_stop_tracks.size() - 1] = -1


func _get_free_track() -> int:
	for track_id in range(_stop_tracks.size()):
		if not _vehicles_on_tracks.get(track_id) != -1:
			return track_id

	return -1


func _on_vehicle_entered(vehicle_id: int, _completed: bool) -> void:
	for track_id in _vehicles_on_tracks.keys():
		if _vehicles_on_tracks[track_id] == vehicle_id:
			_vehicles_on_tracks[track_id] = -1
			return
