extends Node2D

class_name Vehicle

var navigator_module = load("res://game-objects/vehicles/navigator.gd")
var driver_module = load("res://game-objects/vehicles/driver.gd")
var ai_module = load("res://game-objects/vehicles/AI/car_ai.gd")

var id: int

var driver = Driver.new()
var navigator = Navigator.new()

@onready var path_follower: PathFollow2D = $PathFollower
@onready var body_area = $BodyArea
@onready var collision_area = $CollisionArea
@onready var forward_blockage_area = $ForwardBlockadeObserver


signal trip_started(vehicle_id)
signal trip_completed(vehicle_id)
signal trip_abandoned(vehicle_id)

@onready var game_manager: GameManager = GDInjector.inject("GameManager") as GameManager
@onready var network_manager: NetworkManager = GDInjector.inject("NetworkManager") as NetworkManager
@onready var pathing_manager: PathingManager = GDInjector.inject("PathingManager") as PathingManager
@onready var line_helper: LineHelper = GDInjector.inject("LineHelper") as LineHelper


func _ready():
	var ai = CarAI.new()
	driver.set_owner(self)
	driver.set_ai(ai)
	driver.set_navigator(navigator)
	driver.set_brake_lights([$Body/LeftBrakeLight, $Body/RightBrakeLight])
	driver.set_casters(
		{
			"close": $CloseRayCaster,
			"medium": $MediumRayCaster,
			"long": $LongRayCaster,
			"left": $LeftRayCaster,
			"right": $RightRayCaster
		}
	)
	driver.set_blockade_observer(forward_blockage_area)

	driver.connect("caster_state_changed", Callable(self, "_on_caster_state_changed"))
	driver.connect("state_changed", Callable(self, "_on_driver_state_changed"))

	navigator.connect("trip_started", Callable(self, "_on_trip_started"))
	navigator.connect("trip_ended", Callable(self, "_on_trip_ended"))
	navigator.setup(self)

func init_trip(from: int, to: int) -> void:
	if from == to:
		push_error("Invalid trip: Start and end nodes are the same for vehicle ID %d" % id)
		return

	navigator.setup_trip(from, to)

func get_popup_data() -> Dictionary:
	var data = {
		"speed": driver.get_current_speed(),
		"target_speed": driver.get_target_speed(),
		"state": Driver.VehicleState.keys()[driver.state],
		"from_node": navigator.trip_points[0] if navigator.trip_points.size() > 0 else null,
		"to_node": navigator.trip_points[1] if navigator.trip_points.size() > 1 else null,
		"step_type": Navigator.StepType.keys()[navigator.get_current_step().get("type")]
	}

	return data

func get_total_progress() -> float:
	return navigator.get_total_progress()

func get_all_trip_curves() -> Array:
	return navigator.get_trip_curves()

func _process(delta: float) -> void:
	if game_manager.is_debug_pick_enabled() && game_manager.try_hit_debug_pick(self):
		print("Debug pick triggered for vehicle ID %d" % id)
		breakpoint

	if not navigator.can_advance():
		return

	if driver.state == Driver.VehicleState.BLOCKED:
		if driver.just_enabled_casters:
			driver.just_enabled_casters = false
			return

		driver.check_blockade_cleared(delta)
		return

	var trail_length = navigator.get_current_step()["length"]

	var current_speed = driver.tick_speed(delta)

	path_follower.progress_ratio += delta * current_speed / trail_length
	self.global_transform = path_follower.global_transform

	if path_follower.progress_ratio >= 1.0:
		navigator.complete_current_step()

func _on_trip_started() -> void:
	body_area.connect("input_event", Callable(self, "_on_input_event"))
	collision_area.connect("area_entered", Callable(self, "_on_body_area_body_entered"))
	self.position = (navigator.get_current_step()["path"] as Curve2D).get_point_position(0)
	self.visible = true
	collision_area.monitoring = true
	collision_area.monitorable = true
	collision_area.get_child(0).set_deferred("disabled", false)
	emit_signal("trip_started", id)
	$Body/Label.text = str(id)

func _on_trip_ended(completed: bool) -> void:
	if completed:
		emit_signal("trip_completed", id)
	else:
		emit_signal("trip_abandoned", id)

func _on_input_event(_viewport, event, _shape_idx) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		game_manager.set_selection(self, GameManager.SelectionType.VEHICLE)

func _on_body_area_body_entered(_body) -> void:
	driver.emergency_stop()

func _on_caster_state_changed(caster_id: String, is_colliding: bool) -> void:
	match caster_id:
		"close":
			$Body/CloseRayIndicator.set_active(is_colliding)
		"medium":
			$Body/MediumRayIndicator.set_active(is_colliding)
		"long":
			$Body/LongRayIndicator.set_active(is_colliding)
		"left":
			$Body/LeftRayIndicator.set_active(is_colliding)
		"right":
			$Body/RightRayIndicator.set_active(is_colliding)

func _on_driver_state_changed(new_state: Driver.VehicleState) -> void:
	var line = $Body/Line2D as Line2D
	match new_state:
		Driver.VehicleState.BLOCKED:
			line.default_color = Color.RED
		_:
			line.default_color = Color.WHITE
