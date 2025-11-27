extends Camera2D

class_name Camera

var camera_speed
var bounds: Rect2
var bounds_offset: Vector2
var camera_zoom_bounds: Array[Vector2]
var dragging = false
var drag_start_pos = Vector2.ZERO
var last_mouse_pos = Vector2.ZERO

var ui_manager: UIManager
var game_manager: GameManager


func _ready() -> void:
	ui_manager = GDInjector.inject("UIManager") as UIManager
	game_manager = GDInjector.inject("GameManager") as GameManager


func set_camera_props(new_bounds: Rect2, projection_offset: Vector2, zoom_bounds: Array[Vector2], speed: float):
	bounds = new_bounds
	var pos = position
	pos.x = clamp(pos.x, bounds.position.x, bounds.position.x + bounds.size.x)
	pos.y = clamp(pos.y, bounds.position.y, bounds.position.y + bounds.size.y)

	position = pos
	bounds_offset = projection_offset
	camera_zoom_bounds = zoom_bounds
	camera_speed = speed


func set_camera_position(new_position: Vector2) -> void:
	global_position = new_position


func _process(delta):
	if not game_manager.is_game_initialized():
		return

	var movement = Vector2.ZERO

	if Input.is_action_pressed("move_viewport_right"):
		movement.x += 1
	if Input.is_action_pressed("move_viewport_left"):
		movement.x -= 1
	if Input.is_action_pressed("move_viewport_up"):
		movement.y -= 1
	if Input.is_action_pressed("move_viewport_down"):
		movement.y += 1

	var movement_delta = movement / zoom * camera_speed * delta
	var new_pos = position + movement_delta

	_update_camera_position(new_pos)


func _input(event):
	if not game_manager.is_game_initialized() or game_manager.is_game_menu_visible():
		return

	if event is InputEventMouseButton:
		if event is InputEventMouseButton and (event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			var mouse_pos = get_viewport().get_mouse_position()

			if ui_manager.is_mouse_over_ui(mouse_pos):
				return

		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom *= 1.1
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom *= 0.9

		zoom = zoom.clamp(camera_zoom_bounds[0], camera_zoom_bounds[1])

		if event.button_index == MOUSE_BUTTON_MIDDLE:
			if event.pressed:
				dragging = true
				drag_start_pos = event.position
				last_mouse_pos = event.position
			else:
				dragging = false

	elif event is InputEventMouseMotion and dragging:
		var mouse_delta = last_mouse_pos - event.position
		last_mouse_pos = event.position

		mouse_delta = mouse_delta / zoom

		var new_pos = position + mouse_delta
		_update_camera_position(new_pos)


func _update_camera_position(new_pos: Vector2):
	var min_bounds = bounds.position
	var max_bounds = bounds.position + bounds.size

	if zoom.x == camera_zoom_bounds[0].x:
		min_bounds = Vector2(
			bounds.position.x / bounds_offset.x,
			bounds.position.y / bounds_offset.y,
		)

		max_bounds = Vector2(
			(bounds.position.x + bounds.size.x) / bounds_offset.x,
			(bounds.position.y + bounds.size.y) / bounds_offset.y,
		)

	position = new_pos.clamp(min_bounds, max_bounds)
	get_parent().queue_redraw()
