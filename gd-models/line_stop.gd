class_name LineStop

var line: TransportLine
var stop_idx: int
var target_id: int
var target_name: String

var is_terminal: bool

var route_offset_length: float = 0.0
var length: float = 0.0
var time_for_step: float = 0.0

var can_wait: bool = false

var _transport_manager: TransportManager = GDInjector.inject("TransportManager") as TransportManager


func _init(
		_line: TransportLine,
		_stop_idx: int,
		_is_terminal: bool,
		_target_id: int,
		_target_name: String,
		_route_offset_length: float,
		_length: float,
		_time_for_step: float,
		_can_wait: bool,
) -> void:
	line = _line
	stop_idx = _stop_idx
	is_terminal = _is_terminal
	target_id = _target_id
	target_name = _target_name
	route_offset_length = _route_offset_length
	length = _length
	can_wait = _can_wait
	time_for_step = _time_for_step


func get_stop_selection() -> StopSelection:
	if is_terminal:
		var terminal = _transport_manager.get_terminal(target_id)
		var terminal_peron = TerminalPeron.new(terminal, terminal.get_peron_for_line(line.id))
		return StopSelection.new(StopSelection.StopSelectionType.TERMINAL_PERON, terminal_peron)

	var stop = _transport_manager.get_stop(target_id)
	return StopSelection.new(StopSelection.StopSelectionType.STOP, stop)
