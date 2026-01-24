extends RefCounted

class_name BuildingsManager

var ResidentialBuildingScene = load("res://game-objects/buildings/spawner-buildings/residential-building/residential_building.tscn")
var CommercialBuildingScene = load("res://game-objects/buildings/spawner-buildings/commercial-building/commercial_building.tscn")
var IndustrialBuildingScene = load("res://game-objects/buildings/spawner-buildings/industrial-building/industrial_building.tscn")

var buildings: Dictionary = { }
var _ids_manager: IDManager = IDManager.new()


func register_building(building: BaseBuilding) -> int:
	var id = _ids_manager.occupy_next_id()

	if buildings.has(id):
		push_error("Building ID collision detected for ID %d" % id)
		return -1

	buildings[id] = building

	return id


func create_spawner_building(info: BuildingInfo) -> SpawnerBuilding:
	var id = _ids_manager.occupy_next_id()

	if buildings.has(id):
		push_error("Building ID collision detected for ID %d" % id)
		return null

	var building: SpawnerBuilding = null

	match info.type:
		BuildingInfo.BuildingType.RESIDENTIAL:
			building = ResidentialBuildingScene.instantiate() as SpawnerBuilding
		BuildingInfo.BuildingType.COMMERCIAL:
			building = CommercialBuildingScene.instantiate() as SpawnerBuilding
		BuildingInfo.BuildingType.INDUSTRIAL:
			building = IndustrialBuildingScene.instantiate() as SpawnerBuilding
		_:
			push_error("Unsupported building type: %s" % str(info.type))
			return null
	building.id = id
	building.building_info = info
	buildings[id] = building
	return building


func destroy_building(building_id: int) -> void:
	if buildings.has(building_id):
		buildings[building_id].queue_free()
		buildings.erase(building_id)
		_ids_manager.release_id(building_id)
	else:
		push_error("Attempted to destroy non-existent building with ID %d." % building_id)


func get_building(building_id: int) -> BaseBuilding:
	if buildings.has(building_id):
		return buildings[building_id]

	push_error("Building with ID %d not found." % building_id)
	return null


func get_buildings() -> Array:
	return buildings.values()


func get_random_building() -> BaseBuilding:
	var building_list = buildings.values()
	if building_list.size() == 0:
		return null
	var random_index = randi() % building_list.size()
	return building_list[random_index]


func get_random_building_with_constraints(of_type: BuildingInfo.BuildingType, other_than: int) -> BaseBuilding:
	var building_list = buildings.values()
	if building_list.size() == 0:
		return null

	var filtered_list = building_list.filter(func(building): return building.type == of_type and building.id != other_than)

	if filtered_list.size() == 0:
		return null

	var random_index = randi() % filtered_list.size()
	return filtered_list[random_index]


func get_random_building_type(other_than: BuildingInfo.BuildingType, weights: Dictionary = { }) -> BuildingInfo.BuildingType:
	var types = BuildingInfo.BuildingType.values()
	types.erase(other_than)

	if types.size() == 0:
		return other_than

	if weights.size() > 0:
		var total_weight = 0
		for weight in weights.values():
			total_weight += weight

		var random_value = randi() % total_weight
		for building_type in weights.keys():
			random_value -= weights[building_type]
			if random_value < 0:
				return building_type

	var random_index = randi() % types.size()
	return types[random_index]


func clear_state() -> void:
	buildings.clear()
	_ids_manager.reset()
