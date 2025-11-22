class_name TransportLine

var id: int
var display_number: int
var color_hex: Color

var network_manager: NetworkManager = GDInjector.inject("NetworkManager") as NetworkManager
var path_manager: PathingManager = GDInjector.inject("PathingManager") as PathingManager
var transport_manager: TransportManager = GDInjector.inject("TransportManager") as TransportManager


func setup(new_id: int, line_def: LineDefinition) -> void:
	id = new_id
	display_number = line_def.display_number if line_def.display_number >= 0 else new_id
	color_hex = Color(line_def.color_hex)
