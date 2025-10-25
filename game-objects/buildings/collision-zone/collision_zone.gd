extends Area2D

class_name CollisionZone


@onready var collision_shape: CollisionShape2D = $CollisionShape
@onready var debug_shape: Polygon2D = $DebugShape

@onready var vehicle_manager: VehicleManager = GDInjector.inject("VehicleManager") as VehicleManager


func set_size_scale(scale_factor: float) -> void:
	self.scale = Vector2(scale_factor, 1.0)

func has_vehicles_inside(other_than: Vehicle) -> bool:
	var overlapping_bodies = get_overlapping_areas()

	for body in overlapping_bodies:
		if body.get_parent() != other_than:
			var vehicle = vehicle_manager.get_vehicle_from_area(body)

			if not vehicle:
				continue

			var current_step = vehicle.navigator.get_current_step()
			if current_step["type"] == Navigator.StepType.BUILDING and current_step["is_entering"]:
				continue

		return true

	return false

func set_debug_visuals_enabled(enabled: bool) -> void:
	debug_shape.visible = enabled


func _process(_delta: float) -> void:
	var overlapping_bodies = get_overlapping_areas()

	if overlapping_bodies.size() == 0:
		debug_shape.color = Color(0, 1, 0, 0.3)
	else:
		debug_shape.color = Color(1, 0, 0, 0.3)
