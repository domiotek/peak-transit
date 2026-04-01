class_name RLEnums

enum AgentMode {
	TRAIN,
	INFERENCE,
}

enum BusType {
	REGULAR,
	ARTICULATED,
}

enum BusState {
	AT_DEPOT,
	TRANSFER,
	EN_ROUTE,
	WAITING_FOR_TRIP,
	IN_RESERVE,
}

enum ActionType {
	NO_OP,
	SET_STATE,
	ASSIGN_TO_BRIGADE,
}

enum BusStateRequest {
	DEPOT,
	RESERVE,
}


static func get_action_type_name(action_type: ActionType) -> String:
	match action_type:
		ActionType.NO_OP:
			return "No-op"
		ActionType.SET_STATE:
			return "Set state"
		ActionType.ASSIGN_TO_BRIGADE:
			return "Assign to brigade"

	return "Unknown action"


static func get_bus_state_request_name(state: BusStateRequest) -> String:
	match state:
		BusStateRequest.DEPOT:
			return "Depot"
		BusStateRequest.RESERVE:
			return "Reserve"

	return "Unknown request"

static func parse_agent_mode(mode_str: String) -> AgentMode:
	match mode_str.to_lower():
		"train":
			return AgentMode.TRAIN
		"inference":
			return AgentMode.INFERENCE

	return AgentMode.TRAIN
