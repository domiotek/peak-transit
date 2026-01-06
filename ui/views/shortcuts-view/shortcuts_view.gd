extends GridContainer

class_name ShortcutsView

const VIEW_NAME = "ShortcutsView"
const SHORTCUTS_VIEW_GROUP = "shortcuts"

var ui_manager: UIManager
var game_manager: GameManager

@onready var toggle_lines_view_button: Button = $ToggleLinesViewButton
@onready var toggle_brigades_view_button: Button = $ToggleBrigadesViewButton
@onready var toggle_buses_view_button: Button = $ToggleBusesViewButton


func _ready() -> void:
	ui_manager = GDInjector.inject("UIManager") as UIManager

	visible = false
	ui_manager.register_ui_view(VIEW_NAME, self)

	toggle_lines_view_button.pressed.connect(Callable(self, "_on_toggle_lines_view_button_pressed"))
	toggle_brigades_view_button.pressed.connect(Callable(self, "_on_toggle_brigades_view_button_pressed"))
	toggle_buses_view_button.pressed.connect(Callable(self, "_on_toggle_buses_view_button_pressed"))


func _on_toggle_lines_view_button_pressed() -> void:
	ui_manager.toggle_ui_view_exclusively(SHORTCUTS_VIEW_GROUP, LinesView.VIEW_NAME)


func _on_toggle_brigades_view_button_pressed() -> void:
	ui_manager.toggle_ui_view_exclusively(SHORTCUTS_VIEW_GROUP, BrigadesView.VIEW_NAME)


func _on_toggle_buses_view_button_pressed() -> void:
	ui_manager.toggle_ui_view_exclusively(SHORTCUTS_VIEW_GROUP, BusesView.VIEW_NAME)
