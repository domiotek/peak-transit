class_name TerminalDefinition

var name: String = ""
var position: SegmentPosDefinition = SegmentPosDefinition.new()


static func deserialize(data: Dictionary) -> TerminalDefinition:
	var terminal_def = TerminalDefinition.new()

	terminal_def.name = data["name"] as String
	terminal_def.position = SegmentPosDefinition.deserialize(data["pos"] as Dictionary)

	return terminal_def
