extends BoxContainer

class_name GameObjectStatsView

const VIEW_NAME = "GameObjectStatsView"

@onready var _ui_manager: UIManager = GDInjector.inject("UIManager") as UIManager
@onready var _pathing_manager: PathingManager = GDInjector.inject("PathingManager") as PathingManager
@onready var _vehicle_manager: VehicleManager = GDInjector.inject("VehicleManager") as VehicleManager
@onready var _config_manager: ConfigManager = GDInjector.inject("ConfigManager") as ConfigManager

@onready var pathing_requests: ValueListItem = $PathingRequests
@onready var vehicles_count: ValueListItem = $VehiclesCount


func _ready() -> void:
	visible = false
	_ui_manager.register_ui_view(VIEW_NAME, self)
	_config_manager.DebugToggles.ToggleChanged.connect(Callable(self, "_on_debug_toggles_changed"))


func _exit_tree() -> void:
	_ui_manager.unregister_ui_view(VIEW_NAME)


func _process(_delta: float) -> void:
	if not visible:
		return

	pathing_requests.set_value(str(_pathing_manager.get_request_count()))
	vehicles_count.set_value(str(_vehicle_manager.vehicles_count()))


func _on_debug_toggles_changed(toggle_name: String, value: bool) -> void:
	if toggle_name == "ShowDebugCounters":
		visible = value
