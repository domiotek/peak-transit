class_name UIManager

enum AnchorPoint {
	TOP_LEFT,
	TOP_RIGHT,
	BOTTOM_LEFT,
	BOTTOM_RIGHT,
}


var ui_views: Dictionary[String, Control] = {}

var visible_views: Array[String] = []
var loaded_views: Array[String] = []


func register_ui_view(name: String, node: Control):
	if ui_views.has(name):
		push_error("UI View with name '%s' is already registered." % name)
		return

	ui_views[name] = node

	_call_on_view(node, "init")

	if node.visible:
		visible_views.append(name)
		_call_on_view(node, "load")


func get_ui_view(name: String) -> Control:
	if ui_views.has(name):
		return ui_views[name]
	else:
		push_error("UI View with name '%s' not found." % name)
		return null

func show_ui_view(name: String):
	if ui_views.has(name):
		var view = ui_views[name]
		view.visible = true
		if not visible_views.has(name):
			visible_views.append(name)
		_render_view(view)
	else:
		push_error("UI View with name '%s' not found." % name)

func hide_ui_view(name: String):
	if ui_views.has(name):
		var view = ui_views[name]
		view.visible = false
		visible_views.erase(name)
	else:
		push_error("UI View with name '%s' not found." % name)

func toggle_ui_view(name: String):
	if ui_views.has(name):
		var view = ui_views[name]
		if view.visible:
			hide_ui_view(name)
		else:
			show_ui_view(name)
	else:
		push_error("UI View with name '%s' not found." % name)


func is_mouse_over_ui(mouse_position: Vector2) -> bool:
	for ui_view_id in visible_views:
		var ui_view = ui_views[ui_view_id]
		var is_over = ui_view.get_global_rect().has_point(mouse_position)

		if is_over:
			return true

	return false

func get_anchor_point_to_world_object(viewport: Viewport, object: Object) -> Vector2:
	var vehicle_world_pos = object.global_position
	var camera = viewport.get_camera_2d()

	if not camera:
		return Vector2.ZERO

	var viewport_size = viewport.get_visible_rect().size
	var camera_pos = camera.global_position
	var camera_zoom = camera.zoom
	
	var relative_pos = (vehicle_world_pos - camera_pos) * camera_zoom
	var screen_pos = viewport_size * 0.5 + relative_pos
	return screen_pos

func reanchor_to_world_object(control: Control, target_object: Node2D, anchor: AnchorPoint, clamp_to_screen: bool) -> void:
	var viewport = control.get_viewport()
	var position = get_anchor_point_to_world_object(viewport, target_object)

	match anchor:
		AnchorPoint.TOP_LEFT:
			pass
		AnchorPoint.TOP_RIGHT:
			position.x -= control.size.x
		AnchorPoint.BOTTOM_LEFT:
			position.y -= control.size.y
		AnchorPoint.BOTTOM_RIGHT:
			position -= control.size
		_:
			push_error("Unknown anchor point: %s" % str(anchor))
			return

	if clamp_to_screen:
		position.x = clamp(position.x, 0, viewport.size.x - control.size.x)
		position.y = clamp(position.y, 0, viewport.size.y - control.size.y)

	control.position = position

func _render_view(view: Control) -> void:
	if loaded_views.has(view.name):
		_call_on_view(view, "update")
	else:
		loaded_views.append(view.name)
		_call_on_view(view, "load")

func _call_on_view(view: Control, event: String) -> void:
	match event:
		"init":
			if view.has_method("init"):
				view.init()

		"load":
			if view.has_method("load"):
				view.load()

		"update":
			if view.has_method("update"):
				view.update()
		_:
			push_error("Unknown event '%s' for UI View." % event)
