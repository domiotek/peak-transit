extends PanelContainer

class_name DebugIntersectionsView

var item_scene = preload("res://ui/components/list_item/list_item.tscn")
var CHEVRON_RIGHT_ICON: Resource = preload("res://assets/ui_icons/chevron_right.png")

var VIEW_NAME = "DebugIntersectionsView"

@onready var go_back_button = $MarginContainer/BoxContainer/HeaderContainer/GoBackButton
@onready var close_button = $MarginContainer/BoxContainer/HeaderContainer/CloseButton
@onready var content_container = $MarginContainer/BoxContainer/ScrollContainer/Content/ListContent

@onready var item_list_container = $MarginContainer/BoxContainer/ScrollContainer/Content/ListContent
@onready var traffic_lights_view = $MarginContainer/BoxContainer/ScrollContainer/Content/TrafficLightsView
@onready var default_view = $MarginContainer/BoxContainer/ScrollContainer/Content/DefaultView

var selected_node: RoadNode = null
var selected_view: String = ""

var ui_manager: UIManager
var network_manager: NetworkManager

func _ready() -> void:
	ui_manager = GDInjector.inject("UIManager") as UIManager
	network_manager = GDInjector.inject("NetworkManager") as NetworkManager
	
	visible = false
	ui_manager.register_ui_view(VIEW_NAME, self)
	
	go_back_button.pressed.connect(_on_go_back_button_pressed)
	close_button.pressed.connect(_on_close_button_pressed)



func load() -> void:
	var nodes = network_manager.get_nodes()

	for node in nodes:
		var item = item_scene.instantiate() as ListItem
		item.init_item("Node #%d" % node.id, "Intersection Type: %s; Connected Segments: %d" % [node.intersection_manager.get_used_intersection_type(), node.connected_segments.size()])
		item.show_button(CHEVRON_RIGHT_ICON)
		item.set_data({"node": node})
		item.button_pressed.connect(Callable(self, "_on_item_button_pressed"))
		content_container.add_child(item)


func _on_item_button_pressed(data: Dictionary) -> void:
	selected_node = data.get("node", null)
	var intersection_type = selected_node.intersection_manager.get_used_intersection_type()
	var view = _get_view(intersection_type)

	if view:
		go_back_button.visible = true
		item_list_container.visible = false
		view.visible = true
		view.bind(selected_node)
		selected_view = intersection_type

func _on_go_back_button_pressed() -> void:
	if selected_view == "":
		return

	var view = _get_view(selected_view)
	if view:
		view.unbind()
		view.visible = false
		item_list_container.visible = true
		go_back_button.visible = false
		selected_view = ""
		selected_node = null

func _on_close_button_pressed() -> void:
	ui_manager.hide_ui_view(VIEW_NAME)

func _get_view(view_name: String) -> Control:
	match view_name:
		"TrafficLightsIntersection":
			return traffic_lights_view
		"NullIntersection", "DefaultIntersection":
			return default_view
		_:
			push_error("Unknown view requested: %s" % view_name)
			return null
