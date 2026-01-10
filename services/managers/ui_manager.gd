class_name UIManager

enum AnchorPoint {
	TOP_LEFT,
	TOP_RIGHT,
	BOTTOM_LEFT,
	BOTTOM_RIGHT,
}

var ui_views: Dictionary[String, Control] = { }

var visible_views: Array[String] = []
var loaded_views: Array[String] = []

# Ensure only one view in an exclusivity group is shown at a time
# Key: exclusivity group name, Value: currently shown view name
var _exclusivity_groups: Dictionary[String, String] = { }

# Persistent views that should not be hidden when hiding all views
var _persistent_views: Array[String] = []

var main_menu: Control
var game_manager: GameManager = GDInjector.inject("GameManager") as GameManager


func initialize(_main_menu: Control) -> void:
	main_menu = _main_menu


func show_main_menu() -> void:
	main_menu.visible = true
	var game_viewport = game_manager.get_game_controller()
	game_viewport.visible = false

	hide_all_ui_views()


func hide_main_menu() -> void:
	main_menu.visible = false
	var game_viewport = game_manager.get_game_controller()
	game_viewport.visible = true


func register_ui_view(name: String, node: Control, persistent: bool = false) -> void:
	if ui_views.has(name):
		push_error("UI View with name '%s' is already registered." % name)
		return

	ui_views[name] = node

	if persistent:
		_persistent_views.append(name)

	_call_on_view(node, "init")

	if node.visible:
		visible_views.append(name)
		_call_on_view(node, "load")


func has_ui_view(name: String) -> bool:
	return ui_views.has(name)


func get_ui_view(name: String) -> Control:
	if ui_views.has(name):
		return ui_views[name]

	push_error("UI View with name '%s' not found." % name)
	return null


func is_ui_view_visible(name: String) -> bool:
	return visible_views.has(name)


func show_ui_view(name: String, data: Dictionary = { }) -> void:
	if ui_views.has(name):
		var view = ui_views[name]
		view.visible = true
		if not visible_views.has(name):
			visible_views.append(name)
		_render_view(view, data)
	else:
		push_error("UI View with name '%s' not found." % name)


func hide_ui_view(name: String):
	if ui_views.has(name):
		var view = ui_views[name]
		view.visible = false
		visible_views.erase(name)

		for group_name in _exclusivity_groups.keys():
			if _exclusivity_groups[group_name] == name:
				_exclusivity_groups.erase(group_name)
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


func hide_all_ui_views() -> void:
	for ui_view_id in visible_views.duplicate():
		if not _persistent_views.has(ui_view_id):
			hide_ui_view(ui_view_id)


func unregister_ui_view(name: String) -> void:
	if ui_views.has(name):
		hide_ui_view(name)
		ui_views.erase(name)
		loaded_views.erase(name)
		_persistent_views.erase(name)

		for group_name in _exclusivity_groups.keys():
			if _exclusivity_groups[group_name] == name:
				_exclusivity_groups.erase(group_name)
	else:
		push_error("UI View with name '%s' not found." % name)


func is_mouse_over_ui(mouse_position: Vector2) -> bool:
	for ui_view_id in visible_views:
		var ui_view = ui_views[ui_view_id]
		var is_over = ui_view.get_global_rect().has_point(mouse_position)

		if is_over:
			return true

	return false


func show_ui_view_exclusively(group: String, view_name: String, data: Dictionary = { }) -> void:
	if _exclusivity_groups.has(group):
		var current_view_name = _exclusivity_groups[group]
		if current_view_name != view_name:
			hide_ui_view(current_view_name)

	_exclusivity_groups[group] = view_name
	show_ui_view(view_name, data)


func toggle_ui_view_exclusively(group: String, view_name: String, data: Dictionary = { }) -> void:
	if _exclusivity_groups.has(group):
		var current_view_name = _exclusivity_groups[group]
		if current_view_name == view_name:
			hide_ui_view(current_view_name)
			_exclusivity_groups.erase(group)
			return
		hide_ui_view(current_view_name)

	_exclusivity_groups[group] = view_name
	show_ui_view(view_name, data)


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


func reset_ui_views() -> void:
	for view_name in ui_views.keys():
		_call_on_view(ui_views[view_name], "reset")

	loaded_views.clear()


func _render_view(view: Control, data: Dictionary) -> void:
	if loaded_views.has(view.name):
		_call_on_view(view, "update", data)
	else:
		loaded_views.append(view.name)
		_call_on_view(view, "load")
		_call_on_view(view, "update", data)


func _call_on_view(view: Control, event: String, data: Dictionary = { }) -> void:
	match event:
		"init":
			if view.has_method("init"):
				view.init()
		"load":
			if view.has_method("load"):
				view.load()
		"update":
			if view.has_method("update"):
				view.update(data)
		"reset":
			if view.has_method("reset"):
				view.reset()
		_:
			push_error("Unknown event '%s' for UI View." % event)
