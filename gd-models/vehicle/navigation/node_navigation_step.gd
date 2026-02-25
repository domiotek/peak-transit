extends NavigationStep

class_name NodeNavigationStep

var node: RoadNode
var from_endpoint: int
var to_endpoint: int
var is_intersection: bool
var direction: Enums.Direction


static func create(_node: RoadNode, new_path: Path2D, next_node_info: NextNodeInfo) -> NodeNavigationStep:
	var line_helper: LineHelper = GDInjector.inject("LineHelper") as LineHelper

	var step = NodeNavigationStep.new()
	step.type = Navigator.StepType.NODE
	step.node = _node
	step.path = line_helper.convert_curve_local_to_global(new_path.curve, _node)
	step.length = new_path.curve.get_baked_length()
	step.progress = 0.0
	step.from_endpoint = next_node_info.from
	step.to_endpoint = next_node_info.to
	step.is_intersection = _node.connected_segments.size() > 2
	step.direction = next_node_info.direction

	return step
