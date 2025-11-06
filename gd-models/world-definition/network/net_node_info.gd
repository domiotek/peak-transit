class_name NetNodeInfo

enum IntersectionType {
	Default,
	TrafficLights,
}

var id: int
var position: Vector2
var intersection_type: IntersectionType
var priority_segments: Array[int]
var stop_segments: Array[int]


static func deserialize(data: Dictionary) -> NetNodeInfo:
	var net_node_info = NetNodeInfo.new()
	net_node_info.id = data.get("id")
	net_node_info.position = data.get("pos")
	net_node_info.intersection_type =  data.get("intersection") as IntersectionType
	net_node_info.priority_segments = data.get("priSegments", [])
	net_node_info.stop_segments = data.get("stpSegments", [])
	return net_node_info
