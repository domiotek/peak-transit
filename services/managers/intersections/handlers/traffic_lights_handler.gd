extends RefCounted

class_name TrafficLightsIntersectionHandler

var full_traffic_light = preload("res://game-objects/network/net-node/traffic-light/traffic-light.tscn")
var arrow_traffic_light = preload("res://game-objects/network/net-node/arrow-traffic-light/arrow_traffic_light.tscn")
var traffic_light_pole = preload("res://game-objects/network/net-node/traffic-light-pole/traffic-light-pole.tscn")

enum TrafficLightConfiguration {
	SINGLE,
	SINGLE_WITH_LEFT,
	SINGLE_WITH_RIGHT
}

enum TrafficLightPosition {
	POLE,
	ROAD_SIDE
}

var CLASS_NAME: String = "TrafficLightsIntersection"

var MIN_PHASE_DURATION_SCALER: float = 0.1
var LONG_PHASE_DURATION: float = 60.0
var SHORT_PHASE_DURATION: float = 30.0
var LOW_FLOW_THRESHOLD: int = 10
var FLOW_SCAN_DISTANCE: float = 50.0

var segment_helper: SegmentHelper
var connections_helper: ConnectionsHelper
var intersection_helper: IntersectionHelper
var line_helper: LineHelper

var stoppers: Array = []

var phases: Array = []
var current_phase_index: int = 0
var phase_timer: float = 0.0
var is_first_cycle = true

var node: RoadNode

func setup(_node: RoadNode, _stoppers: Array) -> void:
	node = _node
	stoppers = _stoppers

	segment_helper = GDInjector.inject("SegmentHelper") as SegmentHelper
	connections_helper = GDInjector.inject("ConnectionsHelper") as ConnectionsHelper
	intersection_helper = GDInjector.inject("IntersectionHelper") as IntersectionHelper
	line_helper = GDInjector.inject("LineHelper") as LineHelper

	var flows = _find_flows()
	_create_phases(flows)
	_create_traffic_light_visuals()

func process_tick(_delta: float) -> void:
	if phases.size() == 0:
		return

	var active_phase = phases[current_phase_index]
	phase_timer += _delta

	var flow_ratio = 100.0

	var min_phase_duration = active_phase.duration * MIN_PHASE_DURATION_SCALER

	if phase_timer >= min_phase_duration:
		flow_ratio = _measure_current_flow_ratio()

	var first_cycle_after_change = false

	if is_first_cycle || phase_timer >= active_phase.duration || flow_ratio < LOW_FLOW_THRESHOLD:
		is_first_cycle = false
		current_phase_index = (current_phase_index + 1) % phases.size()
		phase_timer = 0.0
		_set_stoppers_active(active_phase.stoppers, true, active_phase["directions"])
		_set_stoppers_active(active_phase.exception_stoppers, true, [Enums.Direction.RIGHT])
		active_phase = phases[current_phase_index]
		first_cycle_after_change = true

	var handle_stoppers = func(stoppers_set: Array, directions: Array) -> void:
		for stopper in stoppers_set:
			var stopper_activated = process_stopper(stopper, directions)

			if first_cycle_after_change:
				stopper.set_active_with_light(stopper_activated, directions)
			else:
				stopper.set_active(stopper_activated)

	handle_stoppers.call(active_phase.stoppers, active_phase["directions"])
	handle_stoppers.call(active_phase.exception_stoppers, [Enums.Direction.RIGHT])

func process_stopper(stopper: LaneStopper, directions: Array) -> bool:
	var lane = stopper.get_lane()
	var approaching_vehicle = lane.get_first_vehicle()

	if not approaching_vehicle:
		return false

	var next_endpoint = approaching_vehicle.navigator.get_current_step()["next_node"]["to"]
	var direction = node.get_connection_direction(stopper.endpoint.Id, next_endpoint)

	if direction not in directions:
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
		var right_most_stoppers_from_other = _get_right_most_stoppers_of_other_flow(flows.filter(func(f): return f != flow)[0])

		if left_direct_stoppers.size() > 0:
			if forward_stoppers.size() > 0:
				phases.append(
					_create_phase(
						_merge_stoppers(forward_stoppers, right_stoppers),
						right_most_stoppers_from_other,
						[Enums.Direction.FORWARD, Enums.Direction.RIGHT], LONG_PHASE_DURATION
					)
				)

				phases.append(
					_create_phase(
						left_combined_stoppers,
						right_most_stoppers_from_other,
						[Enums.Direction.LEFT], 
						SHORT_PHASE_DURATION
					)
				)
			else:
				var left_right_stoppers = _merge_stoppers(left_combined_stoppers, right_stoppers)
				phases.append(
					_create_phase(
						left_right_stoppers,
						right_most_stoppers_from_other,
						[Enums.Direction.LEFT, Enums.Direction.RIGHT], 
						LONG_PHASE_DURATION
					)
				)

		else:
			phases.append(
				_create_phase(
					_merge_stoppers(forward_stoppers, left_combined_stoppers, right_stoppers),
					right_most_stoppers_from_other,
					[Enums.Direction.FORWARD, Enums.Direction.LEFT, Enums.Direction.RIGHT],
					LONG_PHASE_DURATION
				)
			)

	return phases

func _get_right_most_stoppers_of_other_flow(other_flow: Array) -> Array:
	var result = []

	var right_stoppers = _get_stoppers_with_direction(Enums.Direction.RIGHT, other_flow)

	for stopper in right_stoppers:
		var lane = stopper.get_lane()
		var lanes_count = lane.segment.get_relation_of_lane(lane.id).ConnectionInfo.Lanes.size()

		if stopper.endpoint.LaneNumber == lanes_count - 1:
			result.append(stopper)

	return result


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

func _create_phase(_stoppers: Array, _exception_stoppers: Array, _directions: Array, duration: float) -> Dictionary:
	var phase = {
		"stoppers": _stoppers,
		"exception_stoppers": _exception_stoppers,
		"directions": _directions,
		"duration": duration
	}
	return phase

func _set_stoppers_active(_stoppers: Array, _active: bool, _directions: Array) -> void:
	for stopper in _stoppers:
		stopper.set_active_with_light(_active, _directions)

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

func _create_traffic_light_visuals() -> void:

	for segment in node.connected_segments:
		var segment_stoppers = stoppers.filter(func(s): return s.get_lane().segment == segment)

		var right_most_stopper = null
		var left_most_stopper = null

		for stopper in segment_stoppers:
			var lane = stopper.get_lane()
			var lanes_count = segment.get_relation_of_lane(lane.id).ConnectionInfo.Lanes.size();

			if stopper.endpoint.LaneNumber == 0:
				left_most_stopper = stopper

			if stopper.endpoint.LaneNumber == lanes_count - 1:
				right_most_stopper = stopper

			var position = TrafficLightPosition.ROAD_SIDE if segment_stoppers.size() == 1 else TrafficLightPosition.POLE
			var configuration = TrafficLightConfiguration.SINGLE

			if lane.direction == Enums.Direction.LEFT_FORWARD:
				configuration = TrafficLightConfiguration.SINGLE_WITH_LEFT
			elif connections_helper.is_in_combined_direction(lane.direction, Enums.Direction.RIGHT) and lane.direction != Enums.Direction.RIGHT and right_most_stopper == stopper:
				configuration = TrafficLightConfiguration.SINGLE_WITH_RIGHT

			_create_traffic_light_assembly(stopper, configuration, position)

		if segment_stoppers.size() > 1:
			_create_pole(segment.curve_shape, right_most_stopper, left_most_stopper)


func _create_pole(road_curve: Curve2D, right_most_stopper: LaneStopper, left_most_stopper: LaneStopper) -> void:
	var light_pole_instance = traffic_light_pole.instantiate() as TrafficLightPole

	light_pole_instance.position = node.to_local(right_most_stopper.endpoint.Position)
	light_pole_instance.rotation_degrees = line_helper.rotate_along_curve(road_curve, right_most_stopper.endpoint.Position)

	var right_offset = Vector2(-10, NetworkConstants.LANE_WIDTH * 0.75).rotated(deg_to_rad(right_most_stopper.rotation_degrees))
	light_pole_instance.position += right_offset

	light_pole_instance.setup(left_most_stopper.endpoint.Position + Vector2(-10, 0).rotated(deg_to_rad(left_most_stopper.rotation_degrees)))

	node.top_layer.add_child(light_pole_instance)

func _create_traffic_light_assembly(ref_stopper: LaneStopper, configuration: TrafficLightConfiguration, position_mode: TrafficLightPosition ) -> void:

	var assembly = Node2D.new()
	assembly.position = node.to_local(ref_stopper.endpoint.Position)
	assembly.rotation_degrees = ref_stopper.rotation_degrees + 90.0
	assembly.z_index = 1
	node.top_layer.add_child(assembly)

	var pos_offset = Vector2(0, 0)
	if position_mode == TrafficLightPosition.ROAD_SIDE:
		pos_offset = Vector2(NetworkConstants.LANE_WIDTH * 0.75, 0).rotated(deg_to_rad(assembly.rotation_degrees))

	var offset_vector = Vector2(0, 10).rotated(deg_to_rad(assembly.rotation_degrees))
	assembly.position += offset_vector + pos_offset

	var light_instance = full_traffic_light.instantiate() as TrafficLight
	assembly.add_child(light_instance)
	ref_stopper.traffic_lights[Enums.Direction.ALL_DIRECTIONS] = light_instance


	if configuration == TrafficLightConfiguration.SINGLE:
		return

	if configuration == TrafficLightConfiguration.SINGLE_WITH_LEFT:
		var left_light = full_traffic_light.instantiate() as TrafficLight
		left_light.set_mask("res://assets/ui_icons/traffic_light_arrow.png")
		assembly.add_child(left_light)
		left_light.position = Vector2(-10.5, 0)
		ref_stopper.traffic_lights[Enums.Direction.LEFT] = left_light

	elif configuration == TrafficLightConfiguration.SINGLE_WITH_RIGHT:
		var arrow_instance = arrow_traffic_light.instantiate() as ArrowTrafficLight
		assembly.add_child(arrow_instance)
		arrow_instance.position = Vector2(8.5, 7)
		ref_stopper.traffic_lights[Enums.Direction.RIGHT] = arrow_instance
