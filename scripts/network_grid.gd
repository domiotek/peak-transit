extends Node2D
class_name NetworkGrid


func _ready() -> void:
	var netdef = get_node("/root/NetworkDefinition")

	for node in netdef.Nodes:
		var road_node_scene = load("res://scenes/network_node.tscn")
		var road_node = road_node_scene.instantiate()
		road_node.id = node.Id
		road_node.position = node.Position
		add_child(road_node)
		NetworkManager.register_node(road_node)

	NetworkManager.setup_network(self)
	
