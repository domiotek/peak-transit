extends ListItem

class_name BusListItem

@onready var brigade_tag: LineTag = $BrigadeTag
@onready var passengers_label: Label = $PassengersLabel

var _vehicle: Vehicle = null


func _ready() -> void:
	super._ready()


func set_vehicle(vehicle: Vehicle) -> void:
	_vehicle = vehicle


func _process(_delta: float) -> void:
	if _vehicle == null:
		return

	var ai = _vehicle.ai as BusAI

	var passenger_counts = ai.get_passenger_counts()
	passengers_label.text = str(passenger_counts["current_passengers"]) + " / " + str(passenger_counts["max_passengers"])

	label.text = ai.get_custom_identifier()
	support_label.text = ai.get_state_name()

	var brigade = ai.get_brigade()

	if brigade == null:
		brigade_tag.update(0, "Reserve", TransportConstants.BUS_DEFAULT_COLOR)
		return

	brigade_tag.update(brigade.line_id, brigade.get_identifier(), brigade.line_color)
