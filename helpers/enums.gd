class_name Enums

enum GameSpeed {
	PAUSE = 0,
	LOW = 1,
	MEDIUM = 2,
	HIGH = 3,
	TURBO = 4
}

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

enum TrafficLightState {
	RED,
	GREEN,
	INITIAL
}