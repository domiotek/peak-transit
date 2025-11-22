class_name LineDefinition

var display_number: int = -1
var color_hex: String = "#FFFFFF"
var routes: Array[Array] = []


static func deserialize(data: Dictionary) -> LineDefinition:
	var line_def = LineDefinition.new()

	line_def.display_number = data["displayNumber"] as int
	line_def.color_hex = data["color"] as String

	for route in data["routes"] as Array:
		var route_steps: Array[RouteStepDefinition] = []
		for step_data in route as Array:
			var step_def = RouteStepDefinition.deserialize(step_data as Dictionary)
			route_steps.append(step_def)

		line_def.routes.append(route_steps)

	return line_def
