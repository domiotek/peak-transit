class_name PathingManager

var path_finder: PathFinder

func inject_dependencies() -> void:
	path_finder = GDInjector.inject("PathFinder") as PathFinder


func find_path(start_node_id: int, end_node_id: int, callback: Callable) -> void:
	path_finder.FindPath(start_node_id, end_node_id, callback)
