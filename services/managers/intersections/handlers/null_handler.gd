extends RefCounted

class_name NullIntersectionHandler

var CLASS_NAME = "NullIntersection"

var stoppers: Array = []


func setup(_node: RoadNode, new_stoppers: Array) -> void:
	stoppers = new_stoppers

	for stopper in new_stoppers:
		stopper.set_active(false)

func process_tick(_delta: float) -> void:
	pass