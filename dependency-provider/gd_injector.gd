extends Node

const ConnectionsHelperModule = preload("res://helpers/graphic-helpers/connections_helper.gd")
const LineHelperModule = preload("res://helpers/graphic-helpers/line_helper.gd")
const SegmentHelperModule = preload("res://helpers/graphic-helpers/segment_helper.gd")
const NodeLayerHelperModule = preload("res://helpers/graphic-helpers/node_layer_helper.gd")
const NetworkManagerModule = preload("res://services/managers/network_manager.gd")
const VehicleManagerModule = preload("res://services/managers/vehicle_manager.gd")
const SimulationManagerModule = preload("res://services/managers/simulation_manager.gd")
const PathingManagerModule = preload("res://services/managers/pathing_manager.gd")

var deferred_init_list = []

func inject(dep_name: String) -> Object:
	return DIContainer.Inject(dep_name)


func _ready()-> void:
	var on_ready_callback = Callable.create(self, "_init_deferred_dependencies")
	DIContainer.AddOnReadyCallback(on_ready_callback)

	_register_instances()


func _register_instances():
	_register_singleton("ConnectionsHelper", ConnectionsHelper.new())
	_register_singleton("LineHelper", LineHelper.new())
	_register_singleton("SegmentHelper", SegmentHelper.new())
	_register_singleton("NodeLayerHelper", NodeLayerHelper.new())
	_register_singleton("DebugCircleHelper", DebugCircleHelper.new())
	_register_singleton("NetworkManager", NetworkManager.new())
	_register_singleton("VehicleManager", VehicleManager.new())
	_register_singleton("SimulationManager", SimulationManager.new())
	_register_singleton("PathingManager", PathingManager.new())

func _register_singleton(dep_name: String, instance: Object):
	DIContainer.Register(dep_name, instance)

	deferred_init_list.append(instance)

func _init_deferred_dependencies():
	for dep in deferred_init_list:
		if dep.has_method("inject_dependencies"):
			dep.inject_dependencies()
