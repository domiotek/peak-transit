class_name RouteStep

var step_type: Enums.TransportRouteStepType
var target_name: String
var target_id: int


func _init(_step_type: Enums.TransportRouteStepType, _target_name: String, _target_id: int) -> void:
	self.step_type = _step_type
	self.target_name = _target_name
	self.target_id = _target_id
