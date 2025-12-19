class_name PathingManager

var path_finder: PathFinder
var active_requests: Dictionary = { }
var request_counter: int = 0
var path_cache: Dictionary = { }
var cache_ttl_seconds: float = 5.0


func inject_dependencies() -> void:
	path_finder = GDInjector.inject("PathFinder") as PathFinder


func find_path(
		start_node_id: int,
		end_node_id: int,
		callback: Callable,
		requester_vehicle_type: VehicleManager.VehicleCategory,
		force_start_endpoint: int = -1,
		force_end_endpoint: int = -1,
) -> void:
	var cache_key = _generate_cache_key(start_node_id, end_node_id, force_start_endpoint, force_end_endpoint)

	var cached_result = _get_cached_result(cache_key)
	if cached_result != null:
		callback.call(cached_result)
		return

	var request_id = _get_request_id()
	active_requests[request_id] = {
		"results": [null],
		"completed_count": 0,
		"executing_stack": get_stack(),
		"total_count": 1,
		"callback": callback,
		"is_finished": false,
	}

	path_finder.FindPath(
		start_node_id,
		end_node_id,
		request_id,
		Callable(self, "_on_pathfinding_result"),
		requester_vehicle_type,
		force_start_endpoint,
		force_end_endpoint,
		0,
	)


func find_path_with_multiple_options(
		combinations: Array,
		callback: Callable,
		requester_vehicle_type: VehicleManager.VehicleCategory,
		timeout: float = 50.0,
) -> void:
	if combinations.is_empty():
		callback.call(null)
		return

	var request_id = _get_request_id()

	var path_context = {
		"results": [],
		"completed_count": 0,
		"total_count": combinations.size(),
		"callback": callback,
		"is_finished": false,
	}

	active_requests[request_id] = path_context

	var cached_combinations = { }

	for i in range(combinations.size()):
		path_context.results.append(null)
		var combo = combinations[i]
		var cache_key = _generate_cache_key(
			combo["from_node"],
			combo["to_node"],
			combo.get("from_endpoint", -1),
			combo.get("to_endpoint", -1),
		)

		var cached_result = _get_cached_result(cache_key)
		if cached_result != null:
			cached_combinations[i] = true
			call_deferred("_on_pathfinding_result", request_id, i, cached_result)

	var scene_tree = Engine.get_main_loop() as SceneTree
	if scene_tree:
		var timer = scene_tree.create_timer(timeout)
		timer.timeout.connect(_on_request_timeout.bind(request_id))

	for i in range(combinations.size()):
		if cached_combinations.has(i):
			continue

		var combo = combinations[i]

		path_finder.FindPath(
			combo["from_node"],
			combo["to_node"],
			request_id,
			Callable(self, "_on_pathfinding_result"),
			requester_vehicle_type,
			combo.get("from_endpoint", -1),
			combo.get("to_endpoint", -1),
			i,
		)


func cancel_all_requests() -> void:
	active_requests.clear()


func clear_state() -> void:
	active_requests.clear()
	path_cache.clear()
	request_counter = 0
	path_finder.ClearGraph()


func _get_request_id() -> int:
	request_counter += 1
	return (Time.get_ticks_msec() * 10000) + request_counter


func _generate_cache_key(start_node_id: int, end_node_id: int, force_start_endpoint: int = -1, force_end_endpoint: int = -1) -> String:
	return "%d_%d_%d_%d" % [start_node_id, end_node_id, force_start_endpoint, force_end_endpoint]


func _is_cache_entry_valid(cache_key: String) -> bool:
	if not path_cache.has(cache_key):
		return false

	var cache_entry = path_cache[cache_key]

	if not is_instance_valid(cache_entry["result"]):
		return false

	var current_time = Time.get_unix_time_from_system()
	var entry_time = cache_entry["timestamp"]

	return (current_time - entry_time) <= cache_ttl_seconds


func _get_cached_result(cache_key: String):
	if _is_cache_entry_valid(cache_key):
		return path_cache[cache_key]["result"].Clone()

	path_cache.erase(cache_key)

	return null


func _on_pathfinding_result(request_id: int, combination_id: int, path_result) -> void:
	if not active_requests.has(request_id):
		return

	var path_context = active_requests[request_id]
	if path_context.is_finished:
		return

	path_context.results[combination_id] = path_result
	path_context.completed_count += 1

	if path_context.completed_count >= path_context.total_count:
		path_context.is_finished = true
		active_requests.erase(request_id)
		_select_best_path(path_context.results, path_context.callback)


func _on_request_timeout(request_id: int) -> void:
	if not active_requests.has(request_id):
		return

	var path_context = active_requests[request_id]
	if path_context.is_finished:
		return

	path_context.is_finished = true
	active_requests.erase(request_id)
	_select_best_path(path_context.results, path_context.callback)


func _select_best_path(results: Array, callback: Callable) -> void:
	var best_cost: float = INF
	var best_result_index: int = -1

	for i in range(results.size()):
		var result = results[i]
		if result == null:
			continue

		if result.State == 1:
			var path_cost = result.TotalCost
			if path_cost < best_cost:
				best_cost = path_cost
				best_result_index = i

	var best_result = results[best_result_index] if best_result_index != -1 else null

	if best_result_index == -1:
		best_result = {
			"State": 2,
		}
	else:
		var cache_key = _generate_cache_key(
			best_result.StartNodeId,
			best_result.EndNodeId,
			best_result.ForcedStartEndpointId,
			best_result.ForcedEndEndpointId,
		)
		path_cache[cache_key] = {
			"result": best_result,
			"timestamp": Time.get_unix_time_from_system(),
		}

	callback.call(best_result)
