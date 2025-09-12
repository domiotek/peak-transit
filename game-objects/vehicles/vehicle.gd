extends Node2D

class_name Vehicle

var id: int

var speed: float = 100.0

var trip_points: Array[int] = []
var trip_path: Array = []
var trip_step_index: int = 0

var path_follower: PathFollow2D
var trail_curve: Curve2D
var trail_length: float
var trail_end_offset: float
var next_node: Dictionary = {}
var passing_node: bool = false
var trail_ready: bool = false


signal trip_started(vehicle_id)
signal trip_completed(vehicle_id)
signal trip_abandoned(vehicle_id)


var network_manager: NetworkManager
var pathing_manager: PathingManager

func _init() -> void:
	network_manager = GDInjector.inject("NetworkManager") as NetworkManager
	pathing_manager = GDInjector.inject("PathingManager") as PathingManager

	path_follower = PathFollow2D.new()
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
		print("Path found from %d to %d:" % [trip_points[0], trip_points[1]])

		for step in path.Path:
			var endpoint_id = ""

			if "ViaEndpointId" in step:
				endpoint_id = step.ViaEndpointId
			print("Step: ", step.FromNodeId," -> ", step.ToNodeId, " Via:", endpoint_id)

		call_deferred("_start_trip")
	else:
		print("Path not found. Destroying vehicle. State:", path.State)
		emit_signal("trip_abandoned", id)


func _start_trip() -> void:
	emit_signal("trip_started", id)
	var start_step = trip_path[0]

	_assign_to_step(start_step)


func _process(delta: float) -> void:
	if trail_curve == null or not trail_ready:
		return

	path_follower.progress_ratio +=  delta * speed / trail_length
	self.global_transform = path_follower.global_transform


	if path_follower.progress >= trail_end_offset or path_follower.progress_ratio >= 0.97:
		_complete_current_step()


func _assign_to_step(step: Variant) -> void:
	var endpoint_id = step.ViaEndpointId
	var endpoint = network_manager.get_lane_endpoint(endpoint_id)
	self.position = endpoint.Position
	self.visible = true

	var lane = network_manager.get_segment(endpoint.SegmentId).get_lane(endpoint.LaneId) as NetLane
	trail_curve = lane.trail.curve
	trail_length = trail_curve.get_baked_length()

	path_follower.call_deferred("reparent", lane.trail, true)
	
	var start_pos = lane.trail.to_local(endpoint.Position)
	var offset = trail_curve.get_closest_offset(start_pos)

	var setup_data = {
		"trail": lane.trail,
		"offset": offset,
		"start_pos": start_pos
	}

	path_follower.call_deferred("reparent", lane.trail, true)
	call_deferred("_setup_after_reparent", setup_data)


	var finish_endpoint = lane.get_endpoint_by_type(!endpoint.IsOutgoing())
	var finish_pos = lane.trail.to_local(finish_endpoint.Position)
	trail_end_offset = trail_curve.get_closest_offset(finish_pos)

	next_node = {
		"node": network_manager.get_node(finish_endpoint.NodeId),
		"from": finish_endpoint.Id,
		"to": trip_path[trip_step_index + 1].ViaEndpointId if trip_step_index + 1 < trip_path.size() else null
	}

	trail_ready = true

func _complete_current_step() -> void:
	trail_ready = false
	trail_curve = null
	trail_length = 0.0
	trail_end_offset = 0.0

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

	trail_end_offset = trail_length
	trail_ready = true

func _setup_after_reparent(setup_data: Dictionary) -> void:
	path_follower.progress = setup_data.offset

	trail_ready = true
