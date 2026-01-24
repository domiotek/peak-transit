extends RefCounted

class_name BuildingConstants

const BUILDING_ROAD_OFFSET = 20.0
const BUILDING_CONNECTION_OFFSET = 30.0
const BUILDING_CONNECTION_CURVATURE = 0.65

const BUILDING_SOFT_ENTRY_BLOCKADE_TIME = 5.0 # seconds
const BUILDING_SYMPATHY_WITHOUT_BENEFIT_TIMEOUT = 10.0 # seconds
const BUILDING_MAX_ENTERING_VEHICLE_BLOCKADE_TIME = 50.0 # seconds
const BUILDING_VEHICLE_LEFT_PREMISE_PROGRESS_THRESHOLD = 10.0 # percent
const BUILDING_MAX_LEAVING_VEHICLE_BLOCKADE_TIME = 20.0 # seconds

# gdlint-ignore-next-line variable-name
static var TERMINAL_VISUAL_POLYGON = PackedVector2Array(
	[
		Vector2(-146.000, -297.999),
		Vector2(-129.000, -308.000),
		Vector2(-112.000, -316.000),
		Vector2(-86.000, -322.001),
		Vector2(-59.000, -324.001),
		Vector2(192.000, -297.999),
		Vector2(207.000, -293.000),
		Vector2(217.000, -287.000),
		Vector2(225.000, -278.999),
		Vector2(230.000, -270.000),
		Vector2(234.000, -259.999),
		Vector2(233.000, -246.000),
		Vector2(230.000, -235.000),
		Vector2(225.000, -219.000),
		Vector2(218.000, -201.000),
		Vector2(205.000, -178.000),
		Vector2(139.000, -92.000),
		Vector2(126.000, -83.000),
		Vector2(115.000, -75.000),
		Vector2(105.000, -67.000),
		Vector2(96.000, -62.000),
		Vector2(85.000, -56.000),
		Vector2(57.000, -45.000),
		Vector2(49.000, -39.000),
		Vector2(41.000, -32.000),
		Vector2(22.000, 1.000),
		Vector2(-19.000, 1.000),
		Vector2(-34.000, -15.000),
		Vector2(-45.000, -23.000),
		Vector2(-91.000, -27.000),
		Vector2(-140.000, -32.000),
		Vector2(-168.000, -42.000),
		Vector2(-184.000, -52.000),
		Vector2(-203.000, -67.000),
		Vector2(-207.000, -76.000),
		Vector2(-209.000, -88.000),
		Vector2(-209.000, -109.000),
		Vector2(-205.000, -141.000),
		Vector2(-197.000, -172.000),
		Vector2(-191.000, -194.000),
		Vector2(-181.000, -231.000),
		Vector2(-174.000, -249.000),
		Vector2(-167.000, -265.001),
		Vector2(-157.000, -280.999),
	],
)

# gdlint-ignore-next-line variable-name
static var TERMINAL_COLLISION_POLYGON = PolygonHelper.get_bounding_box(TERMINAL_VISUAL_POLYGON, 5.0)

# gdlint-ignore-next-line variable-name
static var STOP_VISUAL_POLYGON = PackedVector2Array(
	[
		Vector2(-9, -27),
		Vector2(9, -27),
		Vector2(9, 4),
		Vector2(68, 4),
		Vector2(68, 29),
		Vector2(-68, 29),
		Vector2(-68, 4),
		Vector2(-9, 4),
	],
)

# gdlint-ignore-next-line variable-name
static var STOP_COLLISION_POLYGON = PolygonHelper.get_bounding_box(STOP_VISUAL_POLYGON, 5.0)

# gdlint-ignore-next-line variable-name
static var DEPOT_COLLISION_POLYGON = PackedVector2Array(
	[
		Vector2(-172.0001, -188.0000),
		Vector2(169.0001, -189.0002),
		Vector2(169.0001, 0.0000),
		Vector2(4.4035, 0.2318),
		Vector2(-171.0000, 0.0000),
	],
)

# gdlint-ignore-next-line variable-name
static var SPAWNER_BUILDING_COLLISION_POLYGON = PackedVector2Array(
	[
		Vector2(-25, -50),
		Vector2(26, -50),
		Vector2(26, -16),
		Vector2(-25, -16),
	],
)
