extends Vehicle

class_name Bus

@onready var path_follower: PathFollow2D = $PathFollower
@onready var body_area = $BodyArea
@onready var collision_area = $CollisionArea
@onready var forward_blockage_area = $ForwardBlockadeObserver


func _get_vehicle_config() -> Variant:
	var _config = VehicleConfig.new()

	_config.ai = BusAI.new()
	_config.category = VehicleManager.VehicleCategory.PUBLIC_TRANSPORT
	_config.blockade_observer = forward_blockage_area
	_config.head_lights = [$Body/Lights/LeftBeam, $Body/Lights/RightBeam] as Array[Headlight]
	_config.brake_lights = [$Body/Lights/LeftBrakeLight, $Body/Lights/RightBrakeLight] as Array[Light]
	_config.casters = CasterCollection.new(
		$CloseRayCaster,
		$MediumRayCaster,
		$LongRayCaster,
		$LeftRayCaster,
		$RightRayCaster,
	)
	_config.caster_indicators = CasterCollection.CasterIndicatorCollection.new(
		$Body/CloseRayIndicator,
		$Body/MediumRayIndicator,
		$Body/LongRayIndicator,
		$Body/LeftRayIndicator,
		$Body/RightRayIndicator,
	)
	_config.id_label = $Body/Label
	_config.path_follower = path_follower
	_config.body_areas = [body_area] as Array[Area2D]
	_config.collision_areas = [collision_area] as Array[Area2D]
	_config.blockade_indicator = $Body/Line2D
	_config.body_segments = [$Body] as Array[Polygon2D]
	_config.visibility_notifier = $VisibilityNotifier

	return _config
