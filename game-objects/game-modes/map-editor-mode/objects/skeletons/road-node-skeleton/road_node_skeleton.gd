extends Node2D

class_name RoadNodeSkeleton

@onready var indicator: Light = $Indicator
@onready var pickable_area: Area2D = $PickableArea

var _is_trackable: bool = true


func _ready() -> void:
	pickable_area.collision_layer = MapEditorConstants.MAP_NET_NODE_LAYER_ID if _is_trackable else 0


func render_default() -> void:
	indicator.update_color("inactive", MapEditorConstants.SKELETON_DEFAULT_COLOR)


func render_error() -> void:
	indicator.update_color("inactive", MapEditorConstants.SKELETON_ERROR_COLOR)


func mark_untrackable() -> void:
	_is_trackable = false
