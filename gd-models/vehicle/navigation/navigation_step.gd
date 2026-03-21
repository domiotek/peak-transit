class_name NavigationStep

var type: Navigator.StepType
var path: Curve2D
var length: float
var progress: float
var max_speed: float = INF

func get_percent_complete() -> float:
	if length == 0.0:
		return 1.0
	return progress / length


static func create_empty_step() -> NavigationStep:
	var step = NavigationStep.new()
	step.type = Navigator.StepType.NONE
	step.path = null
	step.length = 0.0
	step.progress = 0.0
	step.max_speed = INF

	return step


static func create_custom_step(_path: Path2D, _max_speed: float = INF) -> NavigationStep:
	var step = NavigationStep.new()
	step.type = Navigator.StepType.CUSTOM
	step.path = _path.curve
	step.length = _path.curve.get_baked_length()
	step.progress = 0.0
	step.max_speed = _max_speed if _max_speed > 0.0 else INF

	return step
