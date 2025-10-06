extends Area2D
class_name DeathZone

# --- Configuration ---
@export var death_sound: AudioStream = null
@export var kill_player: bool = true
@export var kill_enemies: bool = true
@export var player_respawn_time: float = 2.0
@export var enemy_respawn_time: float = 2.0
@export var camera_shake_strength: float = 8.0
@export var camera_shake_duration: float = 0.25

# --- Nodes ---
@onready var audio_player: AudioStreamPlayer2D = $AudioStreamPlayer2D if has_node("AudioStreamPlayer2D") else null

func _ready() -> void:
	monitoring = true
	connect("body_entered", Callable(self, "_on_body_entered"))

func _on_body_entered(body: Node) -> void:
	if not is_instance_valid(body):
		return

	# --- Player ---
	if kill_player and body.is_in_group("Player"):
		if body.has_method("take_damage"):
			body.take_damage(9999)  # fatal damage
			_play_death_sound(body.global_position)
			_camera_shake(body)
			_deferred_respawn(body, player_respawn_time)
		return

	# --- Enemies ---
	if kill_enemies and body.is_in_group("enemies"):
		if body.has_method("take_damage"):
			body.take_damage(9999)  # fatal damage
			_play_death_sound(body.global_position)
			_deferred_respawn(body, enemy_respawn_time)
		return

func _play_death_sound(pos: Vector2) -> void:
	if death_sound and audio_player:
		audio_player.global_position = pos
		audio_player.stream = death_sound
		audio_player.play()

func _camera_shake(player: Node) -> void:
	if player.has_node("Camera2D"):
		var cam: Camera2D = player.get_node("Camera2D")
		var tween = cam.create_tween()
		tween.tween_property(cam, "offset", Vector2(randf_range(-camera_shake_strength, camera_shake_strength), randf_range(-camera_shake_strength, camera_shake_strength)), camera_shake_duration)
		tween.tween_property(cam, "offset", Vector2.ZERO, camera_shake_duration)

func _deferred_respawn(body: Node, wait_time: float) -> void:
	if not is_instance_valid(body):
		return
	var spawn_pos: Vector2 = body.global_position
	# Hide body immediately
	body.visible = false
	body.set_process(false)
	body.set_physics_process(false)

	# Wait then respawn
	var timer = Timer.new()
	timer.one_shot = true
	timer.wait_time = wait_time
	add_child(timer)
	timer.start()

	# Use a lambda to pass the parameters safely
	timer.timeout.connect(func():
		_respawn_body(body, spawn_pos, timer)
	)

func _respawn_body(body: Node, spawn_pos: Vector2, timer: Timer) -> void:
	if not is_instance_valid(body):
		return
	body.global_position = spawn_pos
	body.visible = true
	body.set_process(true)
	body.set_physics_process(true)
	timer.queue_free()
