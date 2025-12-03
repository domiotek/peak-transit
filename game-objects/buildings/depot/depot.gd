extends BaseBuilding

class_name Depot

var depot_id: int

var _depot_data: DepotDefinition


func setup_depot(new_id: int, depot_data: DepotDefinition) -> void:
	depot_id = new_id
	_depot_data = depot_data


func update_visuals() -> void:
	# Depots might have specific visuals to update in the future
	pass


func get_position_offset() -> float:
	return _depot_data.position.offset


func get_incoming_node_id() -> int:
	return _depot_data.position.segment[0]


func get_outgoing_node_id() -> int:
	return _depot_data.position.segment[1]


func _get_connection_endpoints() -> Dictionary:
	return {
		"in": to_global(Vector2(10, -25)),
		"out": to_global(Vector2(-10, -25)),
	}
