extends Node2D

class_name Vehicle

var id: int
var type: VehicleManager.VehicleType

var ai
var driver = Driver.new()
var navigator = Navigator.new()

signal trip_started(vehicle_id)
signal trip_completed(vehicle_id)
signal trip_abandoned(vehicle_id)
signal trip_ended(vehicle_id, completed: bool)
signal destroyed(vehicle_id)

@onready var game_manager: GameManager = GDInjector.inject("GameManager") as GameManager
@onready var simulation_manager: SimulationManager = GDInjector.inject("SimulationManager") as SimulationManager
@onready var network_manager: NetworkManager = GDInjector.inject("NetworkManager") as NetworkManager
@onready var pathing_manager: PathingManager = GDInjector.inject("PathingManager") as PathingManager
@onready var line_helper: LineHelper = GDInjector.inject("LineHelper") as LineHelper
@onready var config_manager: ConfigManager = GDInjector.inject("ConfigManager") as ConfigManager

var config: VehicleConfig

var main_path_follower: PathFollow2D

var _trailer_states: Array[Dictionary] = []
var _previous_front_rotation: float = 0.0
var _previous_front_position: Vector2 = Vector2.ZERO
var _smoothed_curvature: float = 0.0


func _ready():
	self.visible = false

	driver.set_owner(self)

	var vehicle_config = _get_vehicle_config() as VehicleConfig

	if not vehicle_config:
		push_error("Vehicle ID %d has no config assigned!" % id)
		return
	config = vehicle_config

	if config.body_color:
		recolor(config.body_color)

	config_manager.DebugToggles.connect("ToggleChanged", Callable(self, "_on_debug_toggle_changed"))
	_toggle_debug_indicators(config_manager.DebugToggles.UseVehicleDebugIndicators)

	main_path_follower = config.path_follower

	config["ai"].bind(self)
	driver.set_navigator(navigator)
	driver.set_lights(config.head_lights, config.brake_lights, config.left_blinker_nodes, config.right_blinker_nodes)
	driver.set_casters(config["casters"])

	driver.set_blockade_observer(config["blockade_observer"])

	driver.connect("caster_state_changed", Callable(self, "_on_caster_state_changed"))
	driver.connect("state_changed", Callable(self, "_on_driver_state_changed"))

	navigator.connect("trip_started", Callable(self, "_on_trip_started"))
	navigator.connect("trip_ended", Callable(self, "_on_trip_ended"))
	navigator.setup(self)

	simulation_manager.desired_world_lights_state_changed.connect(Callable(self, "_on_lights_state_change"))

	for body_area in config["body_areas"]:
		body_area.connect("input_event", Callable(self, "_on_input_event"))

	for collision_area in config["collision_areas"]:
		collision_area.connect("area_entered", Callable(self, "_on_body_area_body_entered"))

	for trailer_def in config.trailers:
		var trailer_body = trailer_def["body"]

		_trailer_states.append(
			{
				"body": trailer_body,
				"offset": trailer_def.get("offset"),
				"articulation_angle": 0.0,
			},
		)


func _exit_tree() -> void:
	destroyed.emit(id)


func init_trip(from_building: BaseBuilding, to_building: BaseBuilding) -> void:
	if from_building == to_building:
		push_error("Invalid trip: Start and end buildings are the same for vehicle ID %d" % id)
		return

	navigator.setup_trip_between_buildings(from_building, to_building)


func init_trip_to_building(from_node_id: int, to_building: BaseBuilding, forced_start_endpoint: int = -1) -> void:
	navigator.setup_trip_mixed(from_node_id, to_building.id, false, forced_start_endpoint)


func init_trip_from_building(to_node_id: int, from_building: BaseBuilding, forced_end_endpoint: int = -1) -> void:
	navigator.setup_trip_mixed(from_building.id, to_node_id, true, forced_end_endpoint)


func init_simple_trip(from_node_id: int, to_node_id: int, from_endpoint: int = -1, to_endpoint: int = -1) -> void:
	if from_node_id == to_node_id:
		push_error("Invalid trip: Start and end nodes are the same for vehicle ID %d" % id)
		return

	navigator.setup_trip(from_node_id, to_node_id, from_endpoint, to_endpoint)


func init_trip_with_path(path: Array, from_building: BaseBuilding = null, to_building: BaseBuilding = null) -> void:
	navigator.setup_trip_with_path(path, from_building, to_building)


func get_popup_data() -> Dictionary:
	var from_node = "N/A"
	var to_node = "N/A"
	var step_type = "N/A"

	if navigator.has_trip():
		from_node = navigator.trip_points[0]
		to_node = navigator.trip_points[-1]
		step_type = Navigator.StepType.keys()[navigator.get_current_step().get("type")]

	var data = {
		"speed": driver.get_current_speed(),
		"target_speed": driver.get_target_speed(),
		"max_speed": driver.get_max_allowed_speed(),
		"state": Driver.VehicleState.keys()[driver.state],
		"from_node": from_node,
		"to_node": to_node,
		"step_type": step_type,
		"time_blocked": int(driver.get_time_blocked()),
	}

	return data


func get_total_progress() -> float:
	return navigator.get_total_progress()


func get_all_trip_curves() -> Array:
	return navigator.get_trip_curves()


func assign_to_path(path: Path2D, progress: float) -> void:
	main_path_follower.reparent(path, true)
	main_path_follower.progress = progress


func recolor(new_color: Color) -> void:
	for body in config.body_segments:
		body.color = new_color


func _physics_process(_delta: float) -> void:
	if driver.just_enabled_casters:
		driver.just_enabled_casters = false
		return


func _process(delta: float) -> void:
	if game_manager.is_debug_pick_enabled() && game_manager.try_hit_debug_pick(self):
		print("Debug pick triggered for vehicle ID %d" % id)
		breakpoint

	ai.process(delta)

	driver.tick_lights(delta)

	if not navigator.can_advance(delta):
		driver.set_idle()
		return

	if driver.state == Driver.VehicleState.BLOCKED:
		if driver.just_enabled_casters:
			return

		driver.check_blockade_cleared(delta)
		return

	var current_speed = driver.tick_speed(delta, main_path_follower.progress)

	_update_position(delta, current_speed)

	if main_path_follower.progress_ratio >= 1.0 or _check_for_building_entry():
		navigator.complete_current_step()


func _update_position(delta: float, current_speed: float) -> void:
	var trail_length = navigator.get_current_step()["length"]

	main_path_follower.progress_ratio += delta * current_speed / trail_length
	self.global_transform = main_path_follower.global_transform

	var front_pos: Vector2 = self.global_position
	var front_rot: float = self.global_rotation

	var rotation_change = front_rot - _previous_front_rotation
	while rotation_change > PI:
		rotation_change -= 2 * PI
	while rotation_change < -PI:
		rotation_change += 2 * PI

	var instant_curvature = rotation_change / delta if delta > 0 else 0.0

	var smoothing_factor = 0.2
	_smoothed_curvature = lerp(_smoothed_curvature, instant_curvature, smoothing_factor)

	var curvature_deadzone = 0.05
	var effective_curvature = _smoothed_curvature if abs(_smoothed_curvature) > curvature_deadzone else 0.0
	var max_articulation_speed: float = 2.0

	for trailer_state in _trailer_states:
		var trailer_body: Node2D = trailer_state["body"]
		var offset: float = trailer_state["offset"]

		var target_phi: float = -effective_curvature * 0.3

		var max_target_phi = deg_to_rad(45.0)
		target_phi = clamp(target_phi, -max_target_phi, max_target_phi)

		var dphi: float = target_phi - trailer_state["articulation_angle"]
		var max_step: float = max_articulation_speed * delta
		dphi = clamp(dphi, -max_step, max_step)
		trailer_state["articulation_angle"] += dphi

		var trailer_rot: float = front_rot + trailer_state["articulation_angle"]
		var trailer_pos: Vector2 = front_pos - Vector2.RIGHT.rotated(trailer_rot) * offset

		trailer_body.global_rotation = trailer_rot

		front_pos = trailer_pos
		front_rot = trailer_rot

	_previous_front_rotation = self.global_rotation
	_previous_front_position = self.global_position


func _on_trip_started() -> void:
	var starts_at_building = navigator.current_step["type"] == Navigator.StepType.BUILDING

	if starts_at_building:
		var building_pos = navigator.current_step["connection"]["from"]
		self.position = building_pos
		var lane = navigator.current_step["connection"]["lane"] as NetLane
		self.rotation = line_helper.rotate_perpendicular_to_curve(lane.get_curve(), building_pos)
	else:
		self.position = (navigator.get_current_step()["path"] as Curve2D).get_point_position(0)
	set_deferred("visible", true)
	driver.set_headlights_enabled(simulation_manager.get_desired_world_lights_state(), true)

	for collision_area in config["collision_areas"]:
		collision_area.monitoring = true
		collision_area.monitorable = true
		collision_area.get_child(0).set_deferred("disabled", false)

	emit_signal("trip_started", id)
	config["id_label"].text = str(id)


func _on_trip_ended(completed: bool, trip_data: Dictionary) -> void:
	driver.ai.on_trip_finished(completed, trip_data)

	if completed:
		emit_signal("trip_completed", id)
	else:
		emit_signal("trip_abandoned", id)

	emit_signal("trip_ended", id, completed)


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


func _on_lights_state_change(should_be_on: bool) -> void:
	driver.set_headlights_enabled(should_be_on, false)

func _on_debug_toggle_changed(toggle_name: String, value: bool) -> void:
	if toggle_name == "UseVehicleDebugIndicators":
		_toggle_debug_indicators(value)


func _toggle_debug_indicators(enabled: bool) -> void:
	for indicator in config.caster_indicators.values():
		indicator.visible = enabled

	config.blockade_indicator.visible = enabled
	config.id_label.visible = enabled
