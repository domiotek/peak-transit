class_name BrigadeHelper

static func get_ongoing_trip(brigade: Brigade, current_time: TimeOfDay, vehicle_manager: VehicleManager = null) -> Dictionary:
	if not vehicle_manager:
		vehicle_manager = GDInjector.inject("VehicleManager") as VehicleManager

	var ongoing_trip = brigade.get_ongoing_trip(current_time)

	if ongoing_trip == null:
		return {
			"ongoing_trip": null,
			"next_stop_idx": null,
			"assigned_bus": null,
		}

	var assigned_bus_idx = brigade.get_vehicle_of_trip(ongoing_trip.idx)

	var next_stop_idx
	var assigned_bus
	var next_bus_stop

	if assigned_bus_idx != -1:
		if not vehicle_manager.vehicle_exists(assigned_bus_idx):
			brigade.unassign_vehicle(assigned_bus_idx)
			assigned_bus_idx = -1
		else:
			var bus = vehicle_manager.get_vehicle(assigned_bus_idx) as Vehicle

			var bus_ai = bus.ai as BusAI
			assigned_bus = bus
			next_bus_stop = bus_ai.get_next_stop()

	next_stop_idx = next_bus_stop.stop_idx if next_bus_stop != null else ongoing_trip.find_next_stop_after_time(current_time)

	return {
		"ongoing_trip": ongoing_trip,
		"next_stop_idx": next_stop_idx,
		"assigned_bus": assigned_bus,
	}


static func get_waiting_passengers(brigade: Brigade, trip: BrigadeTrip, next_stop_idx: int) -> Dictionary:
	var result: Dictionary = {
		"own_waiting": 0,
		"own_waiting_next_stop": 0,
		"total_waiting": 0,
		"total_waiting_next_stop": 0,
		"max_waiting": 0,
		"max_waiting_next_stop": 0,
	}

	var stops = trip.get_stops()

	for stop in stops.slice(next_stop_idx, stops.size()):
		var stop_interface = stop.get_stop_selection() as StopSelection
		var passenger_stats = stop_interface.get_passengers()

		result["own_waiting"] += passenger_stats.get_waiting_passengers_for_line(brigade.line_id)
		result["total_waiting"] += passenger_stats.get_total_waiting()
		result["max_waiting"] += passenger_stats.get_max_waiting()

		if stop.stop_idx == trip.get_stop(next_stop_idx).stop_idx:
			result["own_waiting_next_stop"] = result["own_waiting"]
			result["total_waiting_next_stop"] = result["total_waiting"]
			result["max_waiting_next_stop"] = result["max_waiting"]

	return result


static func get_average_traffic(network_manager: NetworkManager, line: TransportLine, trip: BrigadeTrip, next_stop_idx: int, serving_vehicle: Vehicle) -> float:
	var lanes = line.get_route_lanes(trip.get_route_id(), next_stop_idx - 1)

	var total_traffic = 0.0

	var target_lane: NetLane = null

	if serving_vehicle != null:
		var current_step = serving_vehicle.navigator.get_current_step()

		match current_step.type:
			Navigator.StepType.NODE:
				var endpoint = network_manager.get_lane_endpoint(current_step["to_endpoint"])
				var segment = network_manager.get_segment(endpoint.SegmentId) as NetSegment
				target_lane = segment.get_lane(endpoint.LaneId)
			Navigator.StepType.SEGMENT:
				var segment = network_manager.get_segment(current_step["segment_id"]) as NetSegment
				target_lane = segment.get_lane(current_step["lane_id"])
			Navigator.StepType.BUILDING:
				if current_step["is_entering"]:
					return 0.0

	var index_of_lane = lanes.find(target_lane)

	var sliced_lanes = lanes.slice(index_of_lane, lanes.size()) if index_of_lane != -1 else lanes

	for lane in sliced_lanes:
		total_traffic += lane.get_lane_usage()

	return total_traffic / sliced_lanes.size() if sliced_lanes.size() > 0 else 0.0
