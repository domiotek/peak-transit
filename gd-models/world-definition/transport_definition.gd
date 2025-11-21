class_name TransportDefinition

var stops: Array[StopDefinition] = []


static func deserialize(data: Dictionary) -> TransportDefinition:
	var transport_def = TransportDefinition.new()

	for stop_data in data["stops"] as Array:
		var stop_def = StopDefinition.deserialize(stop_data as Dictionary)
		transport_def.stops.append(stop_def)

	return transport_def
