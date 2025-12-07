extends ListItem

class_name DepartureListItem

var _line_id: int = 0
var _line_number: int = 0
var _line_color: Color = Color.TRANSPARENT
var _departure_time: TimeOfDay = null
var _delay_minutes: int = 0

@onready var line_tag = $LineTag
@onready var departure_time_label = $DepartureTimeLabel
@onready var delay_label = $TimeTillDepartureWrapper/DelayLabel
@onready var time_till_departure_label = $TimeTillDepartureWrapper/TimeTillDepartureLabel

@onready var game_manager = GDInjector.inject("GameManager") as GameManager

signal line_tag_clicked(line_id: int)


func _ready() -> void:
	super._ready()

	line_tag.update(_line_id, _line_number, _line_color)
	line_tag.clicked.connect(_on_line_tag_clicked)

	departure_time_label.text = _departure_time.format()

	if _delay_minutes > 0:
		delay_label.text = "+%d min" % _delay_minutes
		delay_label.visible = true
	else:
		delay_label.visible = false

	game_manager.clock.time_changed.connect(_on_time_changed)
	_on_time_changed(game_manager.clock.get_time())


func setup(line_id: int, line_number: int, line_color: Color, departure_time: TimeOfDay, delay_minutes: int) -> void:
	_line_id = line_id
	_line_number = line_number
	_line_color = line_color
	_departure_time = departure_time
	_delay_minutes = delay_minutes


func _on_time_changed(new_time: ClockTime) -> void:
	var minutes_diff = new_time.to_time_of_day().difference_in_minutes(_departure_time) * -1 + _delay_minutes

	if minutes_diff < 0:
		modulate = Color(0.7, 0.7, 0.7, 0.5)

	time_till_departure_label.text = _format_time_diff(minutes_diff)


func _format_time_diff(minutes_diff: int) -> String:
	if minutes_diff < 0:
		return "Departed"

	var hours = int(minutes_diff / 60.0)
	var minutes = minutes_diff % 60
	if hours > 0:
		return "%dh %02dm" % [hours, minutes]

	return "%dm" % minutes


func _on_line_tag_clicked(line_id: int) -> void:
	emit_signal("line_tag_clicked", line_id)
