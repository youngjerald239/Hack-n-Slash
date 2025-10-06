extends Area2D

func _ready():
	if self.name in Global.key_found:
		queue_free()

func _on_body_entered(body):
	if body.name == "Player":
		Global.key_found.append(self.name)
		Global.Gold += 20
		var tween = get_tree().create_tween()
		var tween1 = get_tree().create_tween()
		tween.tween_property(self, "position", position - Vector2(0, 50), .3)
		tween1.tween_property(self, "modulate:a", 0, .25)
		tween.tween_callback(queue_free)
		
