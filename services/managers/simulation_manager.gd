extends RefCounted

class_name SimulationManager

var vehicle_manager: VehicleManager
var network_manager: NetworkManager

var simulation_running: bool = false

func _init() -> void:
	vehicle_manager = GDInjector.inject("VehicleManager") as VehicleManager
	network_manager = GDInjector.inject("NetworkManager") as NetworkManager



func start_simulation() -> void:
	print("Simulation started")
	simulation_running = true


func is_simulation_running() -> bool:
	return simulation_running
