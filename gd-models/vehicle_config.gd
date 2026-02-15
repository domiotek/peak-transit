class_name VehicleConfig

var ai
var category: VehicleManager.VehicleCategory
var blockade_observer: Area2D
var head_lights: Array[Headlight]
var brake_lights: Array[Node2D]
var left_blinker_nodes: Array[Node2D]
var right_blinker_nodes: Array[Node2D]
var casters: CasterCollection
var caster_indicators: CasterCollection.CasterIndicatorCollection
var id_label: Label
var path_follower: PathFollow2D
var trailers: Array[Dictionary] = []
var body_areas: Array[Area2D]
var collision_areas: Array[Area2D]
var blockade_indicator: Line2D
var body_segments: Array[Polygon2D]
var body_color: Color
