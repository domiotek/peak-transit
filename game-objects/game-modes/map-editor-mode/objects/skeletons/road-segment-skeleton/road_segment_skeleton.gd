extends Node2D

class_name RoadSegmentSkeleton

@onready var body: Line2D = $Body
@onready var line_ref_in: Node2D = $RefInLine
@onready var line_ref_out: Node2D = $RefOutLine

@onready var line_helper: LineHelper = GDInjector.inject("LineHelper") as LineHelper


func update_line(curve: Curve2D, ref_point: Vector2 = Vector2.ZERO, ref_point_set: bool = false) -> void:
	body.points = curve.get_baked_points()

	_clear_object(line_ref_in)
	_clear_object(line_ref_out)

	if ref_point_set:
		line_ref_in.visible = true
		line_ref_out.visible = true

		var in_curve = _get_straight_curve(curve.get_point_position(0), ref_point)
		var out_curve = _get_straight_curve(ref_point, curve.get_point_position(1))

		_draw_dash(in_curve, line_ref_in)
		_draw_dash(out_curve, line_ref_out)

	else:
		line_ref_in.visible = false
		line_ref_out.visible = false


func update_line_width(width: float) -> void:
	body.width = width


func render_default() -> void:
	body.default_color = MapEditorConstants.SKELETON_DEFAULT_COLOR


func render_error() -> void:
	body.default_color = MapEditorConstants.SKELETON_ERROR_COLOR


func _get_straight_curve(start: Vector2, end: Vector2) -> Curve2D:
	var curve = Curve2D.new()
	curve.add_point(start)
	curve.add_point(end)
	return curve


func _draw_dash(curve: Curve2D, parent: Node2D) -> void:
	line_helper.draw_dash_line(
		curve,
		parent,
		MapEditorConstants.SKELETON_SEGMENT_DASH_SIZE,
		MapEditorConstants.SKELETON_SEGMENT_GAP_SIZE,
		MapEditorConstants.SKELETON_SEGMENT_WIDTH,
		MapEditorConstants.SKELETON_DEFAULT_COLOR,
	)


func _clear_object(node: Node2D) -> void:
	for child in node.get_children():
		child.queue_free()
