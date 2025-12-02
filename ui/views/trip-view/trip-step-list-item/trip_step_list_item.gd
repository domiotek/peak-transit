extends ListItem

class_name TripStepListItem

@onready var step_idx_label: Label = $StepIdxLabel
@onready var departure_time_label: Label = $DepartureTimeLabel

var _step_idx: int = -1
var _departure_time: TimeOfDay = null


func _ready() -> void:
	super._ready()
	step_idx_label.text = "%d." % _step_idx
	departure_time_label.text = _departure_time.format()


func set_step_idx(step_idx: int) -> void:
	_step_idx = step_idx


func set_departure_time(departure_time: TimeOfDay) -> void:
	_departure_time = departure_time
