class_name BaseMapTool

var _manager: MapInteractionsManager


func _init(manager: MapInteractionsManager) -> void:
	_manager = manager


func handle_map_clicked(_world_position: Vector2) -> void:
	pass


func handle_map_unclicked() -> void:
	pass


func handle_map_mouse_move(_world_position: Vector2) -> void:
	pass


func reset_state() -> void:
	pass
