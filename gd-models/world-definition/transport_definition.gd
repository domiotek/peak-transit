class_name TransportDefinition

var stops: Array[StopDefinition] = []
var terminals: Array[TerminalDefinition] = []
var depots: Array[DepotDefinition] = []
var lines: Array[LineDefinition] = []
var demand_presets: Array[DemandPresetDefinition] = []


static func deserialize(data: Dictionary) -> TransportDefinition:
	var transport_def = TransportDefinition.new()

	for stop_data in data["stops"] as Array:
		var stop_def = StopDefinition.deserialize(stop_data as Dictionary)
		transport_def.stops.append(stop_def)

	for terminal_data in data["terminals"] as Array:
		var terminal_def = TerminalDefinition.deserialize(terminal_data as Dictionary)
		transport_def.terminals.append(terminal_def)

	for depot_data in data["depots"] as Array:
		var depot_def = DepotDefinition.deserialize(depot_data as Dictionary)
		transport_def.depots.append(depot_def)

	for line_data in data["lines"] as Array:
		var line_def = LineDefinition.deserialize(line_data as Dictionary)
		transport_def.lines.append(line_def)

	for preset_data in data["demandPresets"] as Array:
		var preset_def = DemandPresetDefinition.deserialize(preset_data as Dictionary)
		transport_def.demand_presets.append(preset_def)

	return transport_def
