extends BaseBuilding

class_name Terminal

var terminal_id: int

var _terminal_data: TerminalDefinition

var _line_id_to_peron: Dictionary[int, int] = { }
var _peron_lines: Dictionary[int, Array] = { }
var _peron_count: int
var _peron_anchors: Array = []

var _tracks = { }
var _vehicles_on_tracks: Dictionary = { }
var _tracks_in_use: Dictionary = { }

@onready var in_track: Path2D = $InTrack
@onready var in_line_track: Path2D = $InLineTrack
@onready var in_wait_track: Path2D = $InWaitTrack

@onready var bypass_track: Path2D = $BypassTrack
@onready var bypass_around_track: Path2D = $BypassAroundTrack
@onready var bypass_out_track: Path2D = $BypassOutTrack

@onready var wait_in_tracks: Node2D = $WaitTracks/InTracks
@onready var wait_out_tracks: Node2D = $WaitTracks/OutTracks

@onready var peron_in_tracks: Node2D = $PeronTracks/InTracks
@onready var peron_out_tracks: Node2D = $PeronTracks/OutTracks
@onready var peron_around_tracks: Node2D = $PeronTracks/AroundTracks


@onready var game_manager: GameManager = GDInjector.inject("GameManager") as GameManager


func _ready() -> void:
	super._ready()
	_tracks["wait"] = []
	_tracks["peron"] = []

	_process_tracks(wait_in_tracks, wait_out_tracks, _tracks["wait"])
	_peron_count = _process_tracks(peron_in_tracks, peron_out_tracks, _tracks["peron"], peron_around_tracks)
	_smooth_tracks()
	_setup_perons()


func setup_terminal(new_id: int, terminal_data: TerminalDefinition) -> void:
	terminal_id = new_id
	_terminal_data = terminal_data


func update_visuals() -> void:
	# Terminals might have specific visuals to update in the future
	pass


func get_terminal_name() -> String:
	return _terminal_data.name


func get_position_offset() -> float:
	return _terminal_data.position.offset


func get_incoming_node_id() -> int:
	return _terminal_data.position.segment[0]


func get_outgoing_node_id() -> int:
	return _terminal_data.position.segment[1]


func register_line(line_id) -> int:
	var peron_index = _get_next_peron_index()
	_line_id_to_peron[line_id] = peron_index
	_peron_lines.get_or_add(peron_index, []).append(line_id)
	return peron_index


func get_peron_for_line(line_id) -> int:
	return _line_id_to_peron.get(line_id, -1)


func get_line_curves(line_id: int, is_out: bool) -> Array:
	var peron_index = _line_id_to_peron.get(line_id, -1)
	if peron_index == -1:
		return []

	var result = []
	if not is_out:
		result.append_array([in_track.curve, in_line_track.curve])

	var track_dict = _tracks["peron"][peron_index]

	if is_out:
		result.append(track_dict["out"].curve)
	else:
		result.append(track_dict["in"].curve)

	for i in range(result.size()):
		result[i] = line_helper.convert_curve_local_to_global(result[i], self)

	return result


func get_peron_anchor(peron_index: int) -> Node2D:
	return _peron_anchors[peron_index]

func get_lines_at_peron(peron_index: int) -> Array:
	var lines = []
	for line_id in _line_id_to_peron.keys():
		if _line_id_to_peron[line_id] == peron_index:
			lines.append(line_id)
	return lines


func try_enter(vehicle_id: int) -> Path2D:
	if _tracks_in_use.has("in"):
		return null

	_tracks_in_use["in"] = true
	_vehicles_on_tracks[vehicle_id] = "in"

	return in_track


func navigate_to_peron(vehicle_id: int, peron: int) -> Dictionary:
	var search_callback = func(current_track_id: String, track_id_parts: Array) -> Dictionary:
		var next_track_id: String
		if current_track_id == "in_line":
			next_track_id = "peron_%d_in" % peron
		elif current_track_id == "in_wait":
			var free_wait_index = _get_next_free_wait_track()
			if free_wait_index == -1:
				return {
					"path": null,
					"error": TerminalTrackState.TrackSearchError.NO_FREE_WAIT_TRACK,
				}

			next_track_id = "wait_%d_in" % free_wait_index
		elif current_track_id.begins_with("peron_"):
			var current_peron_index = int(track_id_parts[1])
			var track_type = track_id_parts[2]

			if current_peron_index == peron and track_type == "in":
				return {
					"path": null,
					"error": TerminalTrackState.TrackSearchError.ALREADY_ON_TARGET,
				}

			match track_type:
				"in":
					next_track_id = "peron_%d_around" % current_peron_index
				"around":
					next_track_id = "in_line"
		elif current_track_id.begins_with("wait_"):
			next_track_id = "wait_%s_out" % track_id_parts[1] if track_id_parts[2] == "in" else "peron_%d_in" % peron

		return {
			"path": next_track_id,
		}

	return _find_next_track(vehicle_id, TerminalTrackState.navigate_to_peron_map, search_callback)


func leave_terminal(vehicle_id: int) -> Dictionary:
	var search_callback = func(current_track_id: String, track_id_parts: Array) -> Dictionary:
		var next_track_id: String
		if current_track_id == "in_wait":
			var free_wait_index = _get_next_free_wait_track()
			if free_wait_index == -1:
				return {
					"path": null,
					"error": TerminalTrackState.TrackSearchError.NO_FREE_WAIT_TRACK,
				}

			next_track_id = "wait_%d_in" % free_wait_index
		elif current_track_id.begins_with("peron_"):
			var current_peron_index = int(track_id_parts[1])
			var track_type = track_id_parts[2]

			match track_type:
				"in":
					next_track_id = "peron_%d_out" % current_peron_index
				"around":
					next_track_id = "in_line"
				"out":
					return {
						"path": null,
						"error": TerminalTrackState.TrackSearchError.ALREADY_ON_TARGET,
					}

		elif current_track_id.begins_with("wait_"):
			next_track_id = "wait_%s_out" % track_id_parts[1] if track_id_parts[2] == "in" else "bypass"
		elif current_track_id == "bypass_out":
			return {
				"path": null,
				"error": TerminalTrackState.TrackSearchError.ALREADY_ON_TARGET,
			}

		return {
			"path": next_track_id,
		}

	return _find_next_track(vehicle_id, TerminalTrackState.leave_terminal_map, search_callback)


func wait_at_terminal(vehicle_id: int) -> Dictionary:
	var search_callback = func(current_track_id: String, track_id_parts: Array) -> Dictionary:
		var next_track_id: String
		if current_track_id == "in_wait":
			var free_wait_index = _get_next_free_wait_track()
			if free_wait_index == -1:
				return {
					"path": null,
					"error": TerminalTrackState.TrackSearchError.NO_FREE_WAIT_TRACK,
				}

			next_track_id = "wait_%d_in" % free_wait_index
		elif current_track_id.begins_with("peron_"):
			var current_peron_index = int(track_id_parts[1])

			if track_id_parts[2] == "around":
				next_track_id = "in_wait"
			else:
				next_track_id = "peron_%d_around" % current_peron_index

		elif current_track_id.begins_with("wait_"):
			if track_id_parts[2] == "in":
				return {
					"path": null,
					"error": TerminalTrackState.TrackSearchError.ALREADY_ON_TARGET,
				}

			next_track_id = "bypass"

		return {
			"path": next_track_id,
		}

	return _find_next_track(vehicle_id, TerminalTrackState.wait_at_terminal_map, search_callback)


func notify_vehicle_left_terminal(vehicle_id: int) -> void:
	var current_track_id = _vehicles_on_tracks.get(vehicle_id, "")
	if current_track_id != "":
		_tracks_in_use.erase(current_track_id)
		_vehicles_on_tracks.erase(vehicle_id)


func _find_next_track(vehicle_id: int, state_map: Dictionary, custom_track_search_callback) -> Dictionary:
	if _vehicles_on_tracks.get(vehicle_id, "") == "":
		push_error("Vehicle ID %d is not registered as being at terminal ID %d." % [vehicle_id, terminal_id])
		return {
			"path": null,
			"error": TerminalTrackState.TrackSearchError.VEH_NOT_REGISTERED,
		}

	var current_track_id = _vehicles_on_tracks[vehicle_id]
	var next_track_id = state_map.get(current_track_id, null)
	var track_id_parts = current_track_id.split("_")

	if not next_track_id:
		var search_result = custom_track_search_callback.call(current_track_id, track_id_parts)

		if search_result.has("error"):
			return search_result

		next_track_id = search_result["path"]

	return _switch_to_track(current_track_id, next_track_id, vehicle_id)


func _process_tracks(in_tracks: Node2D, out_tracks: Node2D, target_array: Array, around_tracks: Node2D = null) -> int:
	var children = in_tracks.get_children()

	for i in range(children.size()):
		var child = children[i]

		var path = child as Path2D
		var around_path = around_tracks.get_child(i) as Path2D if around_tracks != null else null
		var out_path = out_tracks.get_child(i) as Path2D

		if not out_path:
			target_array.erase(target_array[i])
			push_error("Terminal track %d is misconfigured: missing out path." % i)
			continue

		if around_tracks and not around_path:
			target_array.erase(target_array[i])
			push_error("Terminal track %d is misconfigured: missing around path." % i)
			continue

		target_array.append(
			{
				"in": path,
				"out": out_path,
				"around": around_path,
			},
		)

	return children.size()


func _get_track_by_id(track_id: String) -> Path2D:
	match track_id:
		"in":
			return in_track
		"in_line":
			return in_line_track
		"in_wait":
			return in_wait_track
		"bypass":
			return bypass_track
		"bypass_around":
			return bypass_around_track
		"bypass_out":
			return bypass_out_track

	var parts = track_id.split("_")

	if parts.size() != 3:
		push_error("Invalid track ID format: '%s'." % track_id)
		return null

	var tracks_array = _tracks.get(parts[0], null)

	if tracks_array == null:
		push_error("Unknown track category: '%s'." % parts[0])
		return null

	var index = int(parts[1])
	if index >= 0 and index < tracks_array.size():
		return tracks_array[index][parts[2]]

	push_error("Peron track index out of range: %d." % index)
	return null


func _get_next_free_wait_track() -> int:
	for i in range(_tracks["wait"].size()):
		var track_id = "wait_%d_in" % i
		if not _tracks_in_use.has(track_id):
			return i

	return -1


func _switch_to_track(current_track_id: String, next_track_id: String, vehicle_id: int) -> Dictionary:
	if not next_track_id:
		push_error("Vehicle ID %d is on an invalid track '%s' at terminal ID %d." % [vehicle_id, current_track_id, terminal_id])
		return {
			"path": null,
			"error": TerminalTrackState.TrackSearchError.INVALID_POSITION,
		}

	if _tracks_in_use.has(next_track_id):
		return {
			"path": null,
			"error": TerminalTrackState.TrackSearchError.TRACK_IN_USE,
		}

	_tracks_in_use.erase(current_track_id)
	_tracks_in_use[next_track_id] = true
	_vehicles_on_tracks[vehicle_id] = next_track_id

	return {
		"path": _get_track_by_id(next_track_id),
		"error": null,
	}


func _smooth_tracks() -> void:
	in_track.curve = line_helper.smooth_curve(in_track.curve)
	in_line_track.curve = line_helper.smooth_curve(in_line_track.curve)
	in_wait_track.curve = line_helper.smooth_curve(in_wait_track.curve)
	bypass_track.curve = line_helper.smooth_curve(bypass_track.curve)
	bypass_around_track.curve = line_helper.smooth_curve(bypass_around_track.curve)
	bypass_out_track.curve = line_helper.smooth_curve(bypass_out_track.curve)

	for track_dict in _tracks["wait"]:
		track_dict["in"].curve = line_helper.smooth_curve(track_dict["in"].curve)
		track_dict["out"].curve = line_helper.smooth_curve(track_dict["out"].curve)

	for track_dict in _tracks["peron"]:
		track_dict["in"].curve = line_helper.smooth_curve(track_dict["in"].curve)
		if track_dict["around"]:
			track_dict["around"].curve = line_helper.smooth_curve(track_dict["around"].curve)
		track_dict["out"].curve = line_helper.smooth_curve(track_dict["out"].curve)


func _update_debug_visuals() -> void:
	super._update_debug_visuals()

	if config_manager.DebugToggles.DrawTerminalPaths:
		for track_dict in _tracks["wait"]:
			line_helper.draw_solid_line(track_dict["in"].curve, debug_layer, 2.0, Color.GREEN)
			line_helper.draw_solid_line(track_dict["out"].curve, debug_layer, 2.0, Color.GREEN)

		for track_dict in _tracks["peron"]:
			line_helper.draw_solid_line(track_dict["in"].curve, debug_layer, 2.0, Color.BLUE)
			if track_dict["around"]:
				line_helper.draw_solid_line(track_dict["around"].curve, debug_layer, 2.0, Color.YELLOW)
			line_helper.draw_solid_line(track_dict["out"].curve, debug_layer, 2.0, Color.BLUE)

		line_helper.draw_solid_line(in_track.curve, debug_layer, 2.0, Color.RED)
		line_helper.draw_solid_line(in_line_track.curve, debug_layer, 2.0, Color.RED)
		line_helper.draw_solid_line(in_wait_track.curve, debug_layer, 2.0, Color.RED)

		line_helper.draw_solid_line(bypass_track.curve, debug_layer, 2.0, Color.ORANGE)
		line_helper.draw_solid_line(bypass_around_track.curve, debug_layer, 2.0, Color.ORANGE)
		line_helper.draw_solid_line(bypass_out_track.curve, debug_layer, 2.0, Color.ORANGE)


func _get_connection_endpoints() -> Dictionary:
	return {
		"in": to_global(Vector2(10, -15)),
		"out": to_global(Vector2(-10, -15)),
	}


func _get_next_peron_index() -> int:
	var curr_min_lines = INF
	var curr_min_idx = -1

	for i in range(_peron_count):
		var assigned_lines = _peron_lines.get(i, [])
		var line_count = assigned_lines.size()

		if line_count < curr_min_lines:
			curr_min_lines = line_count
			curr_min_idx = i

	return curr_min_idx


func _setup_perons() -> void:
	for i in range(_peron_count):
		var peron_node = get_node("Peron%d/ClickArea" % i) as Area2D
		peron_node.input_event.connect(_on_peron_clicked_event.bind(peron_node))
		peron_node.set_meta("peron_index", i)
		
		var anchor_point = peron_node.get_parent()
		_peron_anchors.append(anchor_point)




func _on_peron_clicked_event(_viewport, event: InputEvent, _shape_idx, area: Area2D) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var peron_index = area.get_meta("peron_index") as int
		var pointer = TerminalPeron.new(self, peron_index)
		var selection = StopSelection.new(StopSelection.StopSelectionType.TERMINAL_PERON, pointer)
		game_manager.set_selection(selection, GameManager.SelectionType.TRANSPORT_STOP)
