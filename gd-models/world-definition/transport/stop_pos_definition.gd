class_name StopPosDefinition

var segment: Array[int] = []
var offset: float = 0.0


static func deserialize(data: Dictionary) -> StopPosDefinition:
	var stop_pos_def = StopPosDefinition.new()

	stop_pos_def.segment = data["segment"] as Array[int]
	stop_pos_def.offset = data["offset"] as float

	return stop_pos_def
