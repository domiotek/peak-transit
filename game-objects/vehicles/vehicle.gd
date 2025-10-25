extends Node2D

class_name Vehicle

var id: int

var driver = Driver.new()
var navigator = Navigator.new()

signal trip_started(vehicle_id)
signal trip_completed(vehicle_id)
signal trip_abandoned(vehicle_id)

@onready var game_manager: GameManager = GDInjector.inject("GameManager") as GameManager
@onready var network_manager: NetworkManager = GDInjector.inject("NetworkManager") as NetworkManager
@onready var pathing_manager: PathingManager = GDInjector.inject("PathingManager") as PathingManager
@onready var line_helper: LineHelper = GDInjector.inject("LineHelper") as LineHelper

var config: Dictionary

var main_path_follower: PathFollow2D


func _ready():
	driver.set_owner(self)

	var vehicle_config = _get_vehicle_config()

	if not vehicle_config:
		push_error("Vehicle ID %d has no config assigned!" % id)
		return
	config = vehicle_config

	main_path_follower = config["path_followers"][0]["follower"]
	
	driver.set_ai(config["ai"])
	driver.set_navigator(navigator)
	driver.set_brake_lights(config["brake_lights"])
	driver.set_casters(config["casters"])

	driver.set_blockade_observer(config["blockade_observer"])

	driver.connect("caster_state_changed", Callable(self, "_on_caster_state_changed"))
	driver.connect("state_changed", Callable(self, "_on_driver_state_changed"))

	navigator.connect("trip_started", Callable(self, "_on_trip_started"))
	navigator.connect("trip_ended", Callable(self, "_on_trip_ended"))
	navigator.setup(self)

func init_trip(from_building: BaseBuilding, to_building: BaseBuilding) -> void:
	if from_building == to_building:
		push_error("Invalid trip: Start and end buildings are the same for vehicle ID %d" % id)
		return

	navigator.setup_trip_between_buildings(from_building, to_building)

func init_simple_trip(from_node_id: int, to_node_id: int) -> void:
	if from_node_id == to_node_id:
		push_error("Invalid trip: Start and end nodes are the same for vehicle ID %d" % id)
		return

	navigator.setup_trip(from_node_id, to_node_id)

func get_popup_data() -> Dictionary:
	var data = {
		"speed": driver.get_current_speed(),
		"target_speed": driver.get_target_speed(),
		"max_speed": driver.get_max_allowed_speed(),
		"state": Driver.VehicleState.keys()[driver.state],
		"from_node": navigator.trip_points[0] if navigator.trip_points.size() > 0 else null,
		"to_node": navigator.trip_points[1] if navigator.trip_points.size() > 1 else null,
		"step_type": Navigator.StepType.keys()[navigator.get_current_step().get("type")],
		"time_blocked": int(driver.get_time_blocked())
	}

	return data

func get_total_progress() -> float:
	return navigator.get_total_progress()

func get_all_trip_curves() -> Array:
	return navigator.get_trip_curves()

func assign_to_path(path: Path2D, progress: float) -> void:
	main_path_follower.reparent(path, true)
	main_path_follower.progress = progress

func _physics_process(_delta: float) -> void:
	if driver.just_enabled_casters:
		driver.just_enabled_casters = false
		return


func _process(delta: float) -> void:
	if game_manager.is_debug_pick_enabled() && game_manager.try_hit_debug_pick(self):
		print("Debug pick triggered for vehicle ID %d" % id)
		breakpoint

	if not navigator.can_advance(delta):
		return

	if driver.state == Driver.VehicleState.BLOCKED:
		if driver.just_enabled_casters:
			return

		driver.check_blockade_cleared(delta)
		return

	var trail_length = navigator.get_current_step()["length"]

	var current_speed = driver.tick_speed(delta)

	main_path_follower.progress_ratio += delta * current_speed / trail_length
	self.global_transform = main_path_follower.global_transform
	
	for path_follower_def in config["path_followers"]:
		var path_follower = path_follower_def["follower"]
		if path_follower == main_path_follower:
			continue

		var target_body = path_follower_def["body"]

		var is_initialized = path_follower.get_parent() != target_body

		if not is_initialized and main_path_follower.progress < path_follower_def["offset"]:
			continue
		
		if not is_initialized or path_follower.progress_ratio == 1.0:
			var next_path = navigator.get_next_path(path_follower.get_parent() as Path2D)
			if not next_path:
				next_path = main_path_follower.get_parent() as Path2D
				
			path_follower.reparent(next_path, true)
			path_follower.progress = 0

		var trailer_path = (path_follower.get_parent() as Path2D).curve

		path_follower.progress_ratio += delta * current_speed / trailer_path.get_baked_length()
		var trailer_direction = path_follower.global_rotation
	
		var vehicle_direction = self.global_rotation
		var desired_trailer_rotation = trailer_direction - vehicle_direction
		
		while desired_trailer_rotation > PI:
			desired_trailer_rotation -= 2 * PI
		while desired_trailer_rotation < -PI:
			desired_trailer_rotation += 2 * PI

		var max_articulation = deg_to_rad(90.0)
		var articulation_angle = clamp(desired_trailer_rotation, -max_articulation, max_articulation)

		target_body.rotation = articulation_angle

	if main_path_follower.progress_ratio >= 1.0 or _check_for_building_entry():
		navigator.complete_current_step()

func _on_trip_started() -> void:
	for body_area in config["body_areas"]:
		body_area.connect("input_event", Callable(self, "_on_input_event"))

	for collision_area in config["collision_areas"]:
		collision_area.connect("area_entered", Callable(self, "_on_body_area_body_entered"))
	
	var starts_at_building = navigator.current_step["type"] == Navigator.StepType.BUILDING

	if starts_at_building:
		var building_pos = navigator.current_step["connection"]["from"]
		self.position = building_pos
		var lane = navigator.current_step["connection"]["lane"] as NetLane
		self.rotation = line_helper.rotate_perpendicular_to_curve(lane.get_curve(), building_pos)
	else:
		self.position = (navigator.get_current_step()["path"] as Curve2D).get_point_position(0)
	set_deferred("visible", true)

	for collision_area in config["collision_areas"]:
		collision_area.monitoring = true
		collision_area.monitorable = true
		collision_area.get_child(0).set_deferred("disabled", false)

	emit_signal("trip_started", id)
	config["id_label"].text = str(id)

func _on_trip_ended(completed: bool) -> void:
	if completed:
		emit_signal("trip_completed", id)
	else:
		emit_signal("trip_abandoned", id)

func _on_input_event(_viewport, event, _shape_idx) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		game_manager.set_selection(self, GameManager.SelectionType.VEHICLE)

func _on_body_area_body_entered(_body) -> void:
	if config["collision_areas"].has(_body):
		return

	driver.emergency_stop()

func _on_caster_state_changed(caster_id: String, is_colliding: bool) -> void:
	match caster_id:
		"close":
			config["caster_indicators"]["close"].set_active(is_colliding)
		"medium":
			config["caster_indicators"]["medium"].set_active(is_colliding)
		"long":
			config["caster_indicators"]["long"].set_active(is_colliding)
		"left":
			config["caster_indicators"]["left"].set_active(is_colliding)
		"right":
			config["caster_indicators"]["right"].set_active(is_colliding)

func _on_driver_state_changed(new_state: Driver.VehicleState) -> void:
	var line = config["blockade_indicator"] as Line2D
	match new_state:
		Driver.VehicleState.BLOCKED:
			line.default_color = Color.RED
		_:
			line.default_color = Color.WHITE

func _check_for_building_entry() -> bool:
	if not navigator.current_step.has("building_to_enter"):
		return false

	var trigger_distance = navigator.current_step["building_to_enter"]["trigger_distance"]

	return main_path_follower.progress >= trigger_distance


func _get_vehicle_config() -> Variant:
	return null
