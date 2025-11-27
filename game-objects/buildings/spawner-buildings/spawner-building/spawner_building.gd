extends BaseBuilding

class_name SpawnerBuilding

var vehicles_pool: int = 0
var _roll_cooldown: float = 0.0

@onready var building_shape: Polygon2D = $Shape
@onready var click_area: Area2D = $ClickArea

@onready var vehicle_manager: VehicleManager = GDInjector.inject("VehicleManager") as VehicleManager
@onready var simulation_manager: SimulationManager = GDInjector.inject("SimulationManager") as SimulationManager
@onready var game_manager: GameManager = GDInjector.inject("GameManager") as GameManager


func _ready() -> void:
	super._ready()
	building_shape.color = _get_shape_color()
	click_area.connect("input_event", Callable(self, "_on_input_event"))


func setup(relation_id: int, _segment: NetSegment, _building_info: BuildingInfo) -> void:
	super.setup(relation_id, _segment, _building_info)

	vehicles_pool = _get_starting_vehicles_pool()


func notify_vehicle_left() -> void:
	vehicle_leaving = null


func notify_vehicle_entering(vehicle: Vehicle) -> void:
	vehicles_entering.append(vehicle)


func notify_vehicle_entered(vehicle: Vehicle) -> void:
	vehicles_pool += 1
	vehicles_entering.erase(vehicle)


func spawn_vehicle() -> void:
	if vehicle_leaving:
		return

	var target_building_type = buildings_manager.get_random_building_type(self.type, _get_target_building_roll_weights())
	var target_building = buildings_manager.get_random_building_with_constraints(target_building_type, self.id)

	if not target_building:
		push_warning("Couldn't find target building of type %s for spawner building ID %d." % [str(target_building_type), id])
		return

	if target_building.segment == self.segment:
		return

	var vehicle = vehicle_manager.create_vehicle(VehicleManager.VehicleType.CAR)

	vehicle.trip_abandoned.connect(Callable(self, "_vehicle_routing_failed"))

	vehicle_leaving = vehicle
	vehicles_pool = clamp(vehicles_pool - 1, 0, INF)

	vehicle.init_trip(self, target_building)


func get_popup_data() -> Dictionary:
	return {
		"type": BuildingInfo.BuildingType.keys()[type],
		"vehicle_pool": vehicles_pool,
		"has_vehicle_leaving": vehicle_leaving != null,
		"has_vehicle_entering": vehicles_entering.size() > 0,
		"spawn_chance": _get_spawn_chance(game_manager.clock.get_day_progress_percentage()),
		"spawn_roll_cooldown": int(_roll_cooldown),
	}


func _process(_delta: float) -> void:
	if game_manager.try_hit_debug_pick(self):
		print("Debug pick triggered for spawner building ID %d" % id)
		breakpoint

	if not simulation_manager.is_simulation_running():
		return

	if _roll_cooldown > 0.0:
		_roll_cooldown = clamp(_roll_cooldown - _delta, 0, INF)
		return

	_try_spawn_vehicle()


func _on_input_event(_viewport, event, _shape_idx) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		game_manager.set_selection(self, GameManager.SelectionType.SPAWNER_BUILDING)


func _try_spawn_vehicle() -> void:
	if vehicles_pool <= 0:
		return

	if vehicles_entering.size() > 0:
		return

	_roll_cooldown = 5.0

	if not _roll_for_vehicle_spawn():
		return

	spawn_vehicle()


func _vehicle_routing_failed(_vehicle_id: int) -> void:
	vehicle_leaving = null


func _get_starting_vehicles_pool() -> int:
	return 0


func _get_shape_color() -> Color:
	return Color.GRAY


func _get_connection_endpoints() -> Dictionary:
	return {
		"in": to_global(Vector2(10, -5)),
		"out": to_global(Vector2(-10, -5)),
	}


func _get_spawn_chance(_time_of_day: float) -> float:
	return 0


func _roll_for_vehicle_spawn() -> bool:
	var time_of_day = game_manager.clock.get_day_progress_percentage()

	var spawn_chance = _get_spawn_chance(time_of_day)

	return randf() < spawn_chance


func _get_target_building_roll_weights() -> Dictionary:
	return {
		BuildingInfo.BuildingType.RESIDENTIAL: 1,
		BuildingInfo.BuildingType.COMMERCIAL: 1,
		BuildingInfo.BuildingType.INDUSTRIAL: 1,
	}


# 5AM to 8:30AM
func _is_morning_rush_hour(time_of_day: float) -> bool:
	return time_of_day >= 0.2 and time_of_day < 0.35


# 8:30AM to 3PM
func _is_midday(time_of_day: float) -> bool:
	return time_of_day >= 0.35 and time_of_day < 0.6


# 3PM to 7PM
func _is_evening_rush_hour(time_of_day: float) -> bool:
	return time_of_day >= 0.6 and time_of_day < 0.8


# 7PM to 10PM
func _is_late_evening(time_of_day: float) -> bool:
	return time_of_day >= 0.8 and time_of_day < 1.0


# 10PM to 5AM
func _is_night_time(time_of_day: float) -> bool:
	return time_of_day >= 0.9 or time_of_day < 0.2
