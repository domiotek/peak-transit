extends Vehicle

class_name Car

@onready var body_area = $BodyArea
@onready var collision_area = $CollisionArea
@onready var forward_blockage_area = $ForwardBlockadeObserver


func _get_vehicle_config() -> Variant:
	var _config = VehicleConfig.new()

	_config.ai = CarAI.new()
	_config.category = VehicleManager.VehicleCategory.PRIVATE
	_config.blockade_observer = forward_blockage_area
	_config.head_lights = [$Body/Lights/LeftBeam, $Body/Lights/RightBeam] as Array[Headlight]
	_config.brake_lights = [$Body/Lights/LeftBrakeLight, $Body/Lights/RightBrakeLight] as Array[Node2D]
	_config.left_blinker_nodes = [$Body/Lights/Blinkers/LeftFront, $Body/Lights/Blinkers/LeftSide, $Body/Lights/Blinkers/LeftRear] as Array[Node2D]
	_config.right_blinker_nodes = [$Body/Lights/Blinkers/RightFront, $Body/Lights/Blinkers/RightSide, $Body/Lights/Blinkers/RightRear] as Array[Node2D]
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
	_config.path_follower = $PathFollower
	_config.body_areas = [body_area] as Array[Area2D]
	_config.collision_areas = [collision_area] as Array[Area2D]
	_config.blockade_indicator = $Body/Line2D
	_config.body_segments = [$Body] as Array[Polygon2D]
	_config.body_color = TransportConstants.CAR_COLORS[randi() % TransportConstants.CAR_COLORS.size()]

	return _config
