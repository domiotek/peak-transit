class_name TerminalTrackState

static var navigate_to_peron_map = {
	"in": "in_line",
	"bypass": "bypass_around",
	"bypass_around": "in_line",
}

static var leave_terminal_map = {
	"in": "in_line",
	"in_line": "bypass",
	"bypass": "bypass_out",
	"bypass_around": "in_line",
}

static var wait_at_terminal_map = {
	"in": "in_wait",
	"in_line": "bypass",
	"bypass": "bypass_around",
	"bypass_around": "in_wait",
}

enum TrackSearchError {
	VEH_NOT_REGISTERED,
	NO_FREE_WAIT_TRACK,
	ALREADY_ON_TARGET,
	TRACK_IN_USE,
	INVALID_POSITION,
}
