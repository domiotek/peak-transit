class_name TransportManager

const StopScene = preload("res://game-objects/stop/stop.tscn")
var TerminalScene = load("res://game-objects/buildings/terminal/terminal.tscn")

var _network_manager: NetworkManager

var _stops: Dictionary = { }
var _terminals: Dictionary = { }


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

	target_segment.place_stop(stop)

	_stops[idx] = stop

	return true


func get_stop(stop_id: int) -> Stop:
	if not _stops.has(stop_id):
		push_error("Stop ID not found: " + str(stop_id))
		return null
	return _stops[stop_id] as Stop


func register_terminal(terminal_def: TerminalDefinition) -> bool:
	var validation_error = TransportHelper.validate_terminal_definition(_network_manager, terminal_def)

	if validation_error.length() > 0:
		push_error("Invalid terminal definition: %s - %s" % [terminal_def.name, validation_error])
		return false

	var idx = _get_next_idx(_terminals)

	if not terminal_def.name or terminal_def.name == "":
		terminal_def.name = "Terminal %d" % idx

	var terminal_building = TerminalScene.instantiate() as Terminal

	var target_segment = _network_manager.get_segment_between_nodes(
		terminal_def.position.segment[0],
		terminal_def.position.segment[1],
	)

	var target_relation = target_segment.get_relation_with_starting_node(terminal_def.position.segment[0]) as NetRelation

	var building_info = BuildingInfo.new()
	building_info.type = BuildingInfo.BuildingType.TERMINAL
	building_info.offset_position = terminal_def.position.offset

	terminal_building.setup(target_relation.id, target_segment, building_info)
	terminal_building.setup_terminal(idx, terminal_def)

	target_segment.place_terminal(terminal_building)

	terminal_building.setup_connections()

	_terminals[idx] = terminal_building

	return true


func _get_next_idx(dict: Dictionary) -> int:
	return dict.size()
