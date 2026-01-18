class_name NetRelation

var id: int
var start_node: RoadNode
var end_node: RoadNode
var lanes: Array[int] = []
var _buildings: Dictionary = { }
var _stops: Dictionary = { }

var relation_info: NetRelationInfo


func register_building(building_id: int, offset: float, horizontal_offset: float = 0.0) -> void:
	_buildings[building_id] = {
		"id": building_id,
		"offset": offset,
		"horizontal_offset": horizontal_offset,
	}


func unregister_building(building_id: int) -> void:
	_buildings.erase(building_id)


func register_stop(stop_id: int, offset: float) -> void:
	_stops[stop_id] = {
		"id": stop_id,
		"offset": offset,
		"horizontal_offset": 0.0,
	}


func unregister_stop(stop_id: int) -> void:
	_stops.erase(stop_id)


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


func get_lane_count() -> int:
	return lanes.size()


func get_road_edge_offset() -> float:
	return lanes.size() * NetworkConstants.LANE_WIDTH
