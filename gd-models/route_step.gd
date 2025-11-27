class_name RouteStep

var step_type: Enums.TransportRouteStepType
var target_name: String
var target_id: int
var length: float = 0.0
var time_for_step: float = 0.0


func _init(_step_type: Enums.TransportRouteStepType, _target_name: String, _target_id: int, _length: float, _time: float) -> void:
	self.step_type = _step_type
	self.target_name = _target_name
	self.target_id = _target_id
	self.length = _length
	self.time_for_step = _time
