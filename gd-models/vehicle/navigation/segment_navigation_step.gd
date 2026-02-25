extends NavigationStep

class_name SegmentNavigationStep

var segment_id: int
var lane_id: int
var lane: NetLane
var prev_node: int
var from_endpoint: int
var to_endpoint: int
var next_node: NextNodeInfo
var building_to_enter: BuildingToEnterInfo


func set_next_node_info(node: RoadNode, next_target_endpoint_id: int, next_direction: Enums.Direction) -> void:
	var next_node_info = NextNodeInfo.new()
	next_node_info.node = node
	next_node_info.is_intersection = node.connected_segments.size() > 2
	next_node_info.from = to_endpoint
	next_node_info.to = next_target_endpoint_id
	next_node_info.direction = next_direction

	next_node = next_node_info


func set_building_to_enter(building: BaseBuilding, connection: BuildingConnectionInfo) -> void:
	var line_helper: LineHelper = GDInjector.inject("LineHelper") as LineHelper

	building_to_enter = BuildingToEnterInfo.create(
		building,
		connection,
		line_helper.get_distance_from_point(lane.trail.curve, connection.lane_point),
	)


static func create(_lane: NetLane, prev_node_id: int, target_endpoint: int) -> SegmentNavigationStep:
	var step = SegmentNavigationStep.new()
	step.type = Navigator.StepType.SEGMENT
	step.segment_id = _lane.segment.id
	step.lane_id = _lane.id
	step.lane = _lane
	step.path = _lane.trail.curve
	step.length = step.path.get_baked_length()
	step.progress = 0.0
	step.max_speed = _lane.get_max_allowed_speed()
	step.prev_node = prev_node_id
	step.from_endpoint = _lane.from_endpoint
	step.to_endpoint = target_endpoint

	return step
