extends NavigationStep

class_name BuildingNavigationStep

var target_building: BaseBuilding
var connection: BuildingConnectionInfo
var target_lane: NetLane
var lane_point: Vector2
var next_node: RoadNode
var is_entering: bool
var is_leaving: bool


static func create(building: BaseBuilding, _connection: BuildingConnectionInfo) -> BuildingNavigationStep:
	var step = BuildingNavigationStep.new()
	step.type = Navigator.StepType.BUILDING
	step.path = _connection.path.curve
	step.length = _connection.path.curve.get_baked_length()
	step.progress = 0.0
	step.target_building = building
	step.connection = _connection
	step.target_lane = _connection.lane
	step.lane_point = _connection.lane_point
	step.next_node = null
	step.is_entering = _connection.is_outgoing == false
	step.is_leaving = _connection.is_outgoing == true

	return step
