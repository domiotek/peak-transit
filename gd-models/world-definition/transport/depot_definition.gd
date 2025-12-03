class_name DepotDefinition

var name: String = ""
var position: SegmentPosDefinition = SegmentPosDefinition.new()


static func deserialize(data: Dictionary) -> DepotDefinition:
	var depot_def = DepotDefinition.new()

	depot_def.name = data["name"] as String
	depot_def.position = SegmentPosDefinition.deserialize(data["pos"] as Dictionary)

	return depot_def


func serialize() -> Dictionary:
	var data: Dictionary = { }
	data["name"] = name
	data["pos"] = position.serialize()
	return data
