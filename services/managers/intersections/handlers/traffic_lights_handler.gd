extends RefCounted

class_name TrafficLightsIntersectionHandler

var stoppers: Array = []


func setup(_node: RoadNode, new_stoppers: Array) -> void:
	stoppers = new_stoppers



func process_tick(_delta: float) -> void:
	pass