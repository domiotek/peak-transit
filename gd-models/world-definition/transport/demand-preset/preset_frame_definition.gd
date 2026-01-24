class_name PresetFrameDefinition

var hour: TimeOfDay
var passengers_range: Array[int]
var spawn_chance_multiplier


static func deserialize(data: Dictionary) -> PresetFrameDefinition:
	var frame_def = PresetFrameDefinition.new()

	frame_def.hour = TimeOfDay.parse(data["hour"] as String)

	frame_def.passengers_range = data["range"] as Array[int]
	frame_def.spawn_chance_multiplier = data.get("chance", null)

	return frame_def


func serialize() -> Dictionary:
	var data: Dictionary = { }

	data["hour"] = hour.format()
	data["range"] = passengers_range
	data["chance"] = spawn_chance_multiplier

	return data


static func get_default_definition() -> PresetFrameDefinition:
	var default_def = PresetFrameDefinition.new()
	default_def.hour = TimeOfDay.new(0, 0)
	default_def.passengers_range.append(0)
	default_def.passengers_range.append(10)

	return default_def
