class_name StopDefinition

var name: String = ""
var position: SegmentPosDefinition = SegmentPosDefinition.new()
var demand_preset: int = 0
var draw_stripes: bool = false
var can_wait: bool = true


func serialize() -> Dictionary:
	return {
		"name": name,
		"pos": position.serialize(),
		"demandPreset": demand_preset,
		"drawStripes": draw_stripes,
		"canWait": can_wait,
	}


static func deserialize(data: Dictionary) -> StopDefinition:
	var stop_def = StopDefinition.new()

	stop_def.name = data["name"] as String
	stop_def.position = SegmentPosDefinition.deserialize(data["pos"] as Dictionary)
	stop_def.demand_preset = data["demandPreset"] as int
	stop_def.draw_stripes = data["drawStripes"] as bool
	stop_def.can_wait = data["canWait"] as bool

	return stop_def
