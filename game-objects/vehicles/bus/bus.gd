extends Vehicle

class_name Bus

@onready var path_follower: PathFollow2D = $PathFollower
@onready var body_area = $BodyArea
@onready var collision_area = $CollisionArea
@onready var forward_blockage_area = $ForwardBlockadeObserver

func _get_vehicle_config() -> Variant:
	return {
		"ai": BusAI.new(),
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
		"path_followers": [{"follower": path_follower, "offset": 0.0, "body": self}],
		"body_areas": [body_area],
		"collision_areas": [collision_area],
		"blockade_indicator": $Body/Line2D
	}
