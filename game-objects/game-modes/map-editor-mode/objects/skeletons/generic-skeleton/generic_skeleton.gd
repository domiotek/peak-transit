extends Node2D

class_name GenericSkeleton

@onready var shape: Polygon2D = $Shape


func _ready() -> void:
	render_default()


func update_shape(collision_polygon: PackedVector2Array) -> void:
	shape.polygon = collision_polygon


func render_default() -> void:
	shape.color = MapEditorConstants.SKELETON_DEFAULT_COLOR


func render_error() -> void:
	shape.color = MapEditorConstants.SKELETON_ERROR_COLOR
