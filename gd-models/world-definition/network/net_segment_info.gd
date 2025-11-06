class_name NetSegmentInfo

enum CurveDirection {
	Clockwise = 1,
	CounterClockwise = -1
}

var nodes: Array[int]
var curve_strength: float
var curve_direction: CurveDirection = CurveDirection.Clockwise
var relations: Array[NetRelationInfo] = []
var max_speed: float

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
