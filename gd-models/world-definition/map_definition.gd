class_name MapDefinition

var size: Vector2
var initial_pos: Vector2
var initial_zoom: float


func serialize() -> Dictionary:
	return {
		"size": size,
		"initialPosition": initial_pos,
		"initialZoom": initial_zoom,
	}


static func deserialize(data: Dictionary) -> MapDefinition:
	var map_def = MapDefinition.new()

	map_def.size = data.get("size")
	map_def.initial_pos = data.get("initialPosition")
	map_def.initial_zoom = data.get("initialZoom")

	return map_def
