extends RefCounted

class_name Navigator

enum StepType {
	SEGMENT,
	NODE
}

var vehicle: Vehicle
var path_follower: PathFollow2D
var network_manager: NetworkManager
var pathing_manager: PathingManager
var line_helper: LineHelper

var trip_points: Array[int] = []
var trip_path: Array = []
var trip_step_index: int = 0

var current_step: Dictionary
var step_ready: bool = false

var traveled_distance_till_current_step: float = 0.0
var total_trip_distance: float = 0.0


signal trip_started()
signal trip_ended(completed: bool)

func setup(owner: Vehicle) -> void:
	vehicle = owner
	path_follower = vehicle.path_follower
	network_manager = GDInjector.inject("NetworkManager") as NetworkManager
	pathing_manager = GDInjector.inject("PathingManager") as PathingManager
	line_helper = GDInjector.inject("LineHelper") as LineHelper


func setup_trip(from_endpoint_id: int, to_endpoint_id: int) -> void:
	trip_points = [from_endpoint_id, to_endpoint_id]

	pathing_manager.find_path(from_endpoint_id, to_endpoint_id, Callable(self, "_on_pathfinder_result"))


func get_current_step() -> Dictionary:
	current_step["progress"] = path_follower.progress

	return current_step

func get_distance_left() -> float:
	return current_step["length"] - current_step["progress"]

func can_advance() -> bool:
	return step_ready

func complete_current_step() -> void:
	step_ready = false

	traveled_distance_till_current_step += current_step["length"]

	if trip_step_index + 1 >= trip_path.size():
		emit_signal("trip_ended", true)
	elif current_step["type"] == StepType.NODE:
		trip_step_index += 1
		_assign_to_step(trip_path[trip_step_index])
	else:
		_pass_node()

func clean_up() -> void:
	if current_step and current_step["type"] == StepType.SEGMENT:
		var step = trip_path[trip_step_index]
		var endpoint_id = step.ViaEndpointId
		var endpoint = network_manager.get_lane_endpoint(endpoint_id)

		var lane = network_manager.get_segment(endpoint.SegmentId).get_lane(endpoint.LaneId) as NetLane
		lane.remove_vehicle(vehicle)
	elif current_step["type"] == StepType.NODE:
		var node = current_step["node"]
		node.intersection_manager.mark_vehicle_left(vehicle.id, current_step["from_endpoint"], current_step["to_endpoint"])

func abandon_trip() -> void:
	clean_up()
	emit_signal("trip_ended", false)

func get_total_progress() -> float:
	if total_trip_distance == 0:
		return 0.0

	return (traveled_distance_till_current_step + current_step["progress"]) / total_trip_distance

func get_trip_curves() -> Array:
	var curves: Array = []

	for step_idx in range(trip_path.size()):
		var step = trip_path[step_idx]
		var endpoint = network_manager.get_lane_endpoint(step.ViaEndpointId)
		var lane = network_manager.get_segment(endpoint.SegmentId).get_lane(endpoint.LaneId) as NetLane
		var other_endpoint = lane.get_endpoint_by_type(false)
		curves.append(lane.trail.curve)

		if step.ToNodeId != trip_points[1]:
			var node = network_manager.get_node(step.ToNodeId)
			var next_step = trip_path[step_idx + 1]
			var node_path = node.get_connection_path(other_endpoint.Id, next_step.ViaEndpointId)
			curves.append(line_helper.convert_curve_local_to_global(node_path.curve, node))

	return curves

func _on_pathfinder_result(path: Variant) -> void:
	if path.State == 1:
		trip_path = path.Path

		call_deferred("_start_trip")
		call_deferred("_calc_trip_distance")
	else:
		emit_signal("trip_ended", false)

func _calc_trip_distance() -> void:
	var curves = get_trip_curves()

	for curve in curves:
		total_trip_distance += curve.get_baked_length()

func _start_trip() -> void:
	var start_step = trip_path[0]
	_assign_to_step(start_step)
	emit_signal("trip_started")


func _assign_to_step(step: Variant) -> void:
	var endpoint_id = step.ViaEndpointId
	var endpoint = network_manager.get_lane_endpoint(endpoint_id)

	if current_step and current_step["type"] == StepType.NODE:
		var _node = current_step["node"]
		_node.intersection_manager.mark_vehicle_left(vehicle.id, current_step["from_endpoint"], current_step["to_endpoint"])

	var lane = network_manager.get_segment(endpoint.SegmentId).get_lane(endpoint.LaneId) as NetLane
	lane.assign_vehicle(vehicle)
	var trail_length = lane.trail.curve.get_baked_length()

	path_follower.reparent(lane.trail, true)
	path_follower.progress = 0.0

	var finish_endpoint = lane.get_endpoint_by_type(!endpoint.IsOutgoing())

	current_step = {
		"type": StepType.SEGMENT,
		"path": lane.trail.curve,
		"length": trail_length,
		"progress": 0.0,
		"max_speed": lane.get_max_allowed_speed(),
	}

	var node = network_manager.get_node(finish_endpoint.NodeId)

	if node:
		current_step["next_node"] = {
			"node": node,
			"is_intersection": node.connected_segments.size() > 2,
			"from": finish_endpoint.Id,
			"to": trip_path[trip_step_index + 1].ViaEndpointId if trip_step_index + 1 < trip_path.size() else null,
			"approaching_intersection": node.connected_segments.size() > 2
		}

	step_ready = true

func _pass_node() -> void:
	var step = trip_path[trip_step_index]
	var endpoint_id = step.ViaEndpointId
	var endpoint = network_manager.get_lane_endpoint(endpoint_id)

	var lane = network_manager.get_segment(endpoint.SegmentId).get_lane(endpoint.LaneId) as NetLane
	lane.remove_vehicle(vehicle)

	var node = current_step["next_node"].node
	var new_path = node.get_connection_path(current_step["next_node"].from, current_step["next_node"].to)
	node.intersection_manager.register_crossing_vehicle(vehicle.id, current_step["next_node"].from, current_step["next_node"].to)

	current_step = {
		"type": StepType.NODE,
		"path": line_helper.convert_curve_local_to_global(new_path.curve, node),
		"length": new_path.curve.get_baked_length(),
		"progress": 0.0,
		"node": node,
		"from_endpoint": current_step["next_node"].from,
		"to_endpoint": current_step["next_node"].to,
		"is_intersection": node.connected_segments.size() > 2,
	}

	path_follower.reparent(new_path, true)
	path_follower.progress = 0.0

	step_ready = true	
