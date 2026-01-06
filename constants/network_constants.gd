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
const MIN_TERMINAL_BUILDING_CLEARANCE = 64.0 # minimum distance in pixels between a terminal and a building on the same segment
const MIN_DEPOT_BUILDING_CLEARANCE = 96.0 # minimum distance in pixels between a depot and a building on the same segment
const MIN_SEGMENT_LENGTH_FOR_ROAD_MARKINGS = 120.0 # minimum segment length in pixels to show road markings

const PATH_DIRECTION_INDICATORS_OFFSET = 50.0 # offset in pixels for direction indicators along the path
const PATH_DIRECTION_INDICATORS_SIZE = 8.0 # size in pixels for direction indicator triangles

# duration in seconds for long traffic light phases
const TRAFFIC_LIGHTS_LONG_PHASE_DURATION = (90.0 / SimulationConstants.SIMULATION_REAL_SECONDS_PER_IN_GAME_MINUTE)
# duration in seconds for short traffic light phases
const TRAFFIC_LIGHTS_SHORT_PHASE_DURATION = (60.0 / SimulationConstants.SIMULATION_REAL_SECONDS_PER_IN_GAME_MINUTE)

const TRAFFIC_LIGHTS_MIN_PHASE_DURATION_SCALER = 0.3 # scaler to determine minimum phase duration based on traffic flow
const TRAFFIC_LIGHTS_LOW_FLOW_THRESHOLD = 10 # vehicle count threshold to consider traffic flow as low
const TRAFFIC_LIGHTS_FLOW_SCAN_DISTANCE = 250.0 # distance in pixels to scan for traffic flow
