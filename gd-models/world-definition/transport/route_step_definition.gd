class_name RouteStepDefinition

var step_type: Enums.TransportRouteStepType
var target_id: int = -1


static func deserialize(data: Dictionary) -> RouteStepDefinition:
	var route_step_def = RouteStepDefinition.new()

	route_step_def.step_type = data.get("type") as Enums.TransportRouteStepType
	route_step_def.target_id = data.get("targetId") as int

	return route_step_def
