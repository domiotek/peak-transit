class_name TransportConstants

const BUS_OCCUPY_PERON_THRESHOLD = 3 # in-game minutes
const BUS_BOARDING_TIME_PER_PASSENGER = 0.01 # real seconds
const BUS_MAX_BOARDING_TIME = SimulationConstants.SIMULATION_REAL_SECONDS_PER_IN_GAME_MINUTE * 1.0 # 1 in-game minute
const BUS_MAX_STOP_SYNCING_TIME = SimulationConstants.SIMULATION_REAL_SECONDS_PER_IN_GAME_MINUTE * 2.0 # 2 in-game minutes
const CAR_COLORS = [
	Color(0.8, 0.1, 0.1), # red
	Color(0.349, 0.502, 0.31), # green
	Color(0.0, 0.329, 0.639), # blue
	Color(0.906, 0.871, 0.271), # yellow
	Color(0.882, 0.514, 0.216), # orange
	Color(0.961, 0.878, 0.757), # beige
	Color(0.5, 0.5, 0.5), # gray
]
const BUS_DEFAULT_COLOR = Color(0.105, 0.514, 0.833)
const PASSENGER_SPAWN_INTERVAL_DELTA = 5.0 # (in-game delta) seconds
const PASSENGER_SPAWN_CHANCE_BASE = 80.0 # percentage
const PASSENGER_BEFORE_BUS_ARRIVAL_TIME = 15 # (in-game) minutes
const PASSENGER_BASE_BORE_TIME = 15.0 # (in-game) minutes
const MAX_PASSENGER_AT_STOP = 200
const MAX_PASSENGER_AT_TERMINAL_PERON = 500
const BUS_MAX_CAPACITY = 96
const ARTICULATED_BUS_MAX_CAPACITY = 169

const DEFAULT_DEPOT_ARTICULATED_BUS_CAPACITY = 4
const DEFAULT_DEPOT_STANDARD_BUS_CAPACITY = 8
