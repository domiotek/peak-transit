extends ListItem

class_name BrigadeListItem

@onready var service_time_label: Label = $ServiceTimeLabel

var _service_time: String = ""


func _ready() -> void:
	super._ready()

	service_time_label.text = _service_time


func set_service_time(start_time: TimeOfDay, end_time: TimeOfDay) -> void:
	_service_time = "%s - %s" % [start_time.format(), end_time.format()]
