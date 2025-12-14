extends RefCounted

class_name Navigator

const REROUTE_COOLDOWN = 5.0

enum StepType {
	NONE,
	CUSTOM,
	SEGMENT,
	NODE,
	BUILDING,
}

var vehicle: Vehicle
var path_follower: PathFollow2D
var network_manager: NetworkManager
var buildings_manager: BuildingsManager
var pathing_manager: PathingManager
var line_helper: LineHelper
var segment_helper: SegmentHelper

var trip_points: Array[int] = []
# Array of BaseBuilding, size 0 or 2, but can have nulls for mixed trips
var trip_buildings: Array = []
var trip_path: Array = []
var trip_step_index: int = 0

var first_step_forced_endpoint: int = -1
var last_step_forced_endpoint: int = -1

var current_step: Dictionary = {
	"type": StepType.NONE,
}
var step_ready: bool = false

var traveled_distance_till_current_step: float = 0.0
var total_trip_distance: float = 0.0

var reroute_cooldown: float = 0.0
var _is_rerouting_enabled: bool = true

var trip_curves_cache: Array = []
var _location_triggers: Dictionary = {
	"segment": [],
	"node": [],
}
var _progress_offset: float = 0.0

signal trip_started()
signal trip_ended(completed: bool, trip_data: Dictionary)
signal trip_rerouted()


func setup(owner: Vehicle) -> void:
	vehicle = owner
	path_follower = vehicle.main_path_follower
	network_manager = GDInjector.inject("NetworkManager") as NetworkManager
	buildings_manager = GDInjector.inject("BuildingsManager") as BuildingsManager
	pathing_manager = GDInjector.inject("PathingManager") as PathingManager
	line_helper = GDInjector.inject("LineHelper") as LineHelper
	segment_helper = GDInjector.inject("SegmentHelper") as SegmentHelper


func setup_trip(from_node_id: int, to_node_id: int) -> void:
	trip_points = [from_node_id, to_node_id]

	pathing_manager.find_path(from_node_id, to_node_id, Callable(self, "_on_pathfinder_result"), vehicle.config.category)


func setup_trip_between_buildings(from_building: BaseBuilding, to_building: BaseBuilding) -> void:
	var out_connections = from_building.get_out_connections()
	var in_connections = to_building.get_in_connections()

	var combinations = []
	for out_conn in out_connections:
		for in_conn in in_connections:
			var out_endpoint = out_conn["lane"].get_endpoint_by_type(true)
			var in_endpoint = in_conn["lane"].get_endpoint_by_type(false)
			combinations.append(
				{
					"from_node": out_endpoint.NodeId,
					"to_node": in_endpoint.NodeId,
					"from_endpoint": out_endpoint.Id,
					"to_endpoint": in_endpoint.Id,
				},
			)

	trip_buildings = [from_building, to_building]

	pathing_manager.find_path_with_multiple_options(combinations, Callable(self, "_on_pathfinder_result"), vehicle.config.category)


func setup_trip_mixed(from_id: int, to_id: int, is_from_building: bool, forced_node_endpoint: int = -1) -> void:
	var target_building_id = from_id if is_from_building else to_id
	var target_building = buildings_manager.get_building(target_building_id) as BaseBuilding
	if not target_building:
		push_error("Navigator: Invalid building ID %d for mixed trip setup." % target_building_id)
		return

	var building_connections = target_building.get_out_connections() if is_from_building else target_building.get_in_connections()

	var combinations = []
	for conn in building_connections:
		var endpoint = conn["lane"].get_endpoint_by_type(is_from_building)

		combinations.append(
			{
				"from_node": endpoint.NodeId if is_from_building else from_id,
				"to_node": to_id if is_from_building else endpoint.NodeId,
				"from_endpoint": endpoint.Id if is_from_building else forced_node_endpoint,
				"to_endpoint": forced_node_endpoint if is_from_building else endpoint.Id,
			},
		)

	trip_buildings = [target_building, null] if is_from_building else [null, target_building]

	pathing_manager.find_path_with_multiple_options(combinations, Callable(self, "_on_pathfinder_result"), vehicle.config.category)


func setup_trip_with_path(path: Array, from_building: BaseBuilding = null, to_building: BaseBuilding = null) -> void:
	trip_path = path.duplicate()

	if trip_path.size() == 0:
		push_error("Navigator: Cannot setup trip with empty path.")
		return

	trip_points = [trip_path[0].FromNodeId, trip_path[-1].ToNodeId]
	trip_buildings = [from_building, to_building]

	first_step_forced_endpoint = segment_helper.get_other_endpoint_in_lane(trip_path[0].ViaEndpointId).Id
	last_step_forced_endpoint = trip_path[-1].ViaEndpointId

	call_deferred("_start_trip")
	call_deferred("_calc_trip_distance")


func has_trip() -> bool:
	return trip_path.size() > 0


func get_current_step() -> Dictionary:
	current_step["progress"] = path_follower.progress - _progress_offset

	return current_step


func get_distance_left() -> float:
	return current_step["length"] - current_step["progress"]


func can_advance(delta: float) -> bool:
	if reroute_cooldown > 0.0:
		reroute_cooldown = max(reroute_cooldown - delta, 0.0)

	_tick_segment_triggers()

	return step_ready


func complete_current_step() -> void:
	if not step_ready:
		return

	step_ready = false

	_progress_offset = 0.0
	traveled_distance_till_current_step += current_step["progress"]

	if current_step["type"] == StepType.NODE:
		for trigger in _location_triggers["node"]:
			if current_step["node"].id == trigger["node_id"]:
				if current_step["to_endpoint"] == trigger["endpoint_id"] or trigger["endpoint_id"] == -1:
					var callable = trigger["callback"] as Callable
					callable.call_deferred(vehicle, current_step["node"].id, current_step["to_endpoint"])
					_location_triggers["node"].erase(trigger)

	if trip_step_index + 1 >= trip_path.size():
		if current_step.has("building_to_enter"):
			_enter_building()
		else:
			if current_step.has("target_building") and current_step["target_building"].has_method("notify_vehicle_entered"):
				current_step["target_building"].notify_vehicle_entered(vehicle)

			var event_data = {
				"trip_points": trip_points.duplicate(),
				"trip_buildings": trip_buildings.duplicate(),
				"trip_path": trip_path.duplicate(),
				"last_step": current_step,
			}

			_reset_state()

			emit_signal("trip_ended", true, event_data)

	elif current_step["type"] == StepType.NODE:
		trip_step_index += 1
		_assign_to_step(trip_path[trip_step_index])
	elif current_step["type"] == StepType.BUILDING:
		_leave_building()
	else:
		_pass_node()


func clean_up() -> void:
	_location_triggers.clear()

	if current_step and current_step["type"] == StepType.SEGMENT:
		var step = trip_path[trip_step_index]
		var endpoint_id = step.ViaEndpointId
		var endpoint = network_manager.get_lane_endpoint(endpoint_id)

		var lane = network_manager.get_segment(endpoint.SegmentId).get_lane(endpoint.LaneId) as NetLane
		lane.remove_vehicle(vehicle)
	elif current_step["type"] == StepType.NODE:
		var node = current_step["node"]
		node.intersection_manager.mark_vehicle_left(vehicle.id, current_step["from_endpoint"], current_step["to_endpoint"])
	elif current_step["type"] == StepType.BUILDING:
		if current_step["is_leaving"]:
			current_step["target_building"].notify_vehicle_left()
		else:
			current_step["target_building"].notify_vehicle_entered(vehicle)


func abandon_trip() -> void:
	clean_up()
	emit_signal(
		"trip_ended",
		false,
		{
			"trip_points": trip_points,
			"trip_buildings": trip_buildings,
			"trip_path": trip_path,
			"last_step": current_step,
		},
	)


func reroute(force: bool = false, to_endpoint_id: int = -1) -> void:
	if not _is_rerouting_enabled:
		return

	if current_step["type"] != StepType.SEGMENT and current_step["type"] != StepType.NODE:
		return

	if not force and reroute_cooldown > 0.0:
		return

	reroute_cooldown = REROUTE_COOLDOWN

	step_ready = false

	var new_trip = [current_step["prev_node"], trip_points[1] if to_endpoint_id == -1 else to_endpoint_id]
	var finish_endpoint = segment_helper.get_other_endpoint_in_lane(last_step_forced_endpoint) if last_step_forced_endpoint != -1 else null

	pathing_manager.find_path(
		new_trip[0],
		new_trip[1],
		Callable(self, "_on_pathfinder_result"),
		vehicle.config.category,
		current_step["from_endpoint"],
		finish_endpoint.Id if finish_endpoint else -1,
	)


func block_reroutes() -> void:
	_is_rerouting_enabled = false


func unblock_reroutes() -> void:
	_is_rerouting_enabled = true


func get_total_progress() -> float:
	if total_trip_distance == 0:
		return 0.0

	return (traveled_distance_till_current_step + current_step["progress"]) / total_trip_distance


func get_trip_curves() -> Array:
	if trip_curves_cache.size() > 0:
		return trip_curves_cache

	var starting_building = trip_buildings[0] if trip_buildings.size() > 0 else null
	var ending_building = trip_buildings[1] if trip_buildings.size() > 1 else null

	trip_curves_cache = network_manager.get_curves_of_path(trip_path, starting_building, ending_building)

	return trip_curves_cache


func set_custom_step(path: Path2D, max_speed: float = 0.0) -> void:
	if current_step["type"] != StepType.NONE:
		push_error("Navigator: Cannot set custom step while another trip is in progress.")
		return

	current_step = {
		"type": StepType.CUSTOM,
		"path": path.curve,
		"length": path.curve.get_baked_length(),
		"progress": 0.0,
	}

	if max_speed > 0.0:
		current_step["max_speed"] = max_speed

	step_ready = true
	vehicle.assign_to_path(path, 0.0)
	emit_signal("trip_started")


func set_node_location_trigger(node_id: int, endpoint_id: int, callback: Callable) -> void:
	_location_triggers["node"].append(
		{
			"node_id": node_id,
			"endpoint_id": endpoint_id,
			"callback": callback,
		},
	)


func set_segment_location_trigger(segment_id: int, lane_id: int, distance: float, callback: Callable) -> void:
	_location_triggers["segment"].append(
		{
			"segment_id": segment_id,
			"lane_id": lane_id,
			"distance": distance,
			"callback": callback,
		},
	)


func _tick_segment_triggers() -> void:
	if _location_triggers["segment"].size() == 0:
		return

	if current_step["type"] == StepType.SEGMENT:
		var segment_id = current_step["segment_id"]
		var lane_id = current_step["lane_id"]
		var progress = current_step["progress"]

		for trigger in _location_triggers["segment"]:
			if trigger["segment_id"] == segment_id and (trigger["lane_id"] == lane_id or trigger["lane_id"] == -1):
				if progress >= trigger["distance"]:
					var callable = trigger["callback"] as Callable
					callable.call_deferred(vehicle, segment_id, lane_id)
					_location_triggers["segment"].erase(trigger)


func _on_pathfinder_result(path: Variant) -> void:
	if trip_path.size() > 0:
		_handle_reroute(path)
		return

	if path.State == 1:
		if path.Path.size() == 0:
			push_error("Navigator: Pathfinder returned successful but empty path.")
			emit_signal(
				"trip_ended",
				false,
				{
					"trip_points": trip_points,
					"trip_buildings": trip_buildings,
					"trip_path": trip_path,
					"last_step": current_step,
				},
			)
			_reset_state()
			return

		trip_path = path.Path
		trip_points = [path.StartNodeId, path.EndNodeId]

		first_step_forced_endpoint = segment_helper.get_other_endpoint_in_lane(path.ForcedStartEndpointId).Id if path.ForcedStartEndpointId != -1 else -1
		last_step_forced_endpoint = segment_helper.get_other_endpoint_in_lane(path.ForcedEndEndpointId).Id if path.ForcedEndEndpointId != -1 else -1

		call_deferred("_start_trip")
		call_deferred("_calc_trip_distance")
	else:
		emit_signal(
			"trip_ended",
			false,
			{
				"trip_points": trip_points,
				"trip_buildings": trip_buildings,
				"trip_path": trip_path,
				"last_step": current_step,
			},
		)


func _handle_reroute(path: Variant) -> void:
	if path.State != 1:
		step_ready = true
		return # Failed to find a new path, continue current trip

	var is_at_node = current_step["type"] == StepType.NODE

	var existing_path = trip_path.slice(0, trip_step_index + 1)
	var remaining_existing_path = trip_path.slice(trip_step_index + 1, trip_path.size())

	var new_path_start_index = 0 if is_at_node else 1
	var new_path = path.Path.slice(new_path_start_index, path.Path.size())

	var updated_path = existing_path + new_path

	var is_different = false

	if new_path.size() != remaining_existing_path.size():
		is_different = true
	else:
		for step_idx in range(new_path.size()):
			var new_step = new_path[step_idx]
			var existing_step = remaining_existing_path[step_idx]

			if new_step.ToNodeId != existing_step.ToNodeId or new_step.ViaEndpointId != existing_step.ViaEndpointId:
				is_different = true
				break

	if not is_different:
		step_ready = true
		return # New path is the same as the remaining existing path, continue current trip

	trip_curves_cache = []
	trip_path = updated_path
	last_step_forced_endpoint = segment_helper.get_other_endpoint_in_lane(path.ForcedEndEndpointId).Id if path.ForcedEndEndpointId != -1 else -1

	if not is_at_node:
		_assign_to_step(trip_path[trip_step_index], true)
	_calc_trip_distance()
	emit_signal("trip_rerouted")


func _calc_trip_distance() -> void:
	var curves = get_trip_curves()
	total_trip_distance = 0

	for curve in curves:
		total_trip_distance += curve.get_baked_length()


func _start_trip() -> void:
	traveled_distance_till_current_step = 0.0
	var start_step = trip_path[0]

	if trip_buildings.size() > 0 and trip_buildings[0] != null:
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
	if not leave_progress:
		lane.assign_vehicle(vehicle)
		vehicle.assign_to_path(lane.trail, 0.0)

	current_step = _create_segment_step(lane, 0.0)

	if trip_step_index == trip_path.size() - 1 and trip_buildings.size() > 1:
		var building_in_connection = trip_buildings[1].get_in_connection(last_step_forced_endpoint)
		current_step["building_to_enter"] = {
			"building": trip_buildings[1],
			"connection": building_in_connection,
			"trigger_distance": line_helper.get_distance_from_point(lane.trail.curve, building_in_connection["lane_point"]),
		}

	step_ready = true


func _pass_node(leave_progress: bool = false) -> void:
	var step = trip_path[trip_step_index]
	var endpoint_id = step.ViaEndpointId
	var endpoint = network_manager.get_lane_endpoint(endpoint_id)

	var node = current_step["next_node"].node
	var new_path = node.get_connection_path(current_step["next_node"].from, current_step["next_node"].to)

	if not leave_progress:
		var lane = network_manager.get_segment(endpoint.SegmentId).get_lane(endpoint.LaneId) as NetLane
		lane.remove_vehicle(vehicle)
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

	if not leave_progress:
		vehicle.assign_to_path(new_path, 0.0)

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
		"next_node": null,
		"is_entering": connection["relation"] == "in",
		"is_leaving": connection["relation"] == "out",
	}


func _assign_to_building_step(step: Dictionary) -> void:
	vehicle.assign_to_path(step["connection"]["path"], 0.0)

	current_step = step
	step_ready = true


func _leave_building() -> void:
	var building_step = current_step
	var lane = building_step["target_lane"]

	if building_step["target_building"].has_method("notify_vehicle_left"):
		building_step["target_building"].notify_vehicle_left()

	var offset = line_helper.get_distance_from_point(lane.trail.curve, building_step["lane_point"])

	vehicle.assign_to_path(lane.trail, offset)
	current_step = _create_segment_step(lane, offset)

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


func _create_segment_step(lane: NetLane, progress_offset: float) -> Dictionary:
	var finish_endpoint = lane.get_endpoint_by_type(false)

	var prev_node_id = lane.segment.get_other_node_id(finish_endpoint.NodeId)

	var step = {
		"type": StepType.SEGMENT,
		"segment_id": lane.segment.id,
		"lane_id": lane.id,
		"path": lane.trail.curve,
		"length": lane.trail.curve.get_baked_length(),
		"progress": 0.0,
		"max_speed": lane.get_max_allowed_speed(),
		"prev_node": prev_node_id,
		"from_endpoint": lane.from_endpoint,
		"to_endpoint": finish_endpoint.Id,
	}
	_progress_offset = progress_offset

	var node = network_manager.get_node(finish_endpoint.NodeId)

	if node:
		step["next_node"] = {
			"node": node,
			"is_intersection": node.connected_segments.size() > 2,
			"from": finish_endpoint.Id,
			"to": trip_path[trip_step_index + 1].ViaEndpointId if trip_step_index + 1 < trip_path.size() else null,
			"approaching_intersection": node.connected_segments.size() > 2,
		}

	return step


func _reset_state() -> void:
	trip_points = []
	trip_buildings = []
	trip_path = []
	trip_step_index = 0

	first_step_forced_endpoint = -1
	last_step_forced_endpoint = -1

	current_step = {
		"type": StepType.NONE,
	}
	step_ready = false

	traveled_distance_till_current_step = 0.0
	total_trip_distance = 0.0

	reroute_cooldown = 0.0

	trip_curves_cache = []
	_location_triggers = { "segment": [], "node": [] }
