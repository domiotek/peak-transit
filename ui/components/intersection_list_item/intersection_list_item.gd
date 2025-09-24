extends BoxContainer

class_name IntersectionListItem

var node: RoadNode
var init_main_text: String
var init_support_text: String
var init_value_text: String

@onready var label = $BoxContainer/MainLabel
@onready var support_label = $BoxContainer/SupportLabel
@onready var debug_button = $DebugButton

var game_manager: GameManager

func _ready() -> void:
	game_manager = GDInjector.inject("GameManager") as GameManager

	label.text = init_main_text
	support_label.text = init_support_text

	debug_button.pressed.connect(_on_debug_button_pressed)


func init_item(_node: RoadNode) -> void:
	self.node = _node
	init_main_text = "Node #%d" % node.id
	init_support_text = "Intersection Type: %s; Connected Segments: %d" % [node.intersection_manager.get_used_intersection_type(), node.connected_segments.size()]

func _on_debug_button_pressed() -> void:
	game_manager.set_selection(node, GameManager.SelectionType.NODE)
	game_manager.debug_selection = true
