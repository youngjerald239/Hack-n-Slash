extends Object
class_name Room

@export var pos : Vector2i
@export var size : Vector2i

func get_center() -> Vector2i:
	return pos + size / 2
