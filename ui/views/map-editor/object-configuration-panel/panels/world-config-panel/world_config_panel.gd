extends MarginContainer

@onready var name_edit: LineEdit = $Content/NameProp/NameEdit
@onready var desc_edit: TextEdit = $Content/DescProp/DescEdit
@onready var map_size_x_edit: SpinBox = $Content/MapSizeProp/VectorWrapper/MapSizeXEdit
@onready var map_size_y_edit: SpinBox = $Content/MapSizeProp/VectorWrapper/MapSizeYEdit
@onready var cam_pos_x_edit: SpinBox = $Content/CameraPosProp/VectorWrapper/CamPosXEdit
@onready var cam_pos_y_edit: SpinBox = $Content/CameraPosProp/VectorWrapper/CamPosYEdit
@onready var take_current_cam_pos_button: Button = $Content/CameraPosProp/TakeCurrentCamPosButton
@onready var cam_zoom_edit: SpinBox = $Content/CameraZoomProp/CamZoomEdit
@onready var take_current_cam_zoom_button: Button = $Content/CameraZoomProp/TakeCurrentCamZoomButton

@onready var game_manager: GameManager = GDInjector.inject("GameManager") as GameManager

var _map_editor: MapEditorGameController


func _ready() -> void:
	take_current_cam_pos_button.pressed.connect(_on_take_current_cam_pos_button_pressed)
	take_current_cam_zoom_button.pressed.connect(_on_take_current_cam_zoom_button_pressed)

	name_edit.text_changed.connect(_on_name_edit_text_changed)
	desc_edit.text_changed.connect(_on_desc_edit_text_changed)
	map_size_x_edit.value_changed.connect(_on_map_size_x_edit_value_changed)
	map_size_y_edit.value_changed.connect(_on_map_size_y_edit_value_changed)
	cam_pos_x_edit.value_changed.connect(_on_cam_pos_x_edit_value_changed)
	cam_pos_y_edit.value_changed.connect(_on_cam_pos_y_edit_value_changed)
	cam_zoom_edit.value_changed.connect(_on_cam_zoom_edit_value_changed)


func setup() -> void:
	_map_editor = game_manager.get_game_controller() as MapEditorGameController

	if _map_editor == null:
		push_error("WorldConfigPanel initialized outside of MapEditorGameController context.")
		return

	_load_config()

	var zoom_bounds = _map_editor.get_camera_zoom_bounds()
	cam_zoom_edit.min_value = zoom_bounds[0].x
	cam_zoom_edit.max_value = zoom_bounds[1].x


func _load_config() -> void:
	var world_details = _map_editor.get_world_details()

	name_edit.text = world_details["name"]
	desc_edit.text = world_details["description"]

	var map_size = world_details["map_size"]
	map_size_x_edit.value = map_size.x
	map_size_y_edit.value = map_size.y

	var initial_cam_pos = world_details["camera_initial_pos"]
	cam_pos_x_edit.value = initial_cam_pos.x
	cam_pos_y_edit.value = initial_cam_pos.y

	cam_zoom_edit.value = world_details["camera_initial_zoom"]


func _on_take_current_cam_pos_button_pressed() -> void:
	var cam_pos = _map_editor.get_camera().position
	cam_pos_x_edit.value = cam_pos.x
	cam_pos_y_edit.value = cam_pos.y


func _on_take_current_cam_zoom_button_pressed() -> void:
	var cam_zoom = _map_editor.get_camera().zoom.x
	cam_zoom_edit.value = cam_zoom


func _on_name_edit_text_changed(new_text: String) -> void:
	if _map_editor == null:
		return

	var next_name = new_text.strip_edges().strip_escapes()

	if next_name.length() == 0:
		next_name = "Untitled world"

	_map_editor.set_world_name(next_name)


func _on_desc_edit_text_changed() -> void:
	if _map_editor == null:
		return

	_map_editor.set_world_description(desc_edit.text)


func _on_map_size_x_edit_value_changed(new_value: float) -> void:
	if _map_editor == null:
		return

	var new_size = Vector2(new_value, map_size_y_edit.value)
	_map_editor.set_map_size(new_size)


func _on_map_size_y_edit_value_changed(new_value: float) -> void:
	if _map_editor == null:
		return

	var new_size = Vector2(map_size_x_edit.value, new_value)
	_map_editor.set_map_size(new_size)


func _on_cam_pos_x_edit_value_changed(new_value: float) -> void:
	if _map_editor == null:
		return

	var new_pos = Vector2(new_value, cam_pos_y_edit.value)
	_map_editor.set_camera_initial_pos(new_pos)


func _on_cam_pos_y_edit_value_changed(new_value: float) -> void:
	if _map_editor == null:
		return

	var new_pos = Vector2(cam_pos_x_edit.value, new_value)
	_map_editor.set_camera_initial_pos(new_pos)


func _on_cam_zoom_edit_value_changed(new_value: float) -> void:
	if _map_editor == null:
		return

	_map_editor.set_camera_initial_zoom(new_value)
