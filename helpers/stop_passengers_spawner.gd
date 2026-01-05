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


func _init(target_id: int, is_terminal: bool, lines: Array, demand_preset: DemandPresetDefinition, max_passenger_count: int) -> void:
	_target_id = target_id
	_is_terminal = is_terminal
	_demand_preset = demand_preset
	_max_passenger_count = max_passenger_count

	for line_id in lines:
		var line = _transport_manager.get_line(line_id)
		if line != null:
			_lines.append(line)


func get_total_waiting() -> int:
	var total: int = 0

	for bucket in _buckets:
		total += bucket.get_total_passengers()

	return total


func get_lowest_till_bored_time(clock: ClockTime) -> int:
	var first_bucket: PassengerBucketEntry = _buckets[0] if _buckets.size() > 0 else null

	if first_bucket == null:
		return get_boredom_time()

	var creation_time = first_bucket.get_creation_time()
	var current_time = clock.to_time_of_day()

	var minutes_waited = current_time.to_minutes() - creation_time.to_minutes()

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


func take_passengers_for_line(line_id: int, count: int) -> int:
	var total_taken: int = 0
	var remaining_to_take: int = count

	for bucket in _buckets:
		if remaining_to_take <= 0:
			break

		var taken_from_bucket = bucket.take_passengers_for_line(line_id, remaining_to_take)
		total_taken += taken_from_bucket
		remaining_to_take -= taken_from_bucket

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


func _check_for_bored_passengers(clock: ClockTime) -> void:
	var lowest_time_till_bored = get_lowest_till_bored_time(clock)

	if lowest_time_till_bored > 0:
		return

	var first_bucket: PassengerBucketEntry = _buckets[0] if _buckets.size() > 0 else null

	if first_bucket != null:
		_buckets.remove_at(0)


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

	var passengers_per_line = int(num_passengers / target_lines.size())

	var bucket = PassengerBucketEntry.new(clock.to_time_of_day())

	for i in target_lines.size():
		var line = target_lines[i]

		bucket.add_passengers_for_line(line.id, passengers_per_line)

	_buckets.append(bucket)


func _get_frame_for_hour(clock: ClockTime) -> PresetFrameDefinition:
	var current_time_of_day = clock.to_time_of_day()

	for frame_def in _demand_preset.frames as Array[PresetFrameDefinition]:
		if frame_def.hour.to_minutes() <= current_time_of_day.to_minutes():
			return frame_def

	return null


func _find_target_lines(clock: ClockTime) -> Array[TransportLine]:
	var target_lines: Array[TransportLine] = []
	var current_time = clock.to_time_of_day()

	for line in _lines:
		var next_departure = _get_next_departure(line, current_time)

		if next_departure == null:
			continue

		var time_till_departure = next_departure.departure_time.to_minutes() - current_time.to_minutes()

		if time_till_departure < 0 or time_till_departure > TransportConstants.PASSENGER_BEFORE_BUS_ARRIVAL_TIME:
			continue

		target_lines.append(line)

	return target_lines


func _get_next_departure(line: TransportLine, clock: TimeOfDay) -> StopDeparture:
	var departures: Array = []

	if _is_terminal:
		departures = line.get_departures_at_terminal(_target_id, clock, 1, false)
	else:
		departures = line.get_departures_at_stop(_target_id, clock, 1, false)

	if departures.size() > 0:
		return departures[0] as StopDeparture

	return null
