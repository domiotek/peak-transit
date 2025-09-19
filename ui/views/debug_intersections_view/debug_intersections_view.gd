extends PanelContainer

class_name DebugIntersectionsView

var item_scene = preload("res://ui/components/intersection_list_item/intersection_list_item.tscn")

var VIEW_NAME = "DebugIntersectionsView"

@onready var close_button = $MarginContainer/BoxContainer/HeaderContainer/CloseButton

@onready var content_container = $MarginContainer/BoxContainer/ScrollContainer/Content


var ui_manager: UIManager
var network_manager: NetworkManager

func _ready() -> void:
	ui_manager = GDInjector.inject("UIManager") as UIManager
	network_manager = GDInjector.inject("NetworkManager") as NetworkManager
	
	visible = false
	ui_manager.register_ui_view(VIEW_NAME, self)
	

	close_button.pressed.connect(_on_close_button_pressed)



func load() -> void:
	var nodes = network_manager.get_nodes()

	for node in nodes:
		var item = item_scene.instantiate() as IntersectionListItem
		item.init_item(node)
		content_container.add_child(item)


func _on_close_button_pressed() -> void:
	ui_manager.hide_ui_view(VIEW_NAME)