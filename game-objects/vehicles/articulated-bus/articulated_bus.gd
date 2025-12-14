extends Vehicle

class_name ArticulatedBus

@onready var front_path_follower: PathFollow2D = $FrontBody/PathFollower
@onready var main_body_area = $FrontBody/BodyArea
@onready var trailer_body_area = $Trailer/BodyArea
@onready var main_collision_area = $FrontBody/CollisionArea
@onready var trailer_collision_area = $Trailer/CollisionArea
@onready var forward_blockage_area = $FrontBody/ForwardBlockadeObserver


func _get_vehicle_config() -> Variant:
	var _config = VehicleConfig.new()

	_config.ai = BusAI.new()
	_config.category = VehicleManager.VehicleCategory.PUBLIC_TRANSPORT
	_config.blockade_observer = forward_blockage_area
	_config.head_lights = [$FrontBody/LeftBeam, $FrontBody/RightBeam] as Array[Headlight]
	_config.brake_lights = [$Trailer/TrailerBody/LeftBrakeLight, $Trailer/TrailerBody/RightBrakeLight] as Array[Node2D]
	_config.casters = CasterCollection.new(
		$FrontBody/CloseRayCaster,
		$FrontBody/MediumRayCaster,
		$FrontBody/LongRayCaster,
		$FrontBody/LeftRayCaster,
		$FrontBody/RightRayCaster,
	)
	_config.caster_indicators = CasterCollection.CasterIndicatorCollection.new(
		$FrontBody/CloseRayIndicator,
		$FrontBody/MediumRayIndicator,
		$FrontBody/LongRayIndicator,
		$FrontBody/LeftRayIndicator,
		$FrontBody/RightRayIndicator,
	)
	_config.id_label = $FrontBody/Label
	_config.path_follower = front_path_follower
	_config.trailers = [
		{
			"offset": 60.0,
			"body": $Trailer,
		},
	] as Array[Dictionary]
	_config.body_areas = [main_body_area, trailer_body_area] as Array[Area2D]
	_config.collision_areas = [main_collision_area, trailer_collision_area] as Array[Area2D]
	_config.blockade_indicator = $FrontBody/Line2D
	_config.body_segments = [$FrontBody, $Trailer/TrailerBody] as Array[Polygon2D]

	return _config
