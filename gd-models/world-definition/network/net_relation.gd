class_name NetRelation

var id: int
var start_node: RoadNode
var end_node: RoadNode
var lanes: Array[int] = []
var _buildings: Dictionary = { }
var _stops: Dictionary = { }

var relation_info: NetRelationInfo


func register_building(building_id: int, offset: float) -> void:
	_buildings[building_id] = {
		"id": building_id,
		"offset": offset,
	}


func register_stop(stop_id: int, offset: float) -> void:
	_stops[stop_id] = {
		"id": stop_id,
		"offset": offset,
	}


func get_stops() -> Dictionary:
	return _stops


func get_buildings() -> Dictionary:
	return _buildings


func get_leftmost_lane_id() -> int:
	if relation_info.lanes.size() == 0:
		push_error("No lanes in this relation.")
		return -1

	return lanes[0]


func get_rightmost_lane_id() -> int:
	if relation_info.lanes.size() == 0:
		push_error("No lanes in this relation.")
		return -1

	return lanes[lanes.size() - 1]


func get_road_edge_offset() -> float:
	return relation_info.lanes.size() * NetworkConstants.LANE_WIDTH
