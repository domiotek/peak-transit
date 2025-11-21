class_name StopDefinition

var name: String = ""
var position: StopPosDefinition = StopPosDefinition.new()
var demand_preset: int = 0
var has_shelter: bool = false
var can_wait: bool = true


static func deserialize(data: Dictionary) -> StopDefinition:
	var stop_def = StopDefinition.new()

	stop_def.name = data["name"] as String
	stop_def.position = StopPosDefinition.deserialize(data["pos"] as Dictionary)
	stop_def.demand_preset = data["demandPreset"] as int
	stop_def.has_shelter = data["shelter"] as bool
	stop_def.can_wait = data["canWait"] as bool

	return stop_def
