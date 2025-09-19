class_name Enums

enum IntersectionType {
	Default,
	TrafficLights,
}

enum Direction {
	RIGHT,
	FORWARD,
	RIGHT_FORWARD,
	LEFT,
	LEFT_RIGHT,
	LEFT_FORWARD,
	ALL_DIRECTIONS,
	BACKWARD,
}

enum PathConflictType {
	NONE,
	LINE_CROSSING,
	SAME_ENDPOINT,
}

enum IntersectionPriority {
	YIELD,
	STOP,
	PRIORITY
}