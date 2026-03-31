class_name StopPassengersSpawner

var _demand_preset: DemandPresetDefinition
var _target_id: int
var _is_terminal: bool = false

var _spawn_timer: float = TransportConstants.PASSENGER_SPAWN_INTERVAL_DELTA
var _max_passenger_count: int
var _buckets: Array = []
var _lines: Array[TransportLine] = []

var _game_manager: GameManager = GDInjector.inject("GameManager") as GameManager
var _transport_manager: TransportManager = GDInjector.inject("TransportManager") as TransportManager
var _score_manager: ScoreManager = null


func _init(target_id: int, is_terminal: bool, lines: Array, demand_preset: DemandPresetDefinition, max_passenger_count: int) -> void:
	_target_id = target_id
	_is_terminal = is_terminal
	_demand_preset = demand_preset
	_max_passenger_count = max_passenger_count

	_game_manager.rl_mode_toggled.connect(Callable(self, "_on_rl_mode_toggled"))
	_game_manager.clock.clock_reset.connect(Callable(self, "_on_clock_reset"))

	for line_id in lines:
		var line = _transport_manager.get_line(line_id)
		if line != null:
			_lines.append(line)


func _on_rl_mode_toggled(enabled: bool) -> void:
	if enabled:
		_score_manager = _game_manager.get_game_controller().score_manager()
		return

	_score_manager = null


func _on_clock_reset() -> void:
	_buckets.clear()
	_spawn_timer = TransportConstants.PASSENGER_SPAWN_INTERVAL_DELTA


func get_waiting_passengers_for_line(line_id: int) -> int:
	var total: int = 0

	for bucket in _buckets:
		total += bucket.get_passengers_for_line(line_id)

	return total


func get_total_waiting() -> int:
	var total: int = 0

	for bucket in _buckets:
		total += bucket.get_total_passengers()

	return total


func get_max_waiting() -> int:
	return _max_passenger_count


func get_lowest_till_bored_time(clock: ClockTime) -> int:
	_cleanup_empty_buckets()

	var first_bucket: PassengerBucketEntry = _buckets[0] if _buckets.size() > 0 else null

	if first_bucket == null:
		return get_boredom_time()

	var creation_time = first_bucket.get_creation_time()
	var current_time = clock.to_time_of_day()

	var minutes_waited = current_time.to_minutes() - creation_time.to_minutes()
	if minutes_waited < 0:
		minutes_waited += 1440

	return max(0, get_boredom_time() - int(minutes_waited))


func get_boredom_time() -> int:
	return int(TransportConstants.PASSENGER_BASE_BORE_TIME * _demand_preset.boredom_tolerance_multiplier)


func get_effective_spawn_chance(clock: ClockTime) -> float:
	var frame_def = _get_frame_for_hour(clock)
	if frame_def == null or frame_def.spawn_chance_multiplier == null:
		return TransportConstants.PASSENGER_SPAWN_CHANCE_BASE * _demand_preset.spawn_chance_multiplier

	return TransportConstants.PASSENGER_SPAWN_CHANCE_BASE * frame_def.spawn_chance_multiplier


func get_effective_passenger_spawn_range(clock: ClockTime) -> Array[int]:
	var frame_def = _get_frame_for_hour(clock)

	if frame_def == null:
		push_error("No frame definition found for current hour in demand preset.")
		return [0, 0]

	return frame_def.passengers_range


func take_passengers_for_line(line_id: int, max_count: int) -> int:
	var total_taken: int = 0
	var remaining_to_take: int = max_count

	for bucket in _buckets:
		if remaining_to_take <= 0:
			break

		var taken_from_bucket = bucket.take_passengers_for_line(line_id, remaining_to_take)
		total_taken += taken_from_bucket
		remaining_to_take -= taken_from_bucket

	_cleanup_empty_buckets()

	return total_taken


func process(_delta: float) -> void:
	if _lines.size() == 0:
		return

	var clock = _game_manager.clock.get_time()

	_check_for_bored_passengers(clock)

	if _spawn_timer > 0.0:
		_spawn_timer -= _delta
		return

	_spawn_timer = TransportConstants.PASSENGER_SPAWN_INTERVAL_DELTA

	var spawn_chance = get_effective_spawn_chance(clock)
	var random_value = randi() % 100

	if float(random_value) < spawn_chance:
		_spawn_passengers(clock)

func reset() -> void:
	_buckets.clear()
	_spawn_timer = TransportConstants.PASSENGER_SPAWN_INTERVAL_DELTA

func _check_for_bored_passengers(clock: ClockTime) -> void:
	_cleanup_empty_buckets()

	var lowest_time_till_bored = get_lowest_till_bored_time(clock)

	if lowest_time_till_bored > 0:
		return

	var first_bucket: PassengerBucketEntry = _buckets[0] if _buckets.size() > 0 else null

	if first_bucket != null:
		var bored_passengers = first_bucket.get_total_passengers()
		_apply_boredom_penalty(bored_passengers)
		_buckets.remove_at(0)
		_cleanup_empty_buckets()


func _spawn_passengers(clock: ClockTime) -> void:
	var passenger_range = get_effective_passenger_spawn_range(clock)

	var num_passengers = randi() % (passenger_range[1] - passenger_range[0] + 1) + passenger_range[0]

	var next_passenger_count = get_total_waiting() + num_passengers

	if next_passenger_count > _max_passenger_count:
		num_passengers = max(0, _max_passenger_count - get_total_waiting())

	if num_passengers <= 0:
		return

	var target_lines = _find_target_lines(clock)
	if target_lines.size() == 0:
		return

	var base_passengers_per_line = int(num_passengers / target_lines.size())
	var remainder_passengers = num_passengers % target_lines.size()

	var bucket = PassengerBucketEntry.new(clock.to_time_of_day())

	for i in target_lines.size():
		var line = target_lines[i]
		var passengers_for_line = base_passengers_per_line

		if i < remainder_passengers:
			passengers_for_line += 1

		if passengers_for_line > 0:
			bucket.add_passengers_for_line(line.id, passengers_for_line)

	if bucket.get_total_passengers() <= 0:
		return

	_buckets.append(bucket)


func _cleanup_empty_buckets() -> void:
	while _buckets.size() > 0:
		var first_bucket: PassengerBucketEntry = _buckets[0] as PassengerBucketEntry

		if first_bucket == null or first_bucket.get_total_passengers() <= 0:
			_buckets.remove_at(0)
			continue

		break


func _get_frame_for_hour(clock: ClockTime) -> PresetFrameDefinition:
	var current_time_of_day = clock.to_time_of_day()
	var current_minutes = current_time_of_day.to_minutes()

	var selected_frame: PresetFrameDefinition = null
	var best_minutes = -1

	for frame_def in _demand_preset.frames as Array[PresetFrameDefinition]:
		var frame_minutes = frame_def.hour.to_minutes()

		if frame_minutes <= current_minutes and frame_minutes >= best_minutes:
			best_minutes = frame_minutes
			selected_frame = frame_def

	if selected_frame != null:
		return selected_frame

	# Wrap to the last frame of the day if all frame hours are after current time.
	for frame_def in _demand_preset.frames as Array[PresetFrameDefinition]:
		var frame_minutes = frame_def.hour.to_minutes()

		if frame_minutes >= best_minutes:
			best_minutes = frame_minutes
			selected_frame = frame_def

	return selected_frame


func _find_target_lines(clock: ClockTime) -> Array[TransportLine]:
	var target_lines: Array[TransportLine] = []
	var current_time = clock.to_time_of_day()

	for line in _lines:
		var next_departure = _get_next_departure(line, current_time)

		if next_departure == null:
			continue

		var time_till_departure = current_time.minutes_until(next_departure.departure_time)

		if time_till_departure > TransportConstants.PASSENGER_BEFORE_BUS_ARRIVAL_TIME:
			continue

		target_lines.append(line)

	return target_lines


func _get_next_departure(line: TransportLine, clock: TimeOfDay) -> StopDeparture:
	var departures: Array = []

	if _is_terminal:
		departures = line.get_departures_at_terminal(_target_id, clock, -1, false)
	else:
		departures = line.get_departures_at_stop(_target_id, clock, -1, false)

	if departures.size() == 0:
		return null

	var best_departure: StopDeparture = null
	var best_minutes: int = 1441

	for departure in departures:
		var stop_departure = departure as StopDeparture
		if stop_departure == null:
			continue

		var minutes_to_departure = clock.minutes_until(stop_departure.departure_time)
		if minutes_to_departure < best_minutes:
			best_minutes = minutes_to_departure
			best_departure = stop_departure

	if best_departure != null:
		return best_departure

	return null


func _apply_boredom_penalty(bored_passengers: int) -> void:
	if _score_manager == null:
		return

	_score_manager.update_score(ChallengeEnums.ScoreReason.BORED_PASSENGER, bored_passengers)
