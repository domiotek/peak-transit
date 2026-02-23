extends Control

class_name RLScoreOverview

const VIEW_NAME = "RLScoreOverview"

@onready var _ui_manager: UIManager = GDInjector.inject("UIManager") as UIManager
@onready var _game_manager: GameManager = GDInjector.inject("GameManager")

@onready var overall_score_overview: BoxContainer = $MarginContainer/BoxContainer/Overall
@onready var episode_score_overview: BoxContainer = $MarginContainer/BoxContainer/CurrentEpisode
@onready var step_score_overview: BoxContainer = $MarginContainer/BoxContainer/CurrentStep

@onready var overall_score: Label = $MarginContainer/BoxContainer/Overall/BoxContainer/OverallScore
@onready var episode_score: Label = $MarginContainer/BoxContainer/CurrentEpisode/BoxContainer/EpisodeScore
@onready var step_score: Label = $MarginContainer/BoxContainer/CurrentStep/BoxContainer/StepScore

var _score_manager: ScoreManager


func _ready() -> void:
	visible = false
	_ui_manager.register_ui_view(VIEW_NAME, self)

	_game_manager.rl_mode_toggled.connect(_on_rl_mode_toggled)


func _exit_tree() -> void:
	_ui_manager.unregister_ui_view(VIEW_NAME)
	_game_manager.rl_mode_toggled.disconnect(_on_rl_mode_toggled)


func _on_rl_mode_toggled(enabled: bool) -> void:
	if enabled:
		_ui_manager.show_ui_view(VIEW_NAME)
	else:
		_ui_manager.hide_ui_view(VIEW_NAME)
	_score_manager = _game_manager.get_game_controller().score_manager()


func _process(_delta: float) -> void:
	if _score_manager == null:
		return

	_update_score()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var mouse_pos = get_global_mouse_position()

		if overall_score_overview.get_global_rect().has_point(mouse_pos):
			_ui_manager.show_ui_view(RLScoreView.VIEW_NAME, { "tab": RLScoreView.Tab.OVERALL })
		elif episode_score_overview.get_global_rect().has_point(mouse_pos):
			_ui_manager.show_ui_view(RLScoreView.VIEW_NAME, { "tab": RLScoreView.Tab.EPISODE })
		elif step_score_overview.get_global_rect().has_point(mouse_pos):
			_ui_manager.show_ui_view(RLScoreView.VIEW_NAME, { "tab": RLScoreView.Tab.STEP })


func _update_score() -> void:
	step_score.text = "%0.2f" % _score_manager.get_score()
	episode_score.text = "%0.2f" % _score_manager.get_cumulative_score()
	var last_episode_score = _score_manager.get_last_episode_score()
	overall_score.text = "%0.2f" % last_episode_score if last_episode_score != -INF else "0.00"
