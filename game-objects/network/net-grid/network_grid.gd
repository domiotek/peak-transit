extends Node2D
class_name NetworkGrid


func _ready() -> void:
	var netdef = GDInjector.inject("NetworkDefinition") as NetworkDefinition
	var network_manager = GDInjector.inject("NetworkManager") as NetworkManager

	for node in netdef.Nodes:
		var road_node_scene = load("res://game-objects/network/net-node/network_node.tscn")
		var road_node = road_node_scene.instantiate()
		road_node.id = node.Id
		road_node.position = node.Position
		add_child(road_node)
		network_manager.register_node(road_node)

	network_manager.setup_network(self)
