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
	LeftRight,
}

var max_speed: float
var direction: LaneDirection
var allowed_vehicles: Dictionary


func set_direction(new_direction: LaneDirection) -> void:
	direction = new_direction


func set_direction_from_enum(direction_enum: Enums.Direction) -> void:
	match direction_enum:
		Enums.Direction.FORWARD:
			direction = LaneDirection.Forward
		Enums.Direction.BACKWARD:
			direction = LaneDirection.Backward
		Enums.Direction.LEFT:
			direction = LaneDirection.Left
		Enums.Direction.RIGHT:
			direction = LaneDirection.Right
		Enums.Direction.LEFT_RIGHT:
			direction = LaneDirection.LeftRight
		Enums.Direction.LEFT_FORWARD:
			direction = LaneDirection.ForwardLeft
		Enums.Direction.RIGHT_FORWARD:
			direction = LaneDirection.ForwardRight
		Enums.Direction.ALL_DIRECTIONS:
			direction = LaneDirection.All
		_:
			direction = LaneDirection.Auto


func set_allowed_vehicles(new_allowed_vehicles: Dictionary) -> void:
	allowed_vehicles = new_allowed_vehicles


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
