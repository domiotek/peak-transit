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

var trip_points: Array[int] = []
var trip_path: Array = []
var trip_step_index: int = 0

var current_step: Dictionary
var step_ready: bool = false


signal trip_started()
signal trip_ended(completed: bool)

func setup(owner: Vehicle) -> void:
	vehicle = owner
	path_follower = vehicle.path_follower
	network_manager = GDInjector.inject("NetworkManager") as NetworkManager
	pathing_manager = GDInjector.inject("PathingManager") as PathingManager


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
		node.mark_vehicle_left(vehicle.id, current_step["from_endpoint"], current_step["to_endpoint"])

func _on_pathfinder_result(path: Variant) -> void:
	if path.State == 1:
		trip_path = path.Path

		call_deferred("_start_trip")
	else:
		emit_signal("trip_ended", false)

func _start_trip() -> void:
	var start_step = trip_path[0]
	_assign_to_step(start_step)
	emit_signal("trip_started")


func _assign_to_step(step: Variant) -> void:
	var endpoint_id = step.ViaEndpointId
	var endpoint = network_manager.get_lane_endpoint(endpoint_id)

	if current_step and current_step["type"] == StepType.NODE:
		var _node = current_step["node"]
		_node.mark_vehicle_left(vehicle.id, current_step["from_endpoint"], current_step["to_endpoint"])

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
	node.register_crossing_vehicle(vehicle.id, current_step["next_node"].from, current_step["next_node"].to)

	current_step = {
		"type": StepType.NODE,
		"path": new_path.curve,
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
