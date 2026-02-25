class_name BuildingToEnterInfo

var building: BaseBuilding
var connection: BuildingConnectionInfo
var trigger_distance: float


static func create(_building: BaseBuilding, _connection: BuildingConnectionInfo, _trigger_distance: float) -> BuildingToEnterInfo:
	var info = BuildingToEnterInfo.new()
	info.building = _building
	info.connection = _connection
	info.trigger_distance = _trigger_distance

	return info
