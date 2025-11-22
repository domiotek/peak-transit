class_name TransportDefinition

var stops: Array[StopDefinition] = []
var terminals: Array[TerminalDefinition] = []
var lines: Array[LineDefinition] = []


static func deserialize(data: Dictionary) -> TransportDefinition:
	var transport_def = TransportDefinition.new()

	for stop_data in data["stops"] as Array:
		var stop_def = StopDefinition.deserialize(stop_data as Dictionary)
		transport_def.stops.append(stop_def)

	for terminal_data in data["terminals"] as Array:
		var terminal_def = TerminalDefinition.deserialize(terminal_data as Dictionary)
		transport_def.terminals.append(terminal_def)

	for line_data in data["lines"] as Array:
		var line_def = LineDefinition.deserialize(line_data as Dictionary)
		transport_def.lines.append(line_def)

	return transport_def
