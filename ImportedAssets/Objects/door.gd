extends StaticBody2D

@onready var anim = get_node("AnimationPlayer")


func _on_area_2d_body_entered(_body):
	if self.name in Global.key_found:
		anim.play("Open")
		await get_node("AnimationPlayer").animation_finished
		queue_free()
		
	if not self.name in Global.key_found:
		anim.play("Locked")
