extends BoxContainer

class_name ObjectConfigurationPanel

@onready var expand_button: Button = $MarginContainer/ExpandButton
@onready var world_config_panel: MarginContainer = $MainPanel/MarginContainer/BoxContainer/PanelContainer/ScrollContainer/WorldConfigPanel

const VIEW_NAME := "ObjectConfigurationPanel"

const X_POS_DIFF: float = 326.0

var _is_expanded: bool

@onready var ui_manager: UIManager = GDInjector.inject("UIManager") as UIManager


func _ready() -> void:
	visible = false
	ui_manager.register_ui_view(VIEW_NAME, self)
	expand_button.pressed.connect(_on_expand_button_pressed)
	_is_expanded = false


func _exit_tree() -> void:
	ui_manager.unregister_ui_view(VIEW_NAME)


func _on_expand_button_pressed() -> void:
	_is_expanded = !_is_expanded

	if _is_expanded:
		self.position.x -= X_POS_DIFF
		world_config_panel.setup()
	else:
		self.position.x += X_POS_DIFF
