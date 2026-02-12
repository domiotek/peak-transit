class_name RLEnums

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
