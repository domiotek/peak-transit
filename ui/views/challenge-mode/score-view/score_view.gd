extends Control

class_name RLScoreView

const VIEW_NAME = "RLScoreView"

var ScoreListItemScene = preload("res://ui/components/challenge-mode/score-list-item/score_list_item.tscn")

enum Tab {
	STEP,
	EPISODE,
	OVERALL,
}

@onready var _ui_manager: UIManager = GDInjector.inject("UIManager") as UIManager
@onready var _game_manager: GameManager = GDInjector.inject("GameManager")

@onready var collapse_button: Button = $MarginContainer/BoxContainer/CollapseButton

@onready var step_tab: BoxContainer = $"MarginContainer/BoxContainer/TabContainer/Last Step"
@onready var step_score_container: BoxContainer = $"MarginContainer/BoxContainer/TabContainer/Last Step/ScrollContainer/MarginContainer/BoxContainer"
@onready var episode_tab: BoxContainer = $MarginContainer/BoxContainer/TabContainer/Episode
@onready var episode_score_container: BoxContainer = $MarginContainer/BoxContainer/TabContainer/Episode/ScrollContainer/MarginContainer/BoxContainer
@onready var overall_tab: BoxContainer = $MarginContainer/BoxContainer/TabContainer/Overall
@onready var overall_score_container: BoxContainer = $"MarginContainer/BoxContainer/TabContainer/Overall/ScrollContainer/MarginContainer/BoxContainer"

var _score_manager: ScoreManager

var _last_step_score: float = 0
var _last_score_reasons: Array = []


func _ready() -> void:
	visible = false
	_ui_manager.register_ui_view(VIEW_NAME, self)

	collapse_button.pressed.connect(_on_collapse_button_pressed)
	_game_manager.rl_mode_toggled.connect(_on_rl_mode_toggled)


func _exit_tree() -> void:
	_ui_manager.unregister_ui_view(VIEW_NAME)
	_game_manager.rl_mode_toggled.disconnect(_on_rl_mode_toggled)


func update(data: Dictionary) -> void:
	var tab = data.get("tab", Tab.STEP)

	match tab:
		Tab.STEP:
			step_tab.visible = true
		Tab.EPISODE:
			episode_tab.visible = true
		Tab.OVERALL:
			overall_tab.visible = true


func _on_rl_mode_toggled(_enabled: bool) -> void:
	_score_manager = _game_manager.get_game_controller().score_manager()
	_score_manager.score_reset.connect(_on_step_score_reset)
	_score_manager.episode_ended.connect(_on_epoch_ended)


func _on_collapse_button_pressed() -> void:
	_ui_manager.hide_ui_view(VIEW_NAME)


func _on_step_score_reset(score: float, reasons: Array) -> void:
	_last_step_score = score
	_last_score_reasons = _group_score_reasons_by_type(reasons)
	_update_details(Tab.STEP)
	_update_details(Tab.EPISODE)


func _on_epoch_ended(_epoch_score: float) -> void:
	_update_details(Tab.OVERALL)


func _update_details(target_tab: Tab) -> void:
	match target_tab:
		Tab.STEP:
			var reasons = _last_score_reasons
			_clear_container(step_score_container)

			for reason_idx in range(reasons.size()):
				var reason = reasons[reason_idx]
				var list_item = ScoreListItemScene.instantiate()
				var reason_name = ChallengeEnums.get_score_reason_name(reason["reason"])
				var score_text = reason_name + " (x" + str(reason["stack"]) + ")" if reason["stack"] > 1 else reason_name

				list_item.init_item(score_text)
				list_item.set_score(reason["total_delta"])

				step_score_container.add_child(list_item)
		Tab.EPISODE:
			var score_history = _score_manager.get_score_history()
			_clear_container(episode_score_container)

			for score in score_history:
				var list_item = ScoreListItemScene.instantiate()
				var action = score.get("action", null)
				var action_text = "Waiting for an action..."
				if action != null:
					action_text = _format_action_text(action)
				list_item.init_item(score["timestamp"], action_text)
				list_item.set_score(score["score"])

				episode_score_container.add_child(list_item)
		Tab.OVERALL:
			var episode_history = _score_manager.get_episode_history()
			_clear_container(overall_score_container)

			for episode in episode_history:
				var list_item = ScoreListItemScene.instantiate()
				list_item.init_item(episode["timestamp"])
				list_item.set_score(episode["score"])

				overall_score_container.add_child(list_item)


func _clear_container(container: BoxContainer) -> void:
	for child in container.get_children():
		child.queue_free()


func _group_score_reasons_by_type(score_reasons: Array) -> Array:
	var grouped_reasons: Dictionary = { }

	for reason in score_reasons:
		if not grouped_reasons.has(reason["reason"]):
			grouped_reasons[reason["reason"]] = {
				"reason": reason["reason"],
				"total_delta": 0,
				"stack": 0,
			}

		grouped_reasons[reason["reason"]]["total_delta"] += reason["total_delta"]
		grouped_reasons[reason["reason"]]["stack"] += reason["stack"]

	return grouped_reasons.values()


func _format_action_text(action: Dictionary) -> String:
	if action == null:
		return "No action yet"

	var action_name = RLEnums.ActionType.keys()[action["command"]]

	match action["command"] as int:
		RLEnums.ActionType.NO_OP:
			return "[%s]" % action_name
		RLEnums.ActionType.SET_STATE:
			return "[%s] Bus %d; State %s; Terminal %d" % [
				action_name,
				action["bus_idx"],
				RLEnums.get_bus_state_request_name(action["state"]),
				action["reserve_term_idx"],
			]
		RLEnums.ActionType.ASSIGN_TO_BRIGADE:
			return "[%s] Bus %d; Brigade: %d" % [
				action_name,
				action["bus_idx"],
				action["brigade_idx"],
			]

	return "[%s] Bus %d; State %s; Brigade: %d; Terminal %d" % [
		RLEnums.ActionType.keys()[action["command"]],
		action["bus_idx"],
		RLEnums.get_bus_state_request_name(action["state"]),
		action["brigade_idx"],
		action["reserve_term_idx"],
	]
