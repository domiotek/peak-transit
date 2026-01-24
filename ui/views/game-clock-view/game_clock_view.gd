extends Control

class_name GameClockView

var ui_manager: UIManager
var game_manager: GameManager
var simulation_manager: SimulationManager

static var VIEW_NAME = "GameClockView"

@onready var sim_state_icon: TextureRect = $BoxContainer/SimStateIcon
@onready var animation_player: AnimationPlayer = $BoxContainer/SimStateIcon/AnimationPlayer
@onready var label: Label = $BoxContainer/Label

var last_tick_msec = 0.0


func _ready() -> void:
	ui_manager = GDInjector.inject("UIManager") as UIManager
	game_manager = GDInjector.inject("GameManager") as GameManager
	simulation_manager = GDInjector.inject("SimulationManager") as SimulationManager

	ui_manager.register_ui_view(VIEW_NAME, self)

	game_manager.game_speed_changed.connect(Callable(self, "_on_game_speed_changed"))
	game_manager.clock.time_changed.connect(Callable(self, "_on_time_changed"))

	_on_game_speed_changed(game_manager.get_game_speed())
	_on_time_changed(game_manager.clock.get_time())
	last_tick_msec = Time.get_ticks_msec()


func _exit_tree() -> void:
	ui_manager.unregister_ui_view(VIEW_NAME)


func _process(_delta):
	var current_time = Time.get_ticks_msec()
	var elapsed = (current_time - last_tick_msec) / 1000.0
	last_tick_msec = current_time

	if animation_player.is_playing():
		animation_player.advance(elapsed * animation_player.speed_scale)


func _on_game_speed_changed(new_speed: Enums.GameSpeed) -> void:
	match new_speed:
		Enums.GameSpeed.PAUSE:
			sim_state_icon.texture = preload("res://assets/ui_icons/speed_control/pause.png")
			animation_player.play("pulse")
		Enums.GameSpeed.LOW, Enums.GameSpeed.MEDIUM, Enums.GameSpeed.HIGH, Enums.GameSpeed.TURBO:
			sim_state_icon.texture = preload("res://assets/ui_icons/play.png")
			animation_player.stop()


func _on_time_changed(new_time: ClockTime) -> void:
	label.text = new_time.get_formatted()
