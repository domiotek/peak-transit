extends Vehicle

class_name Car

@onready var path_follower: PathFollow2D = $PathFollower
@onready var body_area = $BodyArea
@onready var collision_area = $CollisionArea
@onready var forward_blockage_area = $ForwardBlockadeObserver

func _get_vehicle_config() -> Variant:
	return {
		"ai": CarAI.new(),
		"blockade_observer": forward_blockage_area,
		"brake_lights": [$Body/LeftBrakeLight, $Body/RightBrakeLight],
		"casters": {
			"close": $CloseRayCaster,
			"medium": $MediumRayCaster,
			"long": $LongRayCaster,
			"left": $LeftRayCaster,
			"right": $RightRayCaster
		},
		"caster_indicators": {
			"close": $Body/CloseRayIndicator,
			"medium": $Body/MediumRayIndicator,
			"long": $Body/LongRayIndicator,
			"left": $Body/LeftRayIndicator,
			"right": $Body/RightRayIndicator
		},
		"id_label": $Body/Label,
		"path_followers": [path_follower],
		"body_areas": [body_area],
		"collision_areas": [collision_area],
		"blockade_indicator": $Body/Line2D
	}
