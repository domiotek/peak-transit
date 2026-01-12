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
var allowed_vehicles: Dictionary


func serialize() -> Dictionary:
	var data = { }
	data["maxSpeed"] = max_speed
	data["direction"] = direction
	data["allowedVehicles"] = allowed_vehicles
	return data


static func deserialize(data: Dictionary) -> NetLaneInfo:
	var net_lane_info = NetLaneInfo.new()

	net_lane_info.max_speed = data.get("maxSpeed")
	net_lane_info.direction = data.get("direction") as LaneDirection
	net_lane_info.allowed_vehicles = data.get("allowedVehicles", { }) as Dictionary[Enums.BaseDirection, Array]

	return net_lane_info


static func get_default() -> NetLaneInfo:
	var net_lane_info = NetLaneInfo.new()
	net_lane_info.max_speed = 0.0
	net_lane_info.direction = LaneDirection.Auto
	net_lane_info.allowed_vehicles = { } as Dictionary[Enums.BaseDirection, Array]
	return net_lane_info
