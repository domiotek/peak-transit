class_name SegmentPosDefinition

var segment: Array = []
var offset: float = 0.0


func serialize() -> Dictionary:
	return {
		"segment": segment,
		"offset": offset,
	}


static func deserialize(data: Dictionary) -> SegmentPosDefinition:
	var stop_pos_def = SegmentPosDefinition.new()

	stop_pos_def.segment = data["segment"] as Array[int]
	stop_pos_def.offset = data["offset"] as float

	return stop_pos_def
