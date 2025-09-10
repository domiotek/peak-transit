extends RefCounted

class_name SimulationManager

var vehicle_manager: VehicleManager
var network_manager: NetworkManager


func _init() -> void:
	vehicle_manager = GDInjector.inject("VehicleManager") as VehicleManager
	network_manager = GDInjector.inject("NetworkManager") as NetworkManager



func start_simulation() -> void:
	print("Simulation started")

	var vehicle = vehicle_manager.create_vehicle()

	vehicle.init_trip(8, 5)
