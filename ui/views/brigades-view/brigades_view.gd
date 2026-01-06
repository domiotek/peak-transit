extends PanelContainer

class_name BrigadesView

var item_scene = preload("res://ui/components/brigade-list/brigade-list-item/brigade_list_item.tscn")
const CHEVRON_RIGHT_ICON: Resource = preload("res://assets/ui_icons/chevron_right.png")

const VIEW_NAME = "BrigadesView"

var _selected_brigade_id: int = -1
var _selected_trip_idx: int = -1

var ui_manager: UIManager
var transport_manager: TransportManager

@onready var go_back_button: Button = $MainWrapper/HeaderMargins/HeaderFlex/GoBackButton
@onready var brigade_list: BrigadeList = $MainWrapper/BrigadeList
@onready var brigade_view: Node = $MainWrapper/BrigadeView
@onready var trip_view: Node = $MainWrapper/TripView


func _ready() -> void:
	ui_manager = GDInjector.inject("UIManager") as UIManager
	transport_manager = GDInjector.inject("TransportManager") as TransportManager

	visible = false
	ui_manager.register_ui_view(VIEW_NAME, self)

	go_back_button.pressed.connect(Callable(self, "_on_go_back_button_pressed"))
	brigade_list.item_button_pressed.connect(Callable(self, "_on_item_button_pressed"))
	brigade_view.trip_selected.connect(Callable(self, "_on_trip_selected"))


func _exit_tree() -> void:
	ui_manager.unregister_ui_view(VIEW_NAME)


func load() -> void:
	var brigades = transport_manager.brigades.get_all()

	brigade_list.display_items(brigades)


func update(_data) -> void:
	if _data.has("brigade"):
		var brigade = _data["brigade"] as Brigade
		var trip_idx = _data.get("trip_id", -1)
		if trip_idx != -1:
			_show_trip_view(brigade, trip_idx)
		else:
			_show_brigade_view(brigade)
	else:
		_on_go_back_button_pressed()


func _on_item_button_pressed(_sender: ListItem, data: Dictionary) -> void:
	var brigade = data.get("brigade", null) as Brigade
	if brigade:
		_show_brigade_view(brigade)


func _show_brigade_view(brigade: Brigade) -> void:
	_selected_brigade_id = brigade.id
	brigade_view.visible = true
	brigade_view.setup(brigade)
	brigade_list.visible = false
	trip_view.visible = false
	go_back_button.visible = true


func _show_trip_view(brigade: Brigade, trip_idx: int) -> void:
	_selected_trip_idx = trip_idx
	trip_view.visible = true
	trip_view.setup(brigade, trip_idx)
	brigade_view.visible = false
	brigade_list.visible = false
	go_back_button.visible = true


func _on_go_back_button_pressed() -> void:
	if _selected_trip_idx != -1:
		brigade_view.visible = true
		trip_view.visible = false
		_selected_trip_idx = -1
		return

	brigade_view.visible = false
	brigade_list.visible = true
	go_back_button.visible = false
	_selected_brigade_id = -1
	_selected_trip_idx = -1


func _on_close_button_pressed() -> void:
	ui_manager.hide_ui_view(VIEW_NAME)


func _on_trip_selected(brigade: Brigade, trip_idx: int) -> void:
	_show_trip_view(brigade, trip_idx)
