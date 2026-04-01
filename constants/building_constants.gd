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
static var TERMINAL_VISUAL_POLYGON = PackedVector2Array([
	Vector2(-146, -297.999),
	Vector2(-129, -308),
	Vector2(-112, -316),
	Vector2(-86, -322.001),
	Vector2(-59, -324.001),
	Vector2(192, -297.999),
	Vector2(207, -293),
	Vector2(217, -287),
	Vector2(225, -282),
	Vector2(233, -275),
	Vector2(239, -267),
	Vector2(241, -253),
	Vector2(241, -240),
	Vector2(241, -224),
	Vector2(241, -201),
	Vector2(238, -182),
	Vector2(234, -163),
	Vector2(227, -140),
	Vector2(219, -127),
	Vector2(210, -117),
	Vector2(171, -87),
	Vector2(148, -73),
	Vector2(127, -66),
	Vector2(103, -57),
	Vector2(85, -53),
	Vector2(57, -45),
	Vector2(49, -39),
	Vector2(41, -32),
	Vector2(22, 1),
	Vector2(-19, 1),
	Vector2(-34, -15),
	Vector2(-45, -23),
	Vector2(-91, -27),
	Vector2(-140, -32),
	Vector2(-168, -42),
	Vector2(-184, -52),
	Vector2(-203, -67),
	Vector2(-207, -76),
	Vector2(-209, -88),
	Vector2(-209, -109),
	Vector2(-205, -141),
	Vector2(-197, -172),
	Vector2(-191, -194),
	Vector2(-181, -231),
	Vector2(-174, -249),
	Vector2(-167, -265.001),
	Vector2(-157, -280.999)
])


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
		Vector2(-75, -118),
		Vector2(78, -118),
		Vector2(78, -16),
		Vector2(-75, -16),
	],
)
