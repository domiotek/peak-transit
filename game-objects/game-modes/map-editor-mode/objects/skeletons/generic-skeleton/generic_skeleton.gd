extends Node2D

class_name GenericSkeleton

@onready var shape: Polygon2D = $Shape
@onready var second_layer_polygon: Polygon2D = $SecondLayerShape


func _ready() -> void:
	render_default()


func update_shape(collision_polygon: PackedVector2Array, visual_polygon: PackedVector2Array = PackedVector2Array()) -> void:
	shape.polygon = collision_polygon

	if visual_polygon.size() > 0:
		second_layer_polygon.polygon = visual_polygon
		second_layer_polygon.visible = true
	else:
		second_layer_polygon.visible = false


func render_default() -> void:
	shape.color = MapEditorConstants.SKELETON_DEFAULT_COLOR
	second_layer_polygon.color = _get_darker_variant(MapEditorConstants.SKELETON_DEFAULT_COLOR, 0.3)


func render_error() -> void:
	shape.color = MapEditorConstants.SKELETON_ERROR_COLOR
	second_layer_polygon.color = _get_darker_variant(MapEditorConstants.SKELETON_ERROR_COLOR, 0.3)


func _get_darker_variant(color: Color, factor: float) -> Color:
	return Color(
		color.r * (1.0 - factor),
		color.g * (1.0 - factor),
		color.b * (1.0 - factor),
		color.a,
	)
