extends Node


var LANE_WIDTH = 32.0
var LINE_WIDTH = 2.0
var LINE_COLOR = Color.WHITE

var DASH_LENGTH = 10.0
var DASH_GAP_LENGTH = 10.0
var DASH_COLOR = Color.DARK_GRAY

var DIRECTION_MARKER_OFFSET = 32.0

var SHARP_LANE_CONNECTION_THRESHOLD = 30 # distance in pixels between lane endpoints to consider a connection "sharp"
var LANE_CONNECTION_BASE_CURVATURE_FACTOR = 1.0
var LANE_CONNECTION_MAX_CURVATURE_FACTOR = 2.5
var LANE_CONNECTION_DISTANCE_THRESHOLD = 200.0 # distance in pixels at which max curvature
