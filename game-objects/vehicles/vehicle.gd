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


@onready var network_manager: NetworkManager = GDInjector.inject("NetworkManager") as NetworkManager
@onready var pathing_manager: PathingManager = GDInjector.inject("PathingManager") as PathingManager
@onready var line_helper: LineHelper = GDInjector.inject("LineHelper") as LineHelper


func _ready():
	var ai = CarAI.new()
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

	navigator.connect("trip_started", Callable(self, "_on_trip_started"))
	navigator.connect("trip_ended", Callable(self, "_on_trip_ended"))
	navigator.setup(path_follower)

func init_trip(from: int, to: int) -> void:
	if from == to:
		push_error("Invalid trip: Start and end nodes are the same for vehicle ID %d" % id)
		return

	navigator.setup_trip(from, to)


func _process(delta: float) -> void:
	if not navigator.can_advance():
		return

	if driver.state == Driver.VehicleState.BLOCKED:
		driver.check_blockade_cleared()
		return

	var trail_length = navigator.get_current_step()["length"]

	var current_speed = driver.tick_speed(delta)

	path_follower.progress_ratio += delta * current_speed / trail_length
	self.global_transform = path_follower.global_transform

	if path_follower.progress_ratio >= 1.0:
		navigator.complete_current_step()

	$Body/Label.text = str(driver.get_target_speed())

func _on_trip_started() -> void:
	body_area.connect("input_event", Callable(self, "_on_input_event"))
	collision_area.connect("area_entered", Callable(self, "_on_body_area_body_entered"))
	emit_signal("trip_started", id)

func _on_trip_ended(completed: bool) -> void:
	if completed:
		emit_signal("trip_completed", id)
	else:
		emit_signal("trip_abandoned", id)

func _on_input_event(_viewport, event, _shape_idx) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		emit_signal("trip_abandoned", id)

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
