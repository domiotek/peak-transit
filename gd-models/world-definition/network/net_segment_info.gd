class_name NetSegmentInfo

enum CurveDirection {
	CLOCKWISE = 1,
	COUNTER_CLOCKWISE = -1,
}

var nodes: Array[int] = []
var curve_strength: float
var curve_direction: CurveDirection = CurveDirection.CLOCKWISE
var relations: Array[NetRelationInfo] = []
var max_speed: float


func serialize() -> Dictionary:
	var _relations: Array[Dictionary] = []

	for relation in relations:
		_relations.append(relation.serialize())

	return {
		"nodes": nodes,
		"bendStrength": curve_strength,
		"bendDir": curve_direction,
		"relations": _relations,
		"maxSpeed": max_speed,
	}


static func deserialize(data: Dictionary) -> NetSegmentInfo:
	var segment_def = NetSegmentInfo.new()
	segment_def.nodes = data.get("nodes")
	segment_def.curve_strength = data.get("bendStrength")
	segment_def.curve_direction = data.get("bendDir") as CurveDirection
	segment_def.max_speed = data.get("maxSpeed")

	for relation_data in data.get("relations", []):
		var relation = NetRelationInfo.deserialize(relation_data)
		segment_def.relations.append(relation)

	return segment_def


static func get_default() -> NetSegmentInfo:
	var segment_def = NetSegmentInfo.new()
	segment_def.nodes = [] as Array[int]
	segment_def.curve_strength = 0.0
	segment_def.curve_direction = CurveDirection.CLOCKWISE
	segment_def.relations = [] as Array[NetRelationInfo]
	segment_def.max_speed = 0.0

	return segment_def
