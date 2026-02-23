class_name ChallengeEnums

enum ScoreReason {
	BUS_INVALID_STATE_FOR_ACTION,
	BUS_ALREADY_IN_RESERVE_SAME_TERMINAL,
	BUS_CHANGED_STATE_WITH_PASSENGERS_ONBOARD,
	BUS_REGULAR_UPKEEP_COST,
	BUS_ARTICULATED_UPKEEP_COST,
	UNSERVED_BRIGADE,
	BORED_PASSENGER,
	SERVICED_PASSENGER,
	SERVICED_STOP_AHEAD_OF_TIME,
	SERVICED_STOP_ON_TIME,
	SERVICED_STOP_SLIGHTLY_LATE,
	SERVICED_STOP_LATE,
	SERVICED_STOP_VERY_LATE,
	LEFT_PASSENGERS_BEHIND,
}


static func get_score_reason_name(reason: ScoreReason) -> String:
	match reason:
		ScoreReason.BUS_INVALID_STATE_FOR_ACTION:
			return "Bus in invalid state for action"
		ScoreReason.BUS_ALREADY_IN_RESERVE_SAME_TERMINAL:
			return "Bus already in reserve at the same terminal"
		ScoreReason.BUS_CHANGED_STATE_WITH_PASSENGERS_ONBOARD:
			return "Bus changed state with passengers onboard"
		ScoreReason.BUS_REGULAR_UPKEEP_COST:
			return "Regular bus upkeep cost"
		ScoreReason.BUS_ARTICULATED_UPKEEP_COST:
			return "Articulated bus upkeep cost"
		ScoreReason.UNSERVED_BRIGADE:
			return "Unserved brigade"
		ScoreReason.BORED_PASSENGER:
			return "Bored passenger"
		ScoreReason.SERVICED_PASSENGER:
			return "Serviced passenger"
		ScoreReason.SERVICED_STOP_AHEAD_OF_TIME:
			return "Serviced stop ahead of time"
		ScoreReason.SERVICED_STOP_ON_TIME:
			return "Serviced stop on time"
		ScoreReason.SERVICED_STOP_SLIGHTLY_LATE:
			return "Serviced stop slightly late"
		ScoreReason.SERVICED_STOP_LATE:
			return "Serviced stop late"
		ScoreReason.SERVICED_STOP_VERY_LATE:
			return "Serviced stop very late"
		ScoreReason.LEFT_PASSENGERS_BEHIND:
			return "Left passengers behind"

	return "Unknown reason"


enum ArrivalTimeThreshold {
	SLIGHTLY_LATE = 0,
	LATE = 5,
	VERY_LATE = 10,
}
