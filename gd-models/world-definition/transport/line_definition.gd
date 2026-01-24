class_name LineDefinition

var display_number: int = -1
var color_hex: String = "#FFFFFF"
var frequency_minutes: int
var min_layover_minutes: int
var start_time: TimeOfDay
var end_time: TimeOfDay
var routes: Array[Array] = []


func serialize() -> Dictionary:
	var _routes: Array[Array] = []

	for route in routes:
		var route_data: Array = []
		for step in route:
			route_data.append(step.serialize())
		_routes.append(route_data)

	return {
		"displayNumber": display_number,
		"color": color_hex,
		"frequency": frequency_minutes,
		"minLayover": min_layover_minutes,
		"startTime": start_time.format(),
		"endTime": end_time.format(),
		"routes": _routes,
	}


static func deserialize(data: Dictionary) -> LineDefinition:
	var line_def = LineDefinition.new()

	line_def.display_number = data["displayNumber"] as int
	line_def.color_hex = data["color"] as String
	line_def.frequency_minutes = data["frequency"] as int
	line_def.min_layover_minutes = data["minLayover"] as int
	line_def.start_time = TimeOfDay.parse(data["startTime"] as String)
	line_def.end_time = TimeOfDay.parse(data["endTime"] as String)

	if line_def.start_time == null:
		line_def.start_time = TimeOfDay.new(0, 0)

	if line_def.end_time == null:
		line_def.end_time = TimeOfDay.new(23, 59)

	for route in data["routes"] as Array:
		var route_steps: Array[RouteStepDefinition] = []
		for step_data in route as Array:
			var step_def = RouteStepDefinition.deserialize(step_data as Dictionary)
			route_steps.append(step_def)

		line_def.routes.append(route_steps)

	return line_def
