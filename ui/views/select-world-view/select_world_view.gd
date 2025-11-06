extends Panel

var LIST_ITEM_SCENE: PackedScene = preload("res://ui/components/list_item/list_item.tscn")
var CHEVRON_RIGHT_ICON: Texture2D = preload("res://assets/ui_icons/chevron_right.png")


@onready var cancel_button: Button = $PanelContainer/MarginContainer/MainContainer/ButtonsContainer/CancelButton
@onready var confirm_button: Button = $PanelContainer/MarginContainer/MainContainer/ButtonsContainer/ConfirmButton
@onready var open_folder_button: Button = $PanelContainer/MarginContainer/MainContainer/ButtonsContainer/OpenFolderButton

@onready var world_container: BoxContainer = $PanelContainer/MarginContainer/MainContainer/WorldList/MarginContainer/ScrollContainer/BoxContainer

@onready var world_manager: WorldManager = GDInjector.inject("WorldManager") as WorldManager

var selected_world_id: String = ""
var selected_world_item: ListItem = null

signal world_selected(world_file: String)


func _ready() -> void:
	cancel_button.connect("pressed", Callable(self, "_on_cancel_button_pressed"))
	confirm_button.connect("pressed", Callable(self, "_on_confirm_button_pressed"))
	open_folder_button.connect("pressed", Callable(self, "_on_open_folder_button_pressed"))

func init() -> void:
	visible = true
	_populate_world_list()



func _on_cancel_button_pressed() -> void:
	visible = false
	_cleanup()

func _on_confirm_button_pressed() -> void:
	visible = false
	emit_signal("world_selected", selected_world_id)
	_cleanup()

func _on_open_folder_button_pressed() -> void:
	world_manager.OpenWorldsFolder()

func _populate_world_list() -> void:
	var worlds = world_manager.GetAvailableWorlds()
	worlds = worlds.map(func (w):
		return SlimWorldDefinition.deserialize(w)
	) as Array[SlimWorldDefinition]

	for world in worlds:
		var list_item = LIST_ITEM_SCENE.instantiate() as ListItem
		var base_name = world.name
		var final_name = base_name if world.built_in == false else "%s (Built-in)" % base_name

		list_item.init_item(final_name, world.description)
		list_item.set_data({"world": world})
		list_item.show_button(CHEVRON_RIGHT_ICON)
		list_item.connect("button_pressed", Callable(self, "_on_world_item_selected"))
		world_container.add_child(list_item)


func _on_world_item_selected(sender: ListItem, data: Dictionary) -> void:
	if selected_world_item:
		selected_world_item.disable_button(false)
	
	sender.disable_button(true)
	selected_world_id = data["world"].file_path
	selected_world_item = sender
	confirm_button.disabled = false

func _cleanup() -> void:
	selected_world_id = ""
	selected_world_item = null
	confirm_button.disabled = true

	for child in world_container.get_children():
		child.queue_free()
