
class_name SlimWorldDefinition

var name: String
var file_path: String
var description: String
var created_at: String
var built_in: bool = false

static func deserialize(data: Dictionary) -> SlimWorldDefinition:
	var slim_world_def = SlimWorldDefinition.new()
	slim_world_def.name = data.get("name")
	slim_world_def.file_path = data.get("filePath")
	slim_world_def.description = data.get("description")
	slim_world_def.created_at = data.get("createdAt")
	slim_world_def.built_in = data.get("builtIn")
	return slim_world_def
