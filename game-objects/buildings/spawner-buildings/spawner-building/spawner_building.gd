extends BaseBuilding

class_name SpawnerBuilding

var vehicles_pool: int = 0

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

	var target_building_type = buildings_manager.get_random_building_type(self.type)
	var target_building = buildings_manager.get_random_building_with_constraints(target_building_type, self.id)

	if not target_building:
		return

	if target_building.segment == self.segment:
		return


	var vehicle = vehicle_manager.create_vehicle(VehicleManager.VEHICLE_TYPE.CAR)

	vehicle.trip_abandoned.connect(Callable(self, "_vehicle_routing_failed"))

	vehicle_leaving = vehicle
	vehicles_pool = clamp(vehicles_pool - 1, 0, INF)

	vehicle.init_trip(self, target_building)

func get_popup_data() -> Dictionary:
	return {
		"type": BuildingType.keys()[type],
		"vehicle_pool": vehicles_pool,
		"has_vehicle_leaving": vehicle_leaving != null,
		"has_vehicle_entering": vehicles_entering.size() > 0
	}

func _process(delta: float) -> void:
	if game_manager.try_hit_debug_pick(self):
		print("Debug pick triggered for spawner building ID %d" % id)
		breakpoint

	super._process(delta)

	if not simulation_manager.is_simulation_running():
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

	spawn_vehicle()
	

func _vehicle_routing_failed(_vehicle_id: int) -> void:
	vehicle_leaving = null

func _get_starting_vehicles_pool() -> int:
	return 0

func _get_shape_color() -> Color:
	return Color.GRAY

func _get_connection_endpoints()-> Dictionary:
	return {
		"in": to_global(Vector2(10, -5)),
		"out": to_global(Vector2(-10, -5))
	}
