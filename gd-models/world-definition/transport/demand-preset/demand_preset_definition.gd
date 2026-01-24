class_name DemandPresetDefinition

var boredom_tolerance_multiplier: float = 1.0
var spawn_chance_multiplier: float = 1.0
var frames: Array = []


static func deserialize(data: Dictionary) -> DemandPresetDefinition:
	var demand_preset_def = DemandPresetDefinition.new()

	demand_preset_def.boredom_tolerance_multiplier = data.get("tolerance", 1.0)
	demand_preset_def.spawn_chance_multiplier = data.get("chance", 1.0)

	for frame_data in data["frames"] as Array:
		var frame_def = PresetFrameDefinition.deserialize(frame_data as Dictionary)
		demand_preset_def.frames.append(frame_def)

	return demand_preset_def


func serialize() -> Dictionary:
	var data: Dictionary = { }
	data["tolerance"] = boredom_tolerance_multiplier
	data["chance"] = spawn_chance_multiplier

	var frames_data: Array = []
	for frame_def in frames:
		frames_data.append(frame_def.serialize())

	data["frames"] = frames_data

	return data


static func get_default_definition() -> DemandPresetDefinition:
	var default_def = DemandPresetDefinition.new()
	default_def.boredom_tolerance_multiplier = 1.0
	default_def.spawn_chance_multiplier = 1.0
	default_def.frames.append(PresetFrameDefinition.get_default_definition())
	return default_def
