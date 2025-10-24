extends Vehicle

class_name ArticulatedBus

@onready var front_path_follower: PathFollow2D = $FrontBody/PathFollower
@onready var trailer_path_follower: PathFollow2D = $Trailer/PathFollower
@onready var main_body_area = $FrontBody/BodyArea
@onready var trailer_body_area = $Trailer/BodyArea
@onready var main_collision_area = $FrontBody/CollisionArea
@onready var trailer_collision_area = $Trailer/CollisionArea
@onready var forward_blockage_area = $FrontBody/ForwardBlockadeObserver

func _get_vehicle_config() -> Variant:
	return {
		"ai": BusAI.new(),
		"blockade_observer": forward_blockage_area,
		"brake_lights": [$Trailer/TrailerBody/LeftBrakeLight, $Trailer/TrailerBody/RightBrakeLight],
		"casters": {
			"close": $FrontBody/CloseRayCaster,
			"medium": $FrontBody/MediumRayCaster,
			"long": $FrontBody/LongRayCaster,
			"left": $FrontBody/LeftRayCaster,
			"right": $FrontBody/RightRayCaster
		},
		"caster_indicators": {
			"close": $FrontBody/CloseRayIndicator,
			"medium": $FrontBody/MediumRayIndicator,
			"long": $FrontBody/LongRayIndicator,
			"left": $FrontBody/LeftRayIndicator,
			"right": $FrontBody/RightRayIndicator
		},
		"id_label": $FrontBody/Label,
		"path_followers": [
			{
				"follower": front_path_follower, 
				"offset": 0.0, 
				"body": $FrontBody
			}, 
			{
				"follower": trailer_path_follower, 
				"offset": 28.0, 
				"body": $Trailer
			}
		],
		"body_areas": [main_body_area, trailer_body_area],
		"collision_areas": [main_collision_area, trailer_collision_area],
		"blockade_indicator": $FrontBody/Line2D
	}
