class_name BuildingInfo

enum BuildingType {
	RESIDENTIAL,
	COMMERCIAL,
	INDUSTRIAL,
	TERMINAL,
	DEPOT,
}

const LANE_STORED_BUILDING_TYPES = [
	BuildingType.RESIDENTIAL,
	BuildingType.COMMERCIAL,
	BuildingType.INDUSTRIAL,
]

var type: BuildingType
var offset_position: float


func serialize() -> Dictionary:
	return {
		"type": type,
		"offset": offset_position,
	}


static func deserialize(data: Dictionary) -> BuildingInfo:
	var building_info = BuildingInfo.new()

	building_info.type = data.get("type") as BuildingType
	building_info.offset_position = data.get("offset")

	return building_info
