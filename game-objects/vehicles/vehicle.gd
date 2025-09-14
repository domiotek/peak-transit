extends Node2D

class_name Vehicle

var id: int

var acceleration: float = 50.0
var brake_force: float = 50.0
var current_speed: float = 0.0
var max_speed: float = 120.0
var target_speed: float = 0.0
var is_accelerating: bool = false
var is_braking: bool = false

var colliding_vehicle: Vehicle = null


var trip_points: Array[int] = []
var trip_path: Array = []
var trip_step_index: int = 0

var path_follower: PathFollow2D
var trail_curve: Curve2D
var trail_length: float
var next_node: Dictionary = {}
var passing_node: bool = false
var trail_ready: bool = false

@onready var interaction_area = $InteractionArea

@onready var close_caster = $CloseRayCaster
@onready var medium_caster = $MediumRayCaster
@onready var long_caster = $LongRayCaster

@onready var left_caster = $LeftRayCaster
@onready var right_caster = $RightRayCaster


signal trip_started(vehicle_id)
signal trip_completed(vehicle_id)
signal trip_abandoned(vehicle_id)


var network_manager: NetworkManager
var pathing_manager: PathingManager
var line_helper: LineHelper

func _init() -> void:
	network_manager = GDInjector.inject("NetworkManager") as NetworkManager
	pathing_manager = GDInjector.inject("PathingManager") as PathingManager
	line_helper = GDInjector.inject("LineHelper") as LineHelper

	path_follower = PathFollow2D.new()
	path_follower.loop = false
	add_child(path_follower)

func init_trip(from: int, to: int) -> void:
	if from == to:
		push_error("Invalid trip: Start and end nodes are the same for vehicle ID %d" % id)
		return

	trip_points = [from, to]

	var callback = Callable(self, "_retrieve_path")

	pathing_manager.find_path(from, to, callback)

func _retrieve_path(path: Variant): 
	if path.State == 1:
		trip_path = path.Path

		call_deferred("_start_trip")
	else:
		print("Path not found. Destroying vehicle. State:", path.State)
		emit_signal("trip_abandoned", id)


func _start_trip() -> void:
	interaction_area.connect("input_event", Callable(self, "_on_input_event"))
	emit_signal("trip_started", id)
	var start_step = trip_path[0]
	_assign_to_step(start_step)

func _on_input_event(_viewport, event, _shape_idx) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		emit_signal("trip_abandoned", id)


func _process(delta: float) -> void:
	if trail_curve == null or not trail_ready:
		return

	target_speed = max_speed

	_apply_slowdown_intersection()

	_check_forward_obstacles()

	_update_speed(delta)

	path_follower.progress_ratio += delta * current_speed / trail_length
	self.global_transform = path_follower.global_transform

	if path_follower.progress_ratio >= 1.0:
		_complete_current_step()

	$Body/Label.text = str(target_speed)


func _assign_to_step(step: Variant) -> void:
	var endpoint_id = step.ViaEndpointId
	var endpoint = network_manager.get_lane_endpoint(endpoint_id)
	self.position = endpoint.Position
	set_target_speed(max_speed)

	var lane = network_manager.get_segment(endpoint.SegmentId).get_lane(endpoint.LaneId) as NetLane
	trail_curve = lane.trail.curve
	trail_length = trail_curve.get_baked_length()

	path_follower.call_deferred("reparent", lane.trail, true)
	call_deferred("_setup_after_reparent")


	var finish_endpoint = lane.get_endpoint_by_type(!endpoint.IsOutgoing())

	var node = network_manager.get_node(finish_endpoint.NodeId)

	next_node = {
		"node": node,
		"is_intersection": node.connected_segments.size() > 2,
		"from": finish_endpoint.Id,
		"to": trip_path[trip_step_index + 1].ViaEndpointId if trip_step_index + 1 < trip_path.size() else null
	}

	trail_ready = true

func _complete_current_step() -> void:
	trail_ready = false
	trail_curve = null
	trail_length = 0.0

	if trip_step_index >= trip_path.size():
		emit_signal("trip_completed", id)
	elif passing_node:
		passing_node = false
		trip_step_index += 1
		_assign_to_step(trip_path[trip_step_index])
	else:
		_pass_node()

func _pass_node() -> void:
	passing_node = true

	if next_node.to == null:
		emit_signal("trip_completed", id)
		return

	var new_path = next_node.node.get_connection_path(next_node.from, next_node.to)

	trail_curve = new_path.curve
	trail_length = trail_curve.get_baked_length()
	path_follower.progress = 0.0
	path_follower.call_deferred("reparent", new_path, true)

	trail_ready = true


func _setup_after_reparent() -> void:
	path_follower.progress = 0.0
	self.visible = true

	trail_ready = true

func _update_speed(delta: float) -> void:

	var speed_difference = target_speed - current_speed

	if abs(speed_difference) == 0:
		_set_accelerating()
		return
	
	if speed_difference > 0:
		_set_accelerating()
		current_speed += acceleration * delta
		current_speed = min(current_speed, target_speed)
	else:
		_set_braking()
		current_speed -= brake_force * delta
		current_speed = max(current_speed, target_speed)
	
	current_speed = clamp(current_speed, 0.0, max_speed)

func set_target_speed(speed: float) -> void:
	target_speed = clamp(speed, 0.0, max_speed)

func _apply_slowdown_intersection() -> void:
	if passing_node or next_node.node == null:
		return

	var distance_to_node = trail_length - path_follower.progress
	var connected_segments = next_node.node.connected_segments.size()

	if connected_segments > 2 and distance_to_node < 200.0:
		set_target_speed(80)


func _check_forward_obstacles() -> void:
	_update_caster_visuals()

	if close_caster.is_colliding():
		set_target_speed(0)
		brake_force = 150.0
		return

	if not _check_turning_caster(left_caster):
		return

	if not _check_turning_caster(right_caster):
		return

	if medium_caster.is_colliding():
		set_target_speed(max(1, target_speed * 0.3))
		brake_force = 120.0
		return

	if long_caster.is_colliding():
		set_target_speed(max(5, target_speed * 0.4))
		brake_force = 80.0
		return

	if target_speed == 0:
		brake_force = 50.0

func _set_braking() -> void:
	is_braking = true
	is_accelerating = false

	$Body/LeftBrakeLight.set_active(true)
	$Body/RightBrakeLight.set_active(true)

func _set_accelerating() -> void:
	is_accelerating = true
	is_braking = false

	$Body/LeftBrakeLight.set_active(false)
	$Body/RightBrakeLight.set_active(false)


func _update_caster(caster_id: String) -> void:

	match caster_id:
		"close":
			$Body/CloseRayIndicator.set_active(close_caster.is_colliding())
		"medium":
			$Body/MediumRayIndicator.set_active(medium_caster.is_colliding())
		"long":
			$Body/LongRayIndicator.set_active(long_caster.is_colliding())
		"left":
			$Body/LeftRayIndicator.set_active(left_caster.is_colliding() && passing_node && next_node.is_intersection)
		"right":
			$Body/RightRayIndicator.set_active(right_caster.is_colliding() && passing_node && next_node.is_intersection)
		_:
			push_error("Unknown caster ID: %s" % id)

func _update_caster_visuals() -> void:
	var casters = ["close", "medium", "long", "left", "right"]

	for caster_id in casters:
		_update_caster(caster_id)

func _check_turning_caster(caster: RayCast2D) -> bool:
	var any_forward_caster = medium_caster.is_colliding() or long_caster.is_colliding()

	if passing_node && next_node.is_intersection && caster.is_colliding():
		var collider = caster.get_collider()

		if collider:
			var vehicle = collider.get_parent() as Vehicle

			if not line_helper.curves_intersect(self.trail_curve, vehicle.trail_curve, 10):
				return true

		set_target_speed(10 if not any_forward_caster else 0)
		brake_force = 320.0
		return false

	return true
