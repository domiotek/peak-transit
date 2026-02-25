extends Area2D

class_name CollisionZone

@onready var collision_shape: CollisionShape2D = $CollisionShape
@onready var debug_shape: Polygon2D = $DebugShape

@onready var vehicle_manager: VehicleManager = GDInjector.inject("VehicleManager") as VehicleManager

var _tracked_overlaps: Dictionary[int, Area2D] = { }


func _ready() -> void:
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)

	for area in get_overlapping_areas():
		_register_overlap(area)


func set_size_scale(scale_factor: float) -> void:
	self.scale = Vector2(scale_factor, 1.0)


func has_vehicles_inside(other_than: Vehicle) -> bool:
	_cleanup_invalid_overlaps()

	for body in _tracked_overlaps.values():
		if body.get_parent() != other_than:
			var vehicle := vehicle_manager.get_vehicle_from_area(body)

			if not vehicle:
				continue

			var current_step := vehicle.navigator.get_current_step() as NavigationStep
			if current_step.type == Navigator.StepType.BUILDING and current_step.is_entering:
				continue

		return true

	return false


func set_debug_visuals_enabled(enabled: bool) -> void:
	debug_shape.visible = enabled


func _process(_delta: float) -> void:
	_cleanup_invalid_overlaps()

	if _tracked_overlaps.size() == 0:
		debug_shape.color = Color(0, 1, 0, 0.3)
	else:
		debug_shape.color = Color(1, 0, 0, 0.3)


func _on_area_entered(area: Area2D) -> void:
	_register_overlap(area)


func _on_area_exited(area: Area2D) -> void:
	_unregister_overlap(area)


func _register_overlap(area: Area2D) -> void:
	if not is_instance_valid(area):
		return

	_tracked_overlaps[area.get_instance_id()] = area


func _unregister_overlap(area: Area2D) -> void:
	if area == null:
		return

	_tracked_overlaps.erase(area.get_instance_id())


func _cleanup_invalid_overlaps() -> void:
	if _tracked_overlaps.size() == 0:
		return

	for area_id in _tracked_overlaps.keys():
		var area = _tracked_overlaps[area_id] as Area2D
		if not is_instance_valid(area):
			_tracked_overlaps.erase(area_id)
