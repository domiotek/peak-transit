extends RefCounted

class_name BuildingsManager

var RESIDENTIAL_BUILDING_SCENE = load("res://game-objects/buildings/spawner-buildings/residential-building/residential_building.tscn")
var COMMERCIAL_BUILDING_SCENE = load("res://game-objects/buildings/spawner-buildings/commercial-building/commercial_building.tscn")
var INDUSTRIAL_BUILDING_SCENE = load("res://game-objects/buildings/spawner-buildings/industrial-building/industrial_building.tscn")

var buildings: Dictionary = {}

func register_building(building: BaseBuilding) -> int:
	var id = _get_next_id()

	if buildings.has(id):
		push_error("Building ID collision detected for ID %d" % id)
		return -1
	
	buildings[id] = building

	return id

func create_spawner_building(info: BuildingInfo) -> SpawnerBuilding:
	var id = _get_next_id()

	if buildings.has(id):
		push_error("Building ID collision detected for ID %d" % id)
		return null

	var building: SpawnerBuilding = null

	match info.Type:
		BaseBuilding.BuildingType.RESIDENTIAL:
			building = RESIDENTIAL_BUILDING_SCENE.instantiate() as SpawnerBuilding
		BaseBuilding.BuildingType.COMMERCIAL:
			building = COMMERCIAL_BUILDING_SCENE.instantiate() as SpawnerBuilding
		BaseBuilding.BuildingType.INDUSTRIAL:
			building = INDUSTRIAL_BUILDING_SCENE.instantiate() as SpawnerBuilding
		_:
			push_error("Unsupported building type: %s" % str(info.Type))
			return null
	building.id = id
	buildings[id] = building
	return building


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

func get_random_building_with_constraints(of_type: BaseBuilding.BuildingType, other_than: int) -> BaseBuilding:
	var building_list = buildings.values()
	if building_list.size() == 0:
		return null

	var filtered_list = building_list.filter(func(building): return building.type == of_type and building.id != other_than)
	
	if filtered_list.size() == 0:
		return null

	var random_index = randi() % filtered_list.size()
	return filtered_list[random_index]

func get_random_building_type(other_than: BaseBuilding.BuildingType) -> BaseBuilding.BuildingType:
	var types = BaseBuilding.BuildingType.values()
	types.erase(other_than)

	if types.size() == 0:
		return other_than
	var random_index = randi() % types.size()
	return types[random_index]


func _get_next_id() -> int:
	var max_id = -1
	for building_id in buildings.keys():
		if building_id > max_id:
			max_id = building_id
	return max_id + 1
