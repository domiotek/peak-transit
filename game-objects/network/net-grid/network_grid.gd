extends Node2D
class_name NetworkGrid

var NETWORK_NODE = preload("res://game-objects/network/net-node/network_node.tscn")


func _ready() -> void:
	var netdef = GDInjector.inject("NetworkDefinition") as NetworkDefinition
	var network_manager = GDInjector.inject("NetworkManager") as NetworkManager

	for node in netdef.Nodes:
		var road_node = NETWORK_NODE.instantiate()
		road_node.id = node.Id
		road_node.position = node.Position
		road_node.definition = node
		add_child(road_node)
		network_manager.register_node(road_node)

	network_manager.setup_network(self)
