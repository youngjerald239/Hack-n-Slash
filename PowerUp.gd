extends Area2D

@export var tornado_scene : PackedScene

func _ready():
	connect("body_entered", Callable(self, "_on_body_entered"))

func _on_body_entered(body):
	if body.is_in_group("Player"):
		if body.has_method("enable_tornado_power"):
			body.enable_tornado_power(tornado_scene)
		queue_free()
