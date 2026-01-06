class_name StopDeparture

var line_id: int
var line_display_number: int
var line_color_hex: Color
var trip_idx: int
var direction: String
var brigade_id: int
var brigade_identifier: String
var departure_time: TimeOfDay


func _init(
		_line_id: int,
		_line_display_number: int,
		_line_color_hex: Color,
		_trip_idx: int,
		_direction: String,
		_brigade_id: int,
		_brigade_identifier: String,
		_departure_time: TimeOfDay,
) -> void:
	line_id = _line_id
	line_display_number = _line_display_number
	line_color_hex = _line_color_hex
	trip_idx = _trip_idx
	direction = _direction
	brigade_id = _brigade_id
	brigade_identifier = _brigade_identifier
	departure_time = _departure_time
