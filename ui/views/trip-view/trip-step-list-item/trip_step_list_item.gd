extends ListItem

class_name TripStepListItem

@onready var step_idx_label: Label = $StepIdxLabel
@onready var departure_time_label: Label = $DepartureTimeLabel
@onready var time_label: Label = $TimeLabel
@onready var diff_label: Label = $DiffLabel

var _step_idx: int = -1
var _departure_time: TimeOfDay = null
var _has_departed: bool = false


func _ready() -> void:
	super._ready()
	step_idx_label.text = "%d." % _step_idx
	departure_time_label.text = _departure_time.format()


func set_step_idx(step_idx: int) -> void:
	_step_idx = step_idx


func set_departure_time(departure_time: TimeOfDay) -> void:
	_departure_time = departure_time


func update_schedule_diff(time_diff: int, current_time: TimeOfDay) -> void:
	if _departure_time == null or _has_departed:
		return

	var new_departure_time = _departure_time.add_minutes(time_diff)

	var time_left = new_departure_time.to_minutes() - current_time.to_minutes()

	time_label.text = "%smin" % time_left

	if time_diff > 0:
		diff_label.text = "+%dmin" % time_diff
	elif time_diff < 0:
		diff_label.text = "%dmin" % time_diff
	else:
		diff_label.text = "OK"


func mark_departed() -> void:
	modulate = Color(0.7, 0.7, 0.7)
	_has_departed = true
	diff_label.text = ""
	time_label.text = ""
