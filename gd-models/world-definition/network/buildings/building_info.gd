class_name BuildingInfo

enum BuildingType {
	RESIDENTIAL,
	COMMERCIAL,
	INDUSTRIAL,
	TERMINAL,
	DEPOT,
}

var type: BuildingType
var offset_position: float


static func deserialize(data: Dictionary) -> BuildingInfo:
	var building_info = BuildingInfo.new()

	building_info.type = data.get("type") as BuildingType
	building_info.offset_position = data.get("offset")

	return building_info
