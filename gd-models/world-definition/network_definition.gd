class_name NetworkDefinition

var nodes: Array[NetNodeInfo] = []
var segments: Array[NetSegmentInfo] = []


func serialize() -> Dictionary:
	var _nodes: Array[Dictionary] = []
	var _segments: Array[Dictionary] = []

	for node in self.nodes:
		_nodes.append(node.serialize())

	for segment in self.segments:
		_segments.append(segment.serialize())

	return {
		"nodes": _nodes,
		"segments": _segments,
	}


static func deserialize(data: Dictionary) -> NetworkDefinition:
	var net_def = NetworkDefinition.new()

	for node_data in data.get("nodes", []):
		net_def.nodes.append(NetNodeInfo.deserialize(node_data))

	for segment_data in data.get("segments", []):
		net_def.segments.append(NetSegmentInfo.deserialize(segment_data))

	return net_def
