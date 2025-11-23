extends GridContainer

class_name ShortcutsView

const VIEW_NAME = "ShortcutsView"

var ui_manager: UIManager
var game_manager: GameManager

@onready var toggle_lines_view_button: Button = $ToggleLinesViewButton


func _ready() -> void:
	ui_manager = GDInjector.inject("UIManager") as UIManager

	visible = false
	ui_manager.register_ui_view(VIEW_NAME, self)

	toggle_lines_view_button.pressed.connect(Callable(self, "_on_toggle_lines_view_button_pressed"))


func _on_toggle_lines_view_button_pressed() -> void:
	ui_manager.toggle_ui_view(LinesView.VIEW_NAME)
