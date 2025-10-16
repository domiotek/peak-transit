extends BaseBuilding

class_name SpawnerBuilding

var vehicles_pool: int = 0

var vehicle_leaving: Vehicle = null


@onready var building_shape: Polygon2D = $Shape

@onready var vehicle_manager: VehicleManager = GDInjector.inject("VehicleManager") as VehicleManager
@onready var simulation_manager: SimulationManager = GDInjector.inject("SimulationManager") as SimulationManager

func _ready() -> void:
	super._ready()
	building_shape.color = _get_shape_color()


func setup(relation_id: int, _segment: NetSegment, _building_info: BuildingInfo) -> void:
	super.setup(relation_id, _segment, _building_info)

	vehicles_pool = _get_starting_vehicles_pool()

func mark_vehicle_left() -> void:
	vehicle_leaving = null


func _process(_delta: float) -> void:
	if not simulation_manager.is_simulation_running():
		return

	_try_spawn_vehicle()


func _try_spawn_vehicle() -> void:
	if vehicles_pool <= 0:
		return

	if vehicle_leaving:
		return

	var target_building_type = buildings_manager.get_random_building_type(self.type)
	var target_building = buildings_manager.get_random_building_with_constraints(target_building_type, self.id)

	if not target_building:
		return

	var vehicle = vehicle_manager.create_vehicle()

	vehicle.trip_abandoned.connect(Callable(self, "_vehicle_routing_failed"))

	vehicle_leaving = vehicle
	vehicles_pool -= 1

	vehicle.init_trip(self, target_building)

func _vehicle_routing_failed(_vehicle_id: int) -> void:
	vehicle_leaving = null

func _get_starting_vehicles_pool() -> int:
	return 0

func _get_shape_color() -> Color:
	return Color.GRAY

func _get_connection_endpoints()-> Dictionary:
	return {
		"in": to_global(Vector2(5, 0)),
		"out": to_global(Vector2(-5, 0))
	}
