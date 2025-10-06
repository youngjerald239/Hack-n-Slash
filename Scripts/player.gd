extends CharacterBody2D
class_name Player

# --- Nodes ---
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var deal_damage_zone: Area2D = $DealDamageZone
@onready var damage_shape: CollisionShape2D = $DealDamageZone/CollisionShape2D
@export var tornado_scene: PackedScene = preload("res://Scenes/Tornado.tscn")
var air_slash_scene: PackedScene = preload("res://Enemies/Skeleton/Air_Slash.tscn")

# --- Knockback ---
var knockback: Vector2 = Vector2.ZERO
@export var knockback_resistance: float = 0.8
@export var knockback_recovery: float = 10.0

# --- Constants ---
const SPEED: float = 200.0
const JUMP_VELOCITY: float = -350.0
const GRAVITY: float = 900.0

# --- Dash ---
var is_dashing: bool = false
var can_dash: bool = true
const DASH_SPEED: float = 1000.0
const DASH_TIME: float = 0.20
const DASH_COOLDOWN: float = 0.5
const DASH_FREEZE_TIME: float = 0.05
const TRAIL_INTERVAL: float = 0.03  # spawn more rapidly

# --- State ---
var attack_type: String = ""
var current_attack: bool = false
var health: int = 100
var dead: bool = false
var can_take_damage: bool = true
var can_spawn_tornado: bool = false
var on_tornado: Tornado = null
var has_air_slash: bool = false

# --- Setup ---
func _enter_tree() -> void:
	Global.playerBody = self

func _ready() -> void:
	Global.playerAlive = true
	Global.playerBody = self
	Global.playerHitbox = $PlayerHitbox if has_node("PlayerHitbox") else Global.playerHitbox
	Global.playerDamageZone = deal_damage_zone
	Global.playerDamageAmount = Global.playerDamageAmount if Global.playerDamageAmount != null else 8

	if "player_health" in Global:
		health = Global.player_health
	else:
		Global.player_health = health

	has_air_slash = Global.has_air_slash
	can_spawn_tornado = Global.tornado_unlocked
	if Global.tornado_scene != null:
		tornado_scene = Global.tornado_scene

	damage_shape.disabled = true
	sprite.frame_changed.connect(_on_frame_changed)
	sprite.animation_finished.connect(_on_animation_finished)

# -------------------- PHYSICS / MOVEMENT --------------------
func _physics_process(delta: float) -> void:
	Global.playerDamageZone = deal_damage_zone
	Global.playerHitbox = $PlayerHitbox if has_node("PlayerHitbox") else Global.playerHitbox

	velocity += knockback
	knockback = knockback.lerp(Vector2.ZERO, clamp(knockback_recovery * delta, 0.0, 1.0))

	if dead:
		move_and_slide()
		return

	if is_dashing:
		move_and_slide()
		return

	if not is_on_floor():
		velocity.y += GRAVITY * delta

	if not current_attack:
		var direction = Input.get_axis("MoveLeft", "MoveRight")
		if direction != 0:
			velocity.x = direction * SPEED
		else:
			velocity.x = move_toward(velocity.x, 0, SPEED)

	if Input.is_action_just_pressed("Jump"):
		if is_on_floor():
			velocity.y = JUMP_VELOCITY
		elif on_tornado != null:
			velocity.y = on_tornado.jump_boost
			on_tornado = null

	if not current_attack:
		if Input.is_action_just_pressed("Attack"):
			if is_on_floor():
				start_attack("single_attack")
			else:
				start_attack("air_attack")
		elif Input.is_action_just_pressed("AltAttack") and is_on_floor():
			start_attack("double_attack")

	if can_spawn_tornado and Input.is_action_just_pressed("special"):
		spawn_tornado()

	if has_air_slash and Input.is_action_just_pressed("air_slash"):
		_cast_air_slash()

	if Input.is_action_just_pressed("Dash") and can_dash and not is_dashing:
		start_dash()

	handle_movement_animations(velocity.x)
	move_and_slide()

	if is_on_floor() and not is_dashing:
		can_dash = true

# -------------------- ATTACKS --------------------
func start_attack(type: String) -> void:
	current_attack = true
	attack_type = type
	sprite.frame = 0
	sprite.play(type)

	match type:
		"single_attack":
			Global.playerDamageAmount = 8
		"double_attack":
			Global.playerDamageAmount = 16
		"air_attack":
			Global.playerDamageAmount = 20

func _on_frame_changed() -> void:
	if not current_attack:
		return

	match sprite.animation:
		"single_attack":
			damage_shape.set_deferred("disabled", sprite.frame != 6)
		"double_attack":
			damage_shape.set_deferred("disabled", not (sprite.frame in [4,5,12,13]))
		"air_attack":
			damage_shape.set_deferred("disabled", sprite.frame != 4)

func _on_animation_finished() -> void:
	if current_attack:
		damage_shape.set_deferred("disabled", true)
		current_attack = false
		attack_type = ""

# -------------------- MOVEMENT ANIMATIONS --------------------
func handle_movement_animations(direction: float) -> void:
	if current_attack:
		return

	if is_on_floor():
		if velocity.x == 0:
			sprite.play("Idle")
		else:
			sprite.play("Run")
			toggle_flip_sprite(direction)
	else:
		if velocity.y < 0:
			sprite.play("Jump")
		else:
			sprite.play("Fall")

func toggle_flip_sprite(direction: float) -> void:
	if direction > 0:
		sprite.flip_h = false
		deal_damage_zone.position.x = 29
	elif direction < 0:
		sprite.flip_h = true
		deal_damage_zone.position.x = -40

# -------------------- DAMAGE --------------------
func take_damage(damage: int) -> void:
	if not can_take_damage or dead or damage <= 0:
		return

	health -= damage
	Global.player_health = health

	sprite.frame = 0
	sprite.play("Hit")
	await get_tree().create_timer(0.5).timeout

	if health <= 0:
		health = 0
		dead = true
		handle_death_animation()
	else:
		take_damage_cooldown(1.0)

func take_damage_cooldown(wait_time: float) -> void:
	can_take_damage = false
	await get_tree().create_timer(wait_time).timeout
	can_take_damage = true

func handle_death_animation() -> void:
	sprite.frame = 0
	sprite.play("Death")
	await get_tree().create_timer(0.5).timeout
	$Camera2D.zoom.x = 4
	await get_tree().create_timer(3.0).timeout
	Global.playerAlive = false
	await get_tree().create_timer(0.5).timeout
	queue_free()

# --- DASH ---
func start_dash() -> void:
	if not can_dash or dead:
		return

	is_dashing = true
	can_dash = false

	# Freeze before dash
	velocity = Vector2.ZERO
	await get_tree().create_timer(DASH_FREEZE_TIME).timeout

	# Dash direction
	var dash_dir = Input.get_axis("MoveLeft", "MoveRight")
	if dash_dir == 0:
		dash_dir = -1 if sprite.flip_h else 1

	# Dash velocity
	velocity.x = dash_dir * DASH_SPEED
	sprite.frame = 0
	sprite.play("Dash")

	# Spawn trail Timer node
	var trail_timer := Timer.new()
	trail_timer.wait_time = TRAIL_INTERVAL
	trail_timer.one_shot = false
	add_child(trail_timer)
	# safe connect using Callable
	trail_timer.timeout.connect(Callable(self, "_spawn_dash_trail"))
	trail_timer.start()

	# Dash duration
	await get_tree().create_timer(DASH_TIME).timeout

	# End dash
	velocity.x = 0
	is_dashing = false

	# Stop & free trail timer safely (no explicit disconnect required)
	if is_instance_valid(trail_timer):
		trail_timer.stop()
		# freeing the timer will remove its connections
		trail_timer.queue_free()

	# Cooldown
	await get_tree().create_timer(DASH_COOLDOWN).timeout
	if is_on_floor():
		can_dash = true


# -------------------- DASH TRAIL --------------------
func _spawn_dash_trail() -> void:
	# create ghost sprite
	var ghost := Sprite2D.new()

	# try to get the current frame texture from AnimatedSprite2D
	var frames: SpriteFrames = sprite.sprite_frames
	var tex: Texture2D = null
	if frames and frames.has_animation(sprite.animation):
		tex = frames.get_frame_texture(sprite.animation, sprite.frame)

	if tex:
		ghost.texture = tex

	ghost.flip_h = sprite.flip_h
	# place ghost at player's global position so it draws in world coords
	ghost.global_position = global_position
	ghost.scale = sprite.scale
	ghost.modulate = Color(0.4, 0.6, 1.0, 0.6)  # bluish, semi-transparent
	# ensure it renders above tiles/player (adjust as needed)
	ghost.z_index = sprite.z_index + 1

	# parent to the current scene (safer when changing scenes)
	var parent_node := get_tree().current_scene
	if parent_node:
		parent_node.add_child(ghost)
	else:
		add_child(ghost) # fallback

	# fade & smear tween, then free safely
	var tween := get_tree().create_tween()
	tween.tween_property(ghost, "modulate:a", 0.0, 0.25)
	tween.tween_property(ghost, "scale", ghost.scale * Vector2(1.15, 1.15), 0.25)

	# safe callback: check instance validity before queue_free()
	tween.tween_callback(func() -> void:
		if is_instance_valid(ghost):
			ghost.queue_free()
	)




# -------------------- Knock Back --------------------
func apply_knockback(force: Vector2) -> void:
	knockback += force * knockback_resistance

# -------------------- SPECIAL ABILITY --------------------
func enable_tornado_power(scene: PackedScene) -> void:
	Global.tornado_unlocked = true
	Global.tornado_scene = scene
	can_spawn_tornado = true
	if scene != null:
		tornado_scene = scene

func spawn_tornado() -> void:
	if not can_spawn_tornado or tornado_scene == null:
		push_warning("Cannot spawn tornado.")
		return

	var tornado = tornado_scene.instantiate()
	get_tree().current_scene.add_child(tornado)

	var spawn_distance = 50
	var spawn_offset = Vector2(spawn_distance, 0)
	if sprite.flip_h:
		spawn_offset.x *= -1
	var feet_offset = Vector2(0, -20)
	tornado.global_position = global_position + spawn_offset + feet_offset

func set_on_tornado(tornado: Tornado):
	on_tornado = tornado

func apply_tornado_boost(boost: float):
	if on_tornado:
		velocity.y = boost

func unlock_air_slash() -> void:
	Global.has_air_slash = true
	has_air_slash = true
	print("Player unlocked Air Slash!")

func _cast_air_slash() -> void:
	if not has_air_slash or air_slash_scene == null:
		return

	start_attack("single_attack")  # play attack animation

	var slash = air_slash_scene.instantiate() as AirSlash
	slash.owner_type = "player"
	slash.owner_ref = self
	slash.direction = Vector2.LEFT if sprite.flip_h else Vector2.RIGHT
	slash.global_position = global_position + Vector2(-30 if sprite.flip_h else 30, -10)
	slash.scale = Vector2(2,2) # optional visual scale

	get_tree().current_scene.add_child(slash)
