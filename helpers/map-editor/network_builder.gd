class_name NetworkBuilder

var NetworkNodeScene = preload("res://game-objects/network/net-node/network_node.tscn")
var NetworkSegmentScene = preload("res://game-objects/network/net-segment/net_segment.tscn")

var _network_manager: NetworkManager = GDInjector.inject("NetworkManager") as NetworkManager


func create_node(position: Vector2) -> RoadNode:
	var node = NetworkNodeScene.instantiate() as RoadNode
	node.definition = NetNodeInfo.get_default()
	node.set_id(_network_manager.get_next_node_id())
	node.position = position

	return node


func create_segment(node_a: RoadNode, node_b: RoadNode, segment_info: NetSegmentInfo) -> NetSegment:
	var segment = NetworkSegmentScene.instantiate()
	segment.setup(node_a, node_b, segment_info)

	for i in range(segment_info.relations.size()):
		var relation = segment_info.relations[i]
		if i == 0:
			segment.add_connection(node_a, node_b, relation)
		else:
			segment.add_connection(node_b, node_a, relation)

	return segment


func build_road(
		start_node: RoadNode,
		target_node: RoadNode,
		segment_info: NetSegmentInfo,
		registrator: Callable,
		created_start_node: bool = false,
		created_target_node: bool = false,
) -> NetSegment:
	start_node.reset_visuals()
	target_node.reset_visuals()

	var segment = create_segment(start_node, target_node, segment_info)

	registrator.call(segment)
	_network_manager.register_segment(segment)
	segment.update_visuals()

	start_node.update_visuals()
	target_node.update_visuals()

	segment.late_update_visuals()

	if not created_start_node:
		start_node.reposition_all_endpoints()

	if not created_target_node:
		target_node.reposition_all_endpoints()

	start_node.late_update_visuals()
	target_node.late_update_visuals()

	return segment


func destroy_road(
		segment: NetSegment,
) -> void:
	_network_manager.unregister_segment(segment)

	for node in segment.nodes:
		node.remove_segment(segment)
		if not node.has_connected_segments():
			_network_manager.unregister_node(node)
			node.queue_free()

	segment.queue_free()


func get_2way_relations(num_lanes: int) -> Array[NetRelationInfo]:
	var relations: Array[NetRelationInfo] = []

	var lane_relation_a = NetRelationInfo.new()

	lane_relation_a.lanes = [] as Array[NetLaneInfo]

	for i in range(num_lanes):
		lane_relation_a.lanes.append(NetLaneInfo.get_default())

	relations.append(lane_relation_a)

	var lane_relation_b = NetRelationInfo.new()
	lane_relation_b.lanes = [] as Array[NetLaneInfo]

	for i in range(num_lanes):
		lane_relation_b.lanes.append(NetLaneInfo.get_default())

	relations.append(lane_relation_b)

	return relations
