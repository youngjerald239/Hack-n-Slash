extends CharacterBody2D
class_name SkeletonBoss

# -- Tuning --
const SPEED := 50.0
const GRAVITY := 900.0
@export var damage_to_deal: int = 20
@export var melee_range: float = 64.0
@export var attack_cooldown: float = 1.2

# Scenes
@export var air_slash_scene: PackedScene     # assign Air_Slash.tscn
@export var warp_point_scene: PackedScene    # assign WarpPoint.tscn

# State
var health: int = 200
var max_health: int = 200
var dead: bool = false
var taking_damage: bool = false
var is_attacking: bool = false
var has_spawned_projectile: bool = false
var attack_cd_left: float = 0.0

# Knockback
var knockback: Vector2 = Vector2.ZERO
@export var knockback_resistance: float = 0.9
@export var knockback_recovery: float = 8.0

# Refs
var player: CharacterBody2D
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var damage_area: Area2D = $Skel_boss_DealDamageArea
@onready var damage_shape: CollisionShape2D = $Skel_boss_DealDamageArea/CollisionShape2D
@onready var hitbox: Area2D = $AnimatedSprite2D/Skel_boss_hitbox # boss's hurtbox (connects to player attacks)

signal boss_defeated(boss_position: Vector2)

func _ready() -> void:
	add_to_group("enemies")
	player = Global.playerBody

	# Signals
	sprite.frame_changed.connect(_on_sprite_frame_changed)
	sprite.animation_finished.connect(_on_animation_finished)
	hitbox.area_entered.connect(_on_hitbox_area_entered)
	damage_area.body_entered.connect(_on_damage_area_body_entered)

	# Start state
	sprite.play("Idle")
	damage_area.monitoring = false
	if damage_shape:
		damage_shape.disabled = true

func _physics_process(delta: float) -> void:
	if dead:
		return

	# gravity
	if not is_on_floor():
		velocity.y += GRAVITY * delta

	# cooldown tick
	if attack_cd_left > 0.0:
		attack_cd_left = max(0.0, attack_cd_left - delta)

	# update player ref
	player = Global.playerBody

	if taking_damage or is_attacking:
		velocity.x = 0.0
	else:
		_chase_and_maybe_attack()

	# apply knockback
	velocity += knockback
	knockback = knockback.lerp(Vector2.ZERO, clamp(knockback_recovery * delta, 0.0, 1.0))

	move_and_slide()

func _chase_and_maybe_attack() -> void:
	if player == null or not is_instance_valid(player):
		sprite.play("Idle")
		return

	var to_player := player.global_position - global_position
	var dir: int = int(sign(to_player.x))
	velocity.x = dir * SPEED

	# flip & keep damage area in front
	sprite.flip_h = (dir < 0.0)
	damage_area.position.x = -40.0 if sprite.flip_h else 40.0

	# choose animation
	if abs(velocity.x) > 0.1:
		sprite.play("Walk")
	else:
		sprite.play("Idle")

	# pick attack if cooled down
	if attack_cd_left == 0.0:
		var dist := to_player.length()
		if dist <= melee_range:
			_start_attack(1 if randf() < 0.5 else 2)
		elif health <= max_health / 2.0:
			# only use ranged at 50% HP or lower
			_start_attack(3)

func _start_attack(which: int) -> void:
	is_attacking = true
	has_spawned_projectile = false
	match which:
		1: sprite.play("Attack1")
		2: sprite.play("Attack2")
		3: sprite.play("Attack3")

# ---------- Damage intake (from player) ----------
func _on_hitbox_area_entered(area: Area2D) -> void:
	if area == Global.playerDamageZone and not taking_damage and not dead:
		take_damage(Global.playerDamageAmount)

func take_damage(amount: int) -> void:
	if dead:
		return
	health -= amount

	# Cancel attack if currently attacking
	if is_attacking:
		is_attacking = false
		has_spawned_projectile = false
		damage_area.call_deferred("set_monitoring", false)
		if damage_shape:
			damage_shape.set_deferred("disabled", true)

	taking_damage = true
	sprite.play("Hurt")

	if health <= 0:
		_die()
		return

	await sprite.animation_finished
	await get_tree().create_timer(0.3).timeout
	taking_damage = false


# ---------- Damage out (to player) ----------
func _on_damage_area_body_entered(body: Node) -> void:
	if not is_attacking:
		return
	if body == Global.playerBody and Global.playerBody and Global.playerBody.has_method("take_damage"):
		Global.playerBody.take_damage(damage_to_deal)

# ---------- Attack frame windows ----------
func _on_sprite_frame_changed() -> void:
	# Automatically flip attack area to face the same way as sprite
	damage_area.position.x = 40.0 if not sprite.flip_h else -40.0

	match sprite.animation:
		"Attack1":
			# Activate attack only on frames 2,3,4
			var active := sprite.frame in [2, 3, 4]
			damage_area.call_deferred("set_monitoring", active)
			if damage_shape:
				damage_shape.call_deferred("set_disabled", not active)

		"Attack2":
			# Activate attack on frames 3,4,5
			var active := sprite.frame in [3, 4, 5]
			damage_area.call_deferred("set_monitoring", active)
			if damage_shape:
				damage_shape.call_deferred("set_disabled", not active)

		"Attack3":
			# Spawn air slash on frame 2
			if sprite.frame == 2 and not has_spawned_projectile:
				_spawn_air_slash()
				has_spawned_projectile = true
			# No direct melee hit for this attack
			damage_area.call_deferred("set_monitoring", false)
			if damage_shape:
				damage_shape.call_deferred("set_disabled", true)

		_:
			# Disable attack area for all other animations
			damage_area.call_deferred("set_monitoring", false)
			if damage_shape:
				damage_shape.call_deferred("set_disabled", true)


func _spawn_air_slash() -> void:
	if air_slash_scene == null:
		return

	var slash = air_slash_scene.instantiate() as AirSlash
	slash.owner_type = "enemy"
	slash.owner_ref = self
	var x_off = -20 if sprite.flip_h else 20
	slash.global_position = global_position + Vector2(x_off, -10)
	slash.direction = Vector2.LEFT if sprite.flip_h else Vector2.RIGHT
	slash.scale = Vector2(4,4)

	get_tree().current_scene.add_child(slash)


# ---------- Animation end resets ----------
func _on_animation_finished() -> void:
	match sprite.animation:
		"Hurt":
			if not dead:
				sprite.play("Idle")

		"Attack1", "Attack2", "Attack3":
			is_attacking = false
			has_spawned_projectile = false
			damage_area.monitoring = false
			if damage_shape:
				damage_shape.set_deferred("disabled", true)
			sprite.play("Idle")
			attack_cd_left = attack_cooldown

		"Death":
			pass

# ---------- Knockback API ----------
func apply_knockback(force: Vector2) -> void:
	knockback += force * knockback_resistance

# ---------- Death & warp spawn ----------
func _die() -> void:
	dead = true
	sprite.play("Death")
	await get_tree().create_timer(1.5).timeout

	# Spawn warp
	var warp: Node2D = null
	if warp_point_scene:
		warp = warp_point_scene.instantiate()
		warp.global_position = global_position
		get_tree().current_scene.call_deferred("add_child", warp)

	# Try to get the player's Camera2D node (may be a custom camera)
	var player_cam: Camera2D = null
	if Global.playerBody and Global.playerBody.has_node("Camera2D"):
		player_cam = Global.playerBody.get_node("Camera2D") as Camera2D

	# Create a temporary, clean Camera2D and add to the scene
	var temp_cam := Camera2D.new()
	# Position it at player's camera (if present) or at boss position
	if player_cam:
		# use the existing global_position of player's camera if available
		if ("global_position" in player_cam): # quick safe check for property name presence
			temp_cam.global_position = player_cam.global_position
		else:
			temp_cam.global_position = Global.playerBody.global_position if Global.playerBody else global_position
	else:
		temp_cam.global_position = Global.playerBody.global_position if Global.playerBody else global_position

	get_tree().current_scene.add_child(temp_cam)
	# Make the temp camera current (Camera2D has make_current())
	if temp_cam.has_method("make_current"):
		temp_cam.make_current()
	else:
		# fallback: set 'current' property if the engine exposes it on this object
		temp_cam.set("current", true)

	# Smooth pan to warp (if warp exists), hold, then pan back to player
	if warp:
		var tween_to = get_tree().create_tween()
		tween_to.tween_property(temp_cam, "global_position", warp.global_position, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		await tween_to.finished

		# hold on warp for 2s
		await get_tree().create_timer(2.0).timeout

		# determine where to return (prefer player's camera position, then player position)
		var return_pos: Vector2 = global_position
		if player_cam and ("global_position" in player_cam):
			return_pos = player_cam.global_position
		elif Global.playerBody:
			return_pos = Global.playerBody.global_position

		var tween_back = get_tree().create_tween()
		tween_back.tween_property(temp_cam, "global_position", return_pos, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		await tween_back.finished

	# Restore player's camera to auto-follow
	if player_cam:
		if player_cam.has_method("make_current"):
			player_cam.make_current()
		else:
			# fallback attempt — many custom cameras still accept set("current", true)
			player_cam.set("current", true)

	# Clean up temporary camera
	if is_instance_valid(temp_cam):
		temp_cam.queue_free()

	# Unlock air slash for player if needed
	if Global.playerBody and Global.playerBody.has_method("unlock_air_slash"):
		Global.playerBody.unlock_air_slash()

	emit_signal("boss_defeated", global_position)
	call_deferred("queue_free")
