extends PanelContainer

class_name BusesView

var item_scene = preload("res://ui/components/bus-list-item/bus_list_item.tscn")
var jump_to_resource = preload("res://assets/ui_icons/jump_to_element.png")

const VIEW_NAME = "BusesView"

var _ui_manager: UIManager
var _vehicle_manager: VehicleManager
var _game_manager: GameManager

@onready var bus_list: BoxContainer = $MainWrapper/Scroller/MarginContainer2/List


func _ready() -> void:
	visible = false
	_ui_manager = GDInjector.inject("UIManager") as UIManager
	_vehicle_manager = GDInjector.inject("VehicleManager") as VehicleManager
	_game_manager = GDInjector.inject("GameManager") as GameManager
	_ui_manager.register_ui_view(VIEW_NAME, self)

	_vehicle_manager.vehicle_created.connect(_on_vehicle_created)
	_vehicle_manager.vehicle_destroyed.connect(_on_vehicle_destroyed)


func update(_data) -> void:
	for child in bus_list.get_children():
		child.queue_free()

	var buses = _vehicle_manager.get_vehicles_by_types([VehicleManager.VehicleType.BUS, VehicleManager.VehicleType.ARTICULATED_BUS])

	for bus in buses:
		var list_item: BusListItem = item_scene.instantiate() as BusListItem
		list_item.init_item(bus.ai.get_custom_identifier(), bus.ai.get_state_name())
		list_item.set_vehicle(bus)
		list_item.show_button(jump_to_resource)
		list_item.set_data({ "vehicle": bus })
		list_item.button_pressed.connect(_on_item_button_pressed)
		bus_list.add_child(list_item)


func _on_item_button_pressed(_sender: ListItem, data: Dictionary) -> void:
	var vehicle: Vehicle = data["vehicle"] as Vehicle

	_game_manager.set_selection(vehicle, GameManager.SelectionType.VEHICLE)
	_game_manager.jump_to_selection()


func _on_vehicle_created(vehicle: Vehicle) -> void:
	if not visible:
		return

	if vehicle.type == VehicleManager.VehicleType.BUS or vehicle.type == VehicleManager.VehicleType.ARTICULATED_BUS:
		update({ })


func _on_vehicle_destroyed(_vehicle_id: int, vehicle_type: VehicleManager.VehicleType) -> void:
	if not visible:
		return

	if vehicle_type == VehicleManager.VehicleType.BUS or vehicle_type == VehicleManager.VehicleType.ARTICULATED_BUS:
		update({ })
