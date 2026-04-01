class_name CasterCollection

enum CasterID {
	CLOSE,
	MEDIUM,
	LONG,
	LEFT,
	RIGHT,
}

const KEYS: Array[CasterID] = [CasterID.CLOSE, CasterID.MEDIUM, CasterID.LONG, CasterID.LEFT, CasterID.RIGHT]

var close: RayCast2D
var medium: RayCast2D
var long: RayCast2D
var left: RayCast2D
var right: RayCast2D

var _array_cache: Array[RayCast2D] = []
var _caster_check_ordered_cache: Array[RayCast2D] = []


func _init(_close: RayCast2D, _medium: RayCast2D, _long: RayCast2D, _left: RayCast2D, _right: RayCast2D) -> void:
	self.close = _close
	self.medium = _medium
	self.long = _long
	self.left = _left
	self.right = _right

	self._array_cache = [close, medium, long, left, right]
	self._caster_check_ordered_cache = [close, left, right, medium, long]


func get_by_id(caster_id: CasterID) -> RayCast2D:
	match caster_id:
		CasterID.CLOSE:
			return close
		CasterID.MEDIUM:
			return medium
		CasterID.LONG:
			return long
		CasterID.LEFT:
			return left
		CasterID.RIGHT:
			return right

	push_error("Unknown caster ID: %s" % caster_id)
	return null


func keys() -> Array[CasterID]:
	return KEYS


func values() -> Array[RayCast2D]:
	return _array_cache


func get_in_check_order() -> Array[RayCast2D]:
	return _caster_check_ordered_cache


func set_all_enabled(enabled: bool) -> void:
	close.set_enabled(enabled)
	medium.set_enabled(enabled)
	long.set_enabled(enabled)
	left.set_enabled(enabled)
	right.set_enabled(enabled)


class CasterIndicatorCollection:
	var close: Node2D
	var medium: Node2D
	var long: Node2D
	var left: Node2D
	var right: Node2D

	var _array_cache: Array[Node2D] = []


	func _init(_close: Node2D, _medium: Node2D, _long: Node2D, _left: Node2D, _right: Node2D) -> void:
		self.close = _close
		self.medium = _medium
		self.long = _long
		self.left = _left
		self.right = _right

		self._array_cache = [close, medium, long, left, right]


	func keys() -> Array[CasterID]:
		return KEYS


	func values() -> Array[Node2D]:
		return _array_cache
