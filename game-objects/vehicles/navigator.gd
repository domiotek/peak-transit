extends RefCounted

class_name Navigator

var REROUTE_COOLDOWN = 5.0

enum StepType {
	SEGMENT,
	NODE,
	BUILDING
}

var vehicle: Vehicle
var path_follower: PathFollow2D
var network_manager: NetworkManager
var pathing_manager: PathingManager
var line_helper: LineHelper
var segment_helper: SegmentHelper

var trip_points: Array[int] = []
var trip_buildings: Array[BaseBuilding] = []
var trip_path: Array = []
var trip_step_index: int = 0

var first_step_forced_endpoint: int = -1
var last_step_forced_endpoint: int = -1

var current_step: Dictionary
var step_ready: bool = false

var traveled_distance_till_current_step: float = 0.0
var total_trip_distance: float = 0.0

var reroute_cooldown: float = 0.0


signal trip_started()
signal trip_ended(completed: bool)
signal trip_rerouted()

func setup(owner: Vehicle) -> void:
	vehicle = owner
	path_follower = vehicle.path_follower
	network_manager = GDInjector.inject("NetworkManager") as NetworkManager
	pathing_manager = GDInjector.inject("PathingManager") as PathingManager
	line_helper = GDInjector.inject("LineHelper") as LineHelper
	segment_helper = GDInjector.inject("SegmentHelper") as SegmentHelper


func setup_trip(from_endpoint_id: int, to_endpoint_id: int) -> void:
	trip_points = [from_endpoint_id, to_endpoint_id]

	pathing_manager.find_path(from_endpoint_id, to_endpoint_id, Callable(self, "_on_pathfinder_result"))

func setup_trip_between_buildings(from_building: BaseBuilding, to_building: BaseBuilding) -> void:
	var out_connections = from_building.get_out_connections()
	var in_connections = to_building.get_in_connections()

	var combinations = []
	for out_conn in out_connections:
		for in_conn in in_connections:
			var out_endpoint = out_conn["lane"].get_endpoint_by_type(true)
			var in_endpoint = in_conn["lane"].get_endpoint_by_type(false)
			combinations.append({
				"from_node": out_endpoint.NodeId,
				"to_node": in_endpoint.NodeId,
				"from_endpoint": out_endpoint.Id,
				"to_endpoint": in_endpoint.Id
			})

	trip_buildings = [from_building, to_building]

	pathing_manager.find_path_with_multiple_options(combinations, Callable(self, "_on_pathfinder_result"))


func get_current_step() -> Dictionary:
	current_step["progress"] = path_follower.progress

	return current_step

func get_distance_left() -> float:
	return current_step["length"] - current_step["progress"]

func can_advance(delta: float) -> bool:
	if reroute_cooldown > 0.0:
		reroute_cooldown = max(reroute_cooldown - delta, 0.0)

	return step_ready

func complete_current_step() -> void:
	step_ready = false

	traveled_distance_till_current_step += current_step["length"]

	if trip_step_index + 1 >= trip_path.size():
		if current_step.has("building_to_enter"):
			_enter_building()
		else:
			if current_step["target_building"].has_method("notify_vehicle_entered"):
				current_step["target_building"].notify_vehicle_entered()
			
			emit_signal("trip_ended", true)
	elif current_step["type"] == StepType.NODE:
		trip_step_index += 1
		_assign_to_step(trip_path[trip_step_index])
	elif current_step["type"] == StepType.BUILDING:
		_leave_building()
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

func reroute(force: bool = false, to_endpoint_id: int = -1) -> void:
	if current_step["type"] == StepType.NODE or current_step["type"] == StepType.BUILDING:
		return

	if not force and reroute_cooldown > 0.0:
		return

	reroute_cooldown = REROUTE_COOLDOWN

	step_ready = false

	var new_trip = [current_step["prev_node"], trip_points[1] if to_endpoint_id == -1 else to_endpoint_id]
	var finish_endpoint = segment_helper.get_other_endpoint_in_lane(last_step_forced_endpoint)

	pathing_manager.find_path(new_trip[0], new_trip[1], Callable(self, "_on_pathfinder_result"), current_step["from_endpoint"], finish_endpoint.Id)

func get_total_progress() -> float:
	if total_trip_distance == 0:
		return 0.0

	return (traveled_distance_till_current_step + current_step["progress"]) / total_trip_distance

func get_trip_curves() -> Array:
	var curves: Array = []

	var first_building_connection: Dictionary
	var last_building_connection: Dictionary

	if trip_buildings.size() > 0:
		var first_building = trip_buildings[0]
		first_building_connection = first_building.get_out_connection(first_step_forced_endpoint)
		curves.append(line_helper.convert_curve_local_to_global(first_building_connection["path"].curve, first_building))

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

	if trip_buildings.size() > 1:
		var last_building = trip_buildings[1]
		last_building_connection = last_building.get_in_connection(last_step_forced_endpoint)
		curves.append(line_helper.convert_curve_local_to_global(last_building_connection["path"].curve, last_building))

		curves[1] = segment_helper.trim_curve_to_building_connection(curves[1], first_building_connection["lane_point"], true)
		curves[curves.size() - 2] = segment_helper.trim_curve_to_building_connection(curves[curves.size() - 2], last_building_connection["lane_point"], false)

	return curves

func _on_pathfinder_result(path: Variant) -> void:
	if trip_path.size() > 0:
		_handle_reroute(path)
		return

	if path.State == 1:
		trip_path = path.Path
		trip_points = [path.StartNodeId, path.EndNodeId]

		first_step_forced_endpoint = segment_helper.get_other_endpoint_in_lane(path.ForcedStartEndpointId).Id
		last_step_forced_endpoint = segment_helper.get_other_endpoint_in_lane(path.ForcedEndEndpointId).Id

		call_deferred("_start_trip")
		call_deferred("_calc_trip_distance")
	else:
		emit_signal("trip_ended", false)

func _handle_reroute(path: Variant) -> void:
	if path.State != 1:
		step_ready = true
		return	# Failed to find a new path, continue current trip

	var existing_path = trip_path.slice(0, trip_step_index + 1)
	var remaining_existing_path = trip_path.slice(trip_step_index + 1, trip_path.size())
	var new_path = path.Path.slice(1, path.Path.size())

	var updated_path = existing_path + new_path

	var is_different = false

	for step_idx in range(new_path.size()):
		var new_step = new_path[step_idx]
		var existing_step = remaining_existing_path[step_idx]
		if new_step.ToNodeId != existing_step.ToNodeId or new_step.ViaEndpointId != existing_step.ViaEndpointId:
			is_different = true
			break

	if not is_different:
		step_ready = true
		return	# New path is the same as the remaining existing path, continue current trip

	trip_path = updated_path
	_assign_to_step(trip_path[trip_step_index], true)
	emit_signal("trip_rerouted")


func _calc_trip_distance() -> void:
	var curves = get_trip_curves()

	for curve in curves:
		total_trip_distance += curve.get_baked_length()

func _start_trip() -> void:
	var start_step = trip_path[0]

	if trip_buildings.size() > 0:
		var starting_step = _create_building_step(trip_buildings[0], trip_buildings[0].get_out_connection(first_step_forced_endpoint))
		_assign_to_building_step(starting_step)
	else:
		_assign_to_step(start_step)
	emit_signal("trip_started")


func _assign_to_step(step: Variant, leave_progress: bool = false) -> void:
	var endpoint_id = step.ViaEndpointId
	var endpoint = network_manager.get_lane_endpoint(endpoint_id)

	if current_step and current_step["type"] == StepType.NODE:
		var _node = current_step["node"]
		_node.intersection_manager.mark_vehicle_left(vehicle.id, current_step["from_endpoint"], current_step["to_endpoint"])

	var lane = network_manager.get_segment(endpoint.SegmentId).get_lane(endpoint.LaneId) as NetLane
	lane.assign_vehicle(vehicle)

	if not leave_progress:
		path_follower.reparent(lane.trail, true)
		path_follower.progress = 0.0

	current_step = _create_segment_step(lane)

	if trip_step_index == trip_path.size() - 1:
		var building_in_connection = trip_buildings[1].get_in_connection(last_step_forced_endpoint)
		current_step["building_to_enter"] = {
			"building": trip_buildings[1],
			"connection": building_in_connection,
			"trigger_distance": line_helper.get_distance_from_point(lane.trail.curve, building_in_connection["lane_point"])
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

func _create_building_step(building: BaseBuilding, connection: Dictionary) -> Dictionary:
	return {
		"type": StepType.BUILDING,
		"path": connection["path"].curve,
		"length": connection["path"].curve.get_baked_length(),
		"progress": 0.0,
		"target_building": building,
		"connection": connection,
		"target_lane": connection["lane"],
		"lane_point": connection["lane_point"],
		"next_node": null
	}

func _assign_to_building_step(step: Dictionary) -> void:
	path_follower.reparent(step["connection"]["path"], true)
	path_follower.progress = 0.0

	current_step = step
	step_ready = true

func _leave_building() -> void:
	var building_step = current_step
	var lane = building_step["target_lane"]

	if building_step["target_building"].has_method("notify_vehicle_left"):
		building_step["target_building"].notify_vehicle_left()

	path_follower.reparent(lane.trail, true)
	path_follower.progress = line_helper.get_distance_from_point(lane.trail.curve, building_step["lane_point"])
	
	current_step = _create_segment_step(lane)

	lane.assign_vehicle(vehicle)

	step_ready = true

func _enter_building() -> void:
	var building_data = current_step["building_to_enter"]

	var step = trip_path[trip_step_index]
	var endpoint_id = step.ViaEndpointId
	var endpoint = network_manager.get_lane_endpoint(endpoint_id)

	if building_data["building"].has_method("notify_vehicle_entering"):
		building_data["building"].notify_vehicle_entering(vehicle)

	var lane = network_manager.get_segment(endpoint.SegmentId).get_lane(endpoint.LaneId) as NetLane
	lane.remove_vehicle(vehicle)

	var next_step = _create_building_step(building_data["building"], building_data["connection"])

	_assign_to_building_step(next_step)


func _create_segment_step(lane: NetLane) -> Dictionary:
	var finish_endpoint = lane.get_endpoint_by_type(false)

	var prev_node_id = lane.segment.get_other_node_id(finish_endpoint.NodeId)

	var step = {
		"type": StepType.SEGMENT,
		"path": lane.trail.curve,
		"length": lane.trail.curve.get_baked_length(),
		"progress": 0.0,
		"max_speed": lane.get_max_allowed_speed(),
		"prev_node": prev_node_id,
		"from_endpoint": lane.from_endpoint,
		"to_endpoint": finish_endpoint.Id,
	}

	var node = network_manager.get_node(finish_endpoint.NodeId)

	if node:
		step["next_node"] = {
			"node": node,
			"is_intersection": node.connected_segments.size() > 2,
			"from": finish_endpoint.Id,
			"to": trip_path[trip_step_index + 1].ViaEndpointId if trip_step_index + 1 < trip_path.size() else null,
			"approaching_intersection": node.connected_segments.size() > 2
		}

	return step
