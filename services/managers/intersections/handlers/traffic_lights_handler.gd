extends RefCounted

class_name TrafficLightsIntersectionHandler

var CLASS_NAME: String = "TrafficLightsIntersectionHandler"

var MIN_PHASE_DURATION_SCALER: float = 0.1
var LONG_PHASE_DURATION: float = 60.0
var SHORT_PHASE_DURATION: float = 30.0
var LOW_FLOW_THRESHOLD: int = 10
var FLOW_SCAN_DISTANCE: float = 50.0

var segment_helper: SegmentHelper
var connections_helper: ConnectionsHelper
var intersection_helper: IntersectionHelper

var stoppers: Array = []

var phases: Array = []
var current_phase_index: int = 0
var phase_timer: float = 0.0

var node: RoadNode

func setup(_node: RoadNode, _stoppers: Array) -> void:
	node = _node
	stoppers = _stoppers

	segment_helper = GDInjector.inject("SegmentHelper") as SegmentHelper
	connections_helper = GDInjector.inject("ConnectionsHelper") as ConnectionsHelper
	intersection_helper = GDInjector.inject("IntersectionHelper") as IntersectionHelper

	var flows = _find_flows()
	_create_phases(flows)

func process_tick(_delta: float) -> void:
	if phases.size() == 0:
		return

	var active_phase = phases[current_phase_index]
	phase_timer += _delta

	var flow_ratio = 100.0

	var min_phase_duration = active_phase.duration * MIN_PHASE_DURATION_SCALER

	if phase_timer >= min_phase_duration:
		flow_ratio = _measure_current_flow_ratio()

	if phase_timer >= active_phase.duration || flow_ratio < LOW_FLOW_THRESHOLD:
		current_phase_index = (current_phase_index + 1) % phases.size()
		phase_timer = 0.0
		_set_stoppers_active(active_phase.stoppers, true)
		active_phase = phases[current_phase_index]


	for stopper in active_phase.stoppers:
		var stopper_activated = process_stopper(stopper, active_phase)
		stopper.set_active(stopper_activated)
		

func process_stopper(stopper: LaneStopper, active_phase: Dictionary) -> bool:
	var lane = stopper.get_lane()
	var approaching_vehicle = lane.get_first_vehicle()

	if not approaching_vehicle:
		return false

	var next_endpoint = approaching_vehicle.navigator.get_current_step()["next_node"]["to"]
	var direction = node.get_connection_direction(stopper.endpoint.Id, next_endpoint)

	if direction not in active_phase.directions:
		return true

	if intersection_helper.block_if_not_enough_space_in_lane_ahead(node, stopper, next_endpoint):
		return true

	return false


func _find_flows() -> Array:
	var flows = []

	if node.is_priority_based:
		flows = _find_flows_by_priority()
	else:
		flows = _find_flows_by_geometry()

	return flows

func _find_flows_by_priority() -> Array:
	var priority_segments: Array = []
	var other_segments: Array = []

	for segment in node.connected_segments:
		if node.segment_priorities[segment.id] == Enums.IntersectionPriority.PRIORITY:
			priority_segments.append(segment)
		else:
			other_segments.append(segment)

	return [priority_segments, other_segments]

func _find_flows_by_geometry() -> Array:
	var segment = node.connected_segments[0]
	var directions = node.segment_directions.get(segment.id, {})
	var forward_segment = directions.get("forward", null)
	var other_segments = node.connected_segments.filter(func (s): return s != segment and s != forward_segment)

	var flow0 = [segment]

	if forward_segment:
		flow0.append(forward_segment)

	return [flow0, other_segments]

func _create_phases(flows: Array) -> Array:
	for flow in flows:
		var forward_stoppers = _get_stoppers_with_direction(Enums.Direction.FORWARD, flow)
		var left_combined_stoppers = _get_stoppers_with_direction(Enums.Direction.LEFT, flow)
		var left_direct_stoppers = _get_stoppers_with_direction(Enums.Direction.LEFT, flow, false)
		var right_stoppers = _get_stoppers_with_direction(Enums.Direction.RIGHT, flow)

		if left_direct_stoppers.size() > 0:
			if forward_stoppers.size() > 0:
				phases.append(_create_phase(_merge_stoppers(forward_stoppers, right_stoppers), [Enums.Direction.FORWARD, Enums.Direction.RIGHT], LONG_PHASE_DURATION))
			if left_combined_stoppers.size() > 0:
				phases.append(_create_phase(left_combined_stoppers, [Enums.Direction.LEFT], SHORT_PHASE_DURATION))

		else:
			phases.append(_create_phase(_merge_stoppers(forward_stoppers, left_combined_stoppers, right_stoppers), [Enums.Direction.FORWARD, Enums.Direction.LEFT, Enums.Direction.RIGHT], 40.0))

	return phases


func _get_stoppers_with_direction(target_direction: Enums.Direction, segments: Array, allow_combined: bool = true) -> Array:
	var result = []

	for stopper in stoppers:
		var lane = stopper.get_lane()

		if lane.segment in segments:
			var lane_direction = lane.direction

			if lane_direction == target_direction:
				result.append(stopper)
			elif allow_combined and connections_helper.is_in_combined_direction(lane_direction, target_direction):
				result.append(stopper)
			

	return result

func _merge_stoppers(stoppers_a: Array, stoppers_b: Array, stoppers_c: Array=[]) -> Array:
	var merged: Array = stoppers_a.duplicate()
	for stopper in stoppers_b:
		if stopper not in merged:
			merged.append(stopper)

	for stopper in stoppers_c:
		if stopper not in merged:
			merged.append(stopper)
	return merged

func _create_phase(_stoppers: Array, _directions: Array, duration: float) -> Dictionary:
	var phase = {
		"stoppers": _stoppers,
		"directions": _directions,
		"duration": duration
	}
	return phase

func _set_stoppers_active(_stoppers: Array, _active: bool) -> void:
	for stopper in _stoppers:
		stopper.set_active(_active)

func _measure_current_flow_ratio() -> float:
	var total_waiting = 0
	var waiting_on_open_lanes = 0

	for stopper in stoppers:
		var lane = stopper.get_lane()
		var vehicle_count = lane.count_vehicles_within_distance(node.id, FLOW_SCAN_DISTANCE)
		total_waiting += vehicle_count

		if not stopper.is_active():
			waiting_on_open_lanes += vehicle_count


	var vehicles_crossing = node.get_vehicles_crossing_count()

	return (float(vehicles_crossing) + float(waiting_on_open_lanes)) / float(total_waiting) * 100 if total_waiting > 0 else 100.0
