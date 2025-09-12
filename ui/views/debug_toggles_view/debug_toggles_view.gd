extends Control


var ui_manager: UIManager
var config_manager: ConfigManager

@onready var item_list_holder = $MainWrapper/MaxSizeContainer/ScrollContainer/MarginContainer/ItemList


func _ready() -> void:
	ui_manager = GDInjector.inject("UIManager") as UIManager
	config_manager = GDInjector.inject("ConfigManager") as ConfigManager

	ui_manager.register_ui_view("DebugTogglesView", self)
	visible = false

	$MainWrapper/HeaderMargins/HeaderFlex/CloseButton.pressed.connect(_on_close_button_pressed)


func init() -> void:
	var debug_toggles = config_manager.DebugToggles.ToDictionary()

	for toggle_name in debug_toggles.keys():
		var scene = load("res://ui/components/debug_toggle_component/debug_toggle_component.tscn")
		var instance = scene.instantiate()

		instance.setup(toggle_name, debug_toggles[toggle_name])

		instance.connect("toggled", Callable(self, "_on_toggle_toggled"))

		item_list_holder.add_child(instance)
		


func _on_close_button_pressed() -> void:
	ui_manager.hide_ui_view("DebugTogglesView")

func _on_toggle_toggled(id: String, state: bool) -> void:
	config_manager.DebugToggles.SetToggle(id, state)
