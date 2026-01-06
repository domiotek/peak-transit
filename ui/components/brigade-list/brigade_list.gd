extends ScrollContainer

class_name BrigadeList

var item_scene = preload("res://ui/components/brigade-list/brigade-list-item/brigade_list_item.tscn")
const CHEVRON_RIGHT_ICON: Resource = preload("res://assets/ui_icons/chevron_right.png")

@onready var box: BoxContainer = $MarginContainer/ItemList

signal item_button_pressed(sender: ListItem, data: Dictionary)


func display_items(brigades: Array) -> void:
	for child in box.get_children():
		child.queue_free()

	for brigade in brigades:
		var item = item_scene.instantiate() as ListItem
		item.init_item(
			str(brigade.get_identifier()),
			"Trips: %d; Cycle Time: %dmin; Vehicles: %d" % [brigade.get_trip_count(), brigade.get_cycle_time(), brigade.get_vehicle_count()],
		)
		item.set_data({ "brigade": brigade })
		item.set_service_time(brigade.get_start_time(), brigade.get_end_time())
		item.show_button(CHEVRON_RIGHT_ICON)
		item.button_pressed.connect(Callable(self, "_on_item_button_pressed"))

		box.add_child(item)


func _on_item_button_pressed(sender: ListItem, data: Dictionary) -> void:
	emit_signal("item_button_pressed", sender, data)
