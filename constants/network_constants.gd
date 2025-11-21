extends RefCounted

class_name NetworkConstants

const LANE_WIDTH = 32.0
const LINE_WIDTH = 2.0
const LINE_COLOR = Color.WHITE

const DASH_LENGTH = 10.0
const DASH_GAP_LENGTH = 10.0
const DASH_COLOR = Color.DARK_GRAY

const DIRECTION_MARKER_OFFSET = 32.0
const SUPPORT_DIRECTION_MARKER_OFFSET = 64.0
const DIRECTION_LABEL_OFFSET = 25.0
const SUPPORT_MARKER_TINT = Color(1, 0.8, 0.28, 1)

const SHARP_LANE_CONNECTION_THRESHOLD = 30 # distance in pixels between lane endpoints to consider a connection "sharp"
const LANE_CONNECTION_BASE_CURVATURE_FACTOR = 1.0
const LANE_CONNECTION_MAX_CURVATURE_FACTOR = 2.5
const LANE_CONNECTION_DISTANCE_THRESHOLD = 200.0 # distance in pixels at which max curvature

const MIN_STOP_DISTANCE = 64.0 # minimum distance in pixels between stops on the same segment
const MIN_STOP_BUILDING_CLEARANCE = 24.0 # minimum distance in pixels between a stop and a building on the same segment
