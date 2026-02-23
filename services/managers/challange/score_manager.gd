class_name ScoreManager

var _score: float = 0
var _cumulative_score: float = 0
var _episode_score: float = -INF

var _score_reasons: Array = []
var _score_history: Array = []
var _episode_history: Array = []

var _game_manager: GameManager

signal score_updated(new_score: float, reason: ChallengeEnums.ScoreReason)
signal score_reset(score: float, reasons: Array)
signal episode_ended(episode_score: float)


func _init() -> void:
	_game_manager = GDInjector.inject("GameManager") as GameManager


func get_score() -> float:
	return _score


func get_cumulative_score() -> float:
	return _cumulative_score


func get_last_episode_score() -> float:
	return _episode_score


func get_score_reasons() -> Array:
	return _score_reasons


func get_score_history() -> Array:
	return _score_history


func get_episode_history() -> Array:
	return _episode_history


func update_score(score_reason: ChallengeEnums.ScoreReason, stack: int = 1) -> void:
	var score_delta = _get_score_delta(score_reason)

	if stack < 1:
		stack = 1

	var delta = score_delta * stack
	_score += delta

	var current_time = _game_manager.clock.get_time().to_time_of_day()

	_score_reasons.append(
		{
			"delta": score_delta,
			"reason": score_reason,
			"stack": stack,
			"total_delta": delta,
			"timestamp": current_time.format(),
		},
	)

	emit_signal("score_updated", _score, score_reason)


func push_action(action: Dictionary) -> void:
	var last_score_history_entry = _score_history[_score_history.size() - 1] if _score_history.size() > 0 else null

	if last_score_history_entry != null:
		last_score_history_entry["action"] = action
	else:
		print("Warning: pushing action to score manager but no score history entry exists yet.")


func end_episode() -> void:
	_episode_score = _cumulative_score

	_episode_history.append(
		{
			"score": _cumulative_score,
			"timestamp": _game_manager.clock.get_time().get_formatted(),
		},
	)

	emit_signal("episode_ended", _cumulative_score)

	_score = 0
	_cumulative_score = 0
	_score_reasons.clear()
	_score_history.clear()


func reset_score() -> void:
	_score_history.append(
		{
			"score": _score,
			"timestamp": _game_manager.clock.get_time().to_time_of_day().format(),
		},
	)
	_cumulative_score += _score
	emit_signal("score_reset", _score, _score_reasons.duplicate())
	_score = 0
	_score_reasons.clear()


func reset_cumulative_score() -> void:
	_cumulative_score = 0
	_score_history.clear()


func hard_reset() -> void:
	_score = 0
	_cumulative_score = 0
	_episode_score = -INF
	_score_reasons.clear()
	_score_history.clear()
	_episode_history.clear()


func _get_score_delta(score_reason: ChallengeEnums.ScoreReason) -> float:
	match score_reason:
		ChallengeEnums.ScoreReason.BUS_INVALID_STATE_FOR_ACTION:
			return -0.1
		ChallengeEnums.ScoreReason.BUS_ALREADY_IN_RESERVE_SAME_TERMINAL:
			return -0.05
		ChallengeEnums.ScoreReason.BUS_CHANGED_STATE_WITH_PASSENGERS_ONBOARD:
			return -1.0
		ChallengeEnums.ScoreReason.BUS_REGULAR_UPKEEP_COST:
			return -0.01
		ChallengeEnums.ScoreReason.BUS_ARTICULATED_UPKEEP_COST:
			return -0.02
		ChallengeEnums.ScoreReason.UNSERVED_BRIGADE:
			return -0.3
		ChallengeEnums.ScoreReason.BORED_PASSENGER:
			return -0.005
		ChallengeEnums.ScoreReason.SERVICED_PASSENGER:
			return 0.005
		ChallengeEnums.ScoreReason.SERVICED_STOP_AHEAD_OF_TIME:
			return 0.3
		ChallengeEnums.ScoreReason.SERVICED_STOP_ON_TIME:
			return 0.5
		ChallengeEnums.ScoreReason.SERVICED_STOP_SLIGHTLY_LATE:
			return 0.3
		ChallengeEnums.ScoreReason.SERVICED_STOP_LATE:
			return 0.2
		ChallengeEnums.ScoreReason.SERVICED_STOP_VERY_LATE:
			return 0.1
		ChallengeEnums.ScoreReason.LEFT_PASSENGERS_BEHIND:
			return -0.1
		_:
			push_warning("Score reason %s not handled in score manager." % str(score_reason))
			return 0.0
