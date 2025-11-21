class_name TransportManager

const StopScene = preload("res://game-objects/stop/stop.tscn")

var _network_manager: NetworkManager

var _stops: Dictionary = { }


func inject_dependencies() -> void:
	_network_manager = GDInjector.inject("NetworkManager") as NetworkManager


func register_stop(stop_def: StopDefinition) -> bool:
	var validation_error = TransportHelper.validate_stop_definition(_network_manager, stop_def)

	if validation_error.length() > 0:
		push_error("Invalid stop definition: %s - %s" % [stop_def.name, validation_error])
		return false

	var idx = _get_next_idx(_stops)

	if not stop_def.name or stop_def.name == "":
		stop_def.name = "Stop %d" % idx

	var stop = StopScene.instantiate() as Stop

	var target_segment = _network_manager.get_segment_between_nodes(
		stop_def.position.segment[0],
		stop_def.position.segment[1],
	)

	stop.setup(idx, stop_def, target_segment)

	if not target_segment.try_place_stop(stop):
		push_error("Failed to place stop on segment: %s" % stop_def.name)
		return false

	_stops[idx] = stop

	return true


func get_stop(stop_id: int) -> Stop:
	if not _stops.has(stop_id):
		push_error("Stop ID not found: " + str(stop_id))
		return null
	return _stops[stop_id] as Stop


func _get_next_idx(dict: Dictionary) -> int:
	return dict.size()
