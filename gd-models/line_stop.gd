class_name LineStop

var line: TransportLine
var stop_idx: int
var target_id: int
var target_name: String

var is_terminal: bool

var length: float = 0.0
var time_for_step: float = 0.0

var can_wait: bool = false


func _init(
		_line: TransportLine,
		_stop_idx: int,
		_is_terminal: bool,
		_target_id: int,
		_target_name: String,
		_length: float,
		_time_for_step: float,
		_can_wait: bool,
) -> void:
	line = _line
	stop_idx = _stop_idx
	is_terminal = _is_terminal
	target_id = _target_id
	target_name = _target_name
	length = _length
	can_wait = _can_wait
	time_for_step = _time_for_step
