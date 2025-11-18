class_name CasterCollection

const KEYS: Array[String] = ["close", "medium", "long", "left", "right"]

var close: RayCast2D
var medium: RayCast2D
var long: RayCast2D
var left: RayCast2D
var right: RayCast2D


func _init(_close: RayCast2D, _medium: RayCast2D, _long: RayCast2D, _left: RayCast2D, _right: RayCast2D) -> void:
	self.close = _close
	self.medium = _medium
	self.long = _long
	self.left = _left
	self.right = _right


func keys() -> Array[String]:
	return KEYS


func values() -> Array[RayCast2D]:
	return [close, medium, long, left, right]


class CasterIndicatorCollection:
	var close: Node2D
	var medium: Node2D
	var long: Node2D
	var left: Node2D
	var right: Node2D


	func _init(_close: Node2D, _medium: Node2D, _long: Node2D, _left: Node2D, _right: Node2D) -> void:
		self.close = _close
		self.medium = _medium
		self.long = _long
		self.left = _left
		self.right = _right


	func keys() -> Array[String]:
		return KEYS


	func values() -> Array[Node2D]:
		return [close, medium, long, left, right]
