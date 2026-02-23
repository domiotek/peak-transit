extends ListItem

class_name ScoreListItem

@onready var score_label: Label = $ScoreLabel

var _score: float = 0


func _ready() -> void:
	super._ready()

	score_label.text = str(_score)
	score_label.label_settings = score_label.label_settings.duplicate()
	score_label.label_settings.font_color = Color(0, 1, 0) if _score > 0 else Color(1, 0, 0)


func set_score(score: float) -> void:
	_score = score
