class_name TransportDefinition

var stops: Array[StopDefinition] = []
var terminals: Array[TerminalDefinition] = []
var depots: Array[DepotDefinition] = []
var lines: Array[LineDefinition] = []
var demand_presets: Array[DemandPresetDefinition] = []


func serialize() -> Dictionary:
	var _stops: Array[Dictionary] = []
	var _depots: Array[Dictionary] = []
	var _terminals: Array[Dictionary] = []
	var _lines: Array[Dictionary] = []
	var _demand_presets: Array[Dictionary] = []

	for stop in self.stops:
		_stops.append(stop.serialize())

	for terminal in self.terminals:
		_terminals.append(terminal.serialize())

	for depot in self.depots:
		_depots.append(depot.serialize())

	for line in self.lines:
		_lines.append(line.serialize())

	for preset in self.demand_presets:
		_demand_presets.append(preset.serialize())

	return {
		"stops": _stops,
		"terminals": _terminals,
		"depots": _depots,
		"lines": _lines,
		"demandPresets": _demand_presets,
	}


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
