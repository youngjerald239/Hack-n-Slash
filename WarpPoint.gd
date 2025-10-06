extends RigidBody2D

@export var target_scene: String = "res://Scenes/lobby_level.tscn"
@export var gravity_scale_ex: float = 1.0
@onready var sprite: AnimatedSprite2D = $PropsevilDoor
@onready var landing_particles: GPUParticles2D = $LandingParticles   # optional, can be null
@onready var player_camera: Camera2D = $"../Player/Camera2D"      # adjust path

# --- Tuning ---
@export var bounce_damping: float = 0.3    # 0 = no bounce
@export var landing_animation: String = "Land"
@export var camera_shake_strength: float = 12.0
@export var camera_shake_duration: float = 0.25

var has_landed: bool = false

func _ready() -> void:
	# Apply gravity scale override
	gravity_scale = gravity_scale_ex

	# Enable collision reporting
	contact_monitor = true
	max_contacts_reported = 8

	# Keep upright
	lock_rotation = true

	# Play fall animation initially
	if sprite:
		sprite.play("Fall")

	# Connect body_entered signal
	if not is_connected("body_entered", Callable(self, "_on_body_entered")):
		connect("body_entered", Callable(self, "_on_body_entered"))

# Physics callback for RigidBody2D
func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if has_landed:
		return

	var contact_count := state.get_contact_count()
	if contact_count == 0:
		return

	for i in range(contact_count):
		var normal := state.get_contact_local_normal(i)
		# Normal roughly pointing up = floor
		if normal.dot(Vector2(0, -1)) > 0.6:
			_on_landed()
			break

func _on_landed() -> void:
	if has_landed:
		return
	has_landed = true

	# Small bounce effect
	linear_velocity = Vector2(linear_velocity.x, -linear_velocity.y * bounce_damping)

	# Play landing animation
	if sprite and landing_animation != "":
		sprite.play(landing_animation)

	# Trigger landing particles
	if landing_particles:
		landing_particles.emitting = true

	# Trigger camera shake
	if player_camera:
		if player_camera.has_method("start_shake"):
			player_camera.call_deferred("start_shake", camera_shake_strength, camera_shake_duration)

	# Freeze body after landing
	call_deferred("_freeze_warp")

func _freeze_warp() -> void:
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	freeze = true   # locks motion

func _on_body_entered(body: Node) -> void:
	# Only warp if the warp has settled on the ground
	if not has_landed:
		return

	# Accept player (CharacterBody2D or group)
	if body.is_in_group("Player") or body is CharacterBody2D:
		call_deferred("_warp_player")

func _warp_player() -> void:
	if target_scene == "":
		return

	var tree := get_tree()
	if tree:
		tree.change_scene_to_file(target_scene)
	else:
		push_warning("SceneTree not available to change scene.")

	# Cleanup
	queue_free()

# Optional: for Area2D detection if used
func _on_area_2d_body_entered(body: Node2D) -> void:
	if not has_landed:
		return
	if body.is_in_group("Player") or body is CharacterBody2D:
		call_deferred("_warp_player")
