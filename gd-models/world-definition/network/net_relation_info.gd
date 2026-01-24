class_name NetRelationInfo

var lanes: Array[NetLaneInfo] = []
var buildings: Array[BuildingInfo] = []


func serialize() -> Dictionary:
	var _lanes: Array[Dictionary] = []
	var _buildings: Array[Dictionary] = []

	for lane in lanes:
		_lanes.append(lane.serialize())

	for building in buildings:
		_buildings.append(building.serialize())

	return {
		"lanes": _lanes,
		"buildings": _buildings,
	}


static func deserialize(data: Dictionary) -> NetRelationInfo:
	var net_relation_info = NetRelationInfo.new()

	for lane_data in data.get("lanes", []):
		var lane = NetLaneInfo.deserialize(lane_data)
		net_relation_info.lanes.append(lane)

	for building_data in data.get("buildings", []):
		var building = BuildingInfo.deserialize(building_data)
		net_relation_info.buildings.append(building)

	return net_relation_info
