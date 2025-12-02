extends ListItem

class_name TripListItem

@onready var idx_label: Label = $IdxLabel
@onready var service_time_label: Label = $ServiceTimeLabel

var _idx: int = -1
var _service_time: String = ""


func _ready() -> void:
	super._ready()

	idx_label.text = "#%d" % _idx
	service_time_label.text = _service_time


func set_idx(idx: int) -> void:
	_idx = idx


func set_service_time(start_time: TimeOfDay, end_time: TimeOfDay) -> void:
	var duration_minutes = end_time.to_minutes() - start_time.to_minutes()

	if duration_minutes < 0:
		duration_minutes += 24 * 60

	_service_time = "%s - %s (%d min)" % [start_time.format(), end_time.format(), duration_minutes]
