class_name NetLaneInfo

enum LaneDirection {
	Auto,
    Forward,
    All,
    ForwardRight,
    Right,
    Backward,
    Left,
    ForwardLeft,
}

var max_speed: float
var direction: LaneDirection

func serialize() -> Dictionary:
	var data = {}
	data["maxSpeed"] = max_speed
	data["direction"] = direction
	return data

static func deserialize(data: Dictionary) -> NetLaneInfo:
	var net_lane_info = NetLaneInfo.new()
	
	net_lane_info.max_speed = data.get("maxSpeed")
	net_lane_info.direction = data.get("direction") as LaneDirection

	return net_lane_info
