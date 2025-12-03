class_name DepotDefinition

var name: String = ""
var position: SegmentPosDefinition = SegmentPosDefinition.new()
var regular_bus_capacity: int
var articulated_bus_capacity: int


static func deserialize(data: Dictionary) -> DepotDefinition:
	var depot_def = DepotDefinition.new()

	depot_def.name = data["name"] as String
	depot_def.position = SegmentPosDefinition.deserialize(data["pos"] as Dictionary)
	depot_def.regular_bus_capacity = data.get("busCount")
	depot_def.articulated_bus_capacity = data.get("articulatedBusCount")

	return depot_def


func serialize() -> Dictionary:
	var data: Dictionary = { }
	data["name"] = name
	data["pos"] = position.serialize()
	data["busCount"] = regular_bus_capacity
	data["articulatedBusCount"] = articulated_bus_capacity
	return data
