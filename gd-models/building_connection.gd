class_name BuildingConnectionInfo

enum BuildingConnectionType {
	IN,
	OUT,
}

const BUILDING_CONNECTION_TYPES = [BuildingConnectionType.IN, BuildingConnectionType.OUT]

var lane: NetLane
var relation: BuildingConnectionType
var is_outgoing: bool
var from: Vector2
var to: Vector2
var lane_point: Vector2
var path: Path2D
var is_opposite_relation: bool
var from_endpoint: int
var next_endpoint: int


static func create(
		_lane: NetLane,
		_path: Path2D,
		is_forward: bool,
		building_endpoint: Vector2,
		connection_point: Vector2,
		is_same_relation: bool,
) -> BuildingConnectionInfo:
	var info = BuildingConnectionInfo.new()
	info.lane = _lane
	info.path = _path
	info.relation = BuildingConnectionType.OUT if is_forward else BuildingConnectionType.IN
	info.is_outgoing = is_forward
	info.from = building_endpoint if is_forward else connection_point
	info.to = connection_point if is_forward else building_endpoint
	info.lane_point = connection_point
	info.from_endpoint = _lane.from_endpoint if not is_forward else -1
	info.next_endpoint = _lane.to_endpoint if is_forward else -1
	info.is_opposite_relation = not is_same_relation

	return info


class BuildingConnectionCollection:
	var in_connections: Dictionary[int, BuildingConnectionInfo] = { }
	var out_connections: Dictionary[int, BuildingConnectionInfo] = { }


	func get_collections() -> Array[Dictionary]:
		return [in_connections, out_connections]


	func get_collection_by_key(type: BuildingConnectionType) -> Dictionary[int, BuildingConnectionInfo]:
		return in_connections if type == BuildingConnectionType.IN else out_connections


	func get_collection_by_bool(is_out: bool) -> Dictionary[int, BuildingConnectionInfo]:
		return in_connections if not is_out else out_connections


	func find_connection(is_out: bool, endpoint_id: int) -> BuildingConnectionInfo:
		var collection = get_collection_by_bool(is_out)
		return collection.get(endpoint_id)


	func add_connection(is_out: bool, endpoint_id: int, connection_info: BuildingConnectionInfo) -> void:
		var collection = get_collection_by_bool(is_out)
		collection[endpoint_id] = connection_info
