class_name WorldDefinition

var name: String
var description: String
var created_at: String
var built_in: bool = false
var file_path: String

var map: MapDefinition
var network: NetworkDefinition
var transport: TransportDefinition


func serialize() -> Dictionary:
	return {
		"name": name,
		"description": description,
		"createdAt": created_at,
		"builtIn": built_in,
		"filePath": file_path,
		"map": map.serialize(),
		"network": network.serialize(),
		"transport": transport.serialize(),
	}


static func deserialize(data: Dictionary) -> WorldDefinition:
	var world_def = WorldDefinition.new()
	world_def.name = data.get("name")
	world_def.description = data.get("description")
	world_def.created_at = data.get("createdAt")
	world_def.built_in = data.get("builtIn")
	world_def.file_path = data.get("filePath")
	world_def.map = MapDefinition.deserialize(data.get("map"))
	world_def.network = NetworkDefinition.deserialize(data.get("network"))
	world_def.transport = TransportDefinition.deserialize(data.get("transport"))
	return world_def
