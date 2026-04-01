class_name TerminalDefinition

var id: int = -1
var name: String = ""
var position: SegmentPosDefinition = SegmentPosDefinition.new()
var demand_preset: int = 0


func serialize() -> Dictionary:
	return {
		"id": id,
		"name": name,
		"pos": position.serialize(),
		"demandPreset": demand_preset,
	}


static func deserialize(data: Dictionary) -> TerminalDefinition:
	var terminal_def = TerminalDefinition.new()

	terminal_def.id = data.get("id", -1) as int
	terminal_def.name = data["name"] as String
	terminal_def.position = SegmentPosDefinition.deserialize(data["pos"] as Dictionary)
	terminal_def.demand_preset = data["demandPreset"] as int

	return terminal_def
