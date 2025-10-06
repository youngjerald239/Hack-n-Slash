extends Area2D
class_name AirSlash

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

# --- Ownership ---
var owner_type: String = ""   # "player" or "enemy"
var owner_ref: Node = null    # who spawned this slash

# --- Movement & Combat ---
@export var damage: int = 10
@export var knockback_force: float = 400.0
@export var speed: float = 400.0
@export var camera_shake_strength: float = 5.0
@export var camera_shake_time: float = 0.15
var direction: Vector2 = Vector2.RIGHT

func _ready() -> void:
	monitoring = true
	if sprite:
		sprite.play("Travel")

	if not is_connected("body_entered", Callable(self, "_on_body_entered")):
		connect("body_entered", Callable(self, "_on_body_entered"))

func _physics_process(delta: float) -> void:
	position += direction.normalized() * speed * delta

func _on_body_entered(body: Node) -> void:
	if body == owner_ref:
		return

	# Collide with Tornado, stop, but no damage
	if "Tornado" in body.get_class() or body.is_in_group("Tornado"):
		_trigger_impact()
		return

	if owner_type == "player" and body.is_in_group("enemies"):
		if body.has_method("take_damage"):
			body.take_damage(damage)
		if body.has_method("apply_knockback"):
			var kb_dir = (body.global_position - global_position).normalized()
			body.apply_knockback(kb_dir * knockback_force)
		_trigger_impact()

	elif owner_type == "enemy" and (body.is_in_group("Player") or body is CharacterBody2D):
		if body.has_method("take_damage"):
			body.take_damage(damage)
		if body.has_method("apply_knockback"):
			var kb_dir = (body.global_position - global_position).normalized()
			body.apply_knockback(kb_dir * knockback_force)
		_trigger_impact()
		
	# Hit any blocking object (like tornado)
	elif body is RigidBody2D or body is CharacterBody2D or (body.is_in_group("blocking")):
		direction = Vector2.ZERO   # stop movement
		# Treat as obstacle, stop air slash
		_trigger_impact()

func _trigger_impact() -> void:
	if sprite:
		sprite.play("Impact")

	set_deferred("monitoring", false)
	for child in get_children():
		if child is CollisionShape2D:
			child.set_deferred("disabled", true)

	# Smooth camera shake
	_shake_camera()

	await sprite.animation_finished
	queue_free()

# --- Helper: smooth camera shake ---
func _shake_camera() -> void:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return

	var original_pos: Vector2 = cam.position
	var elapsed: float = 0.0
	var timer := Timer.new()
	timer.one_shot = false
	timer.wait_time = 0.016 # ~60 FPS
	add_child(timer)
	timer.start()

	timer.timeout.connect(func():
		if cam == null:
			timer.queue_free()
			return

		@warning_ignore("confusable_capture_reassignment")
		elapsed += timer.wait_time
		var decay: float = 1.0 - min(elapsed / camera_shake_time, 1.0)
		var offset: Vector2 = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * camera_shake_strength * decay
		cam.position = original_pos + offset

		if elapsed >= camera_shake_time:
			cam.position = original_pos
			timer.stop()
			timer.queue_free()
	)
