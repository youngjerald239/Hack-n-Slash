extends CharacterBody2D
class_name MushroomEnemy

const SPEED = 50
const GRAVITY = 900
const mushroom_scene = preload("res://Enemies/Mushroom/mushroom.tscn")

# --- NEW knockback system ---
var knockback: Vector2 = Vector2.ZERO
@export var knockback_resistance: float = 0.9 # higher = resists more
@export var knockback_recovery: float = 8.0   # how quickly it fades out
# ----------------------------

var is_mushroom_chase: bool = true
var is_roaming: bool = true
var dir: Vector2 = Vector2.ZERO

var health = 80
var health_max = 80
var knockback_force = -40
var dead: bool = false
var taking_damage: bool = false
var damage_to_deal = 20
var is_dealing_damage: bool = false
var player: CharacterBody2D
var player_in_area = false

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D 
@onready var floor_check: RayCast2D = get_node_or_null("FloorCheck")
@onready var wall_check: RayCast2D = get_node_or_null("WallCheck")
@onready var damage_area: Area2D = $AnimatedSprite2D/MshrmDealDamageArea
@onready var damage_shape: CollisionShape2D = $AnimatedSprite2D/MshrmDealDamageArea/CollisionShape2D


func _ready():
	add_to_group("enemies")   # essential so tornado can detect it
	sprite.play("Idle")
	sprite.frame_changed.connect(_on_sprite_frame_changed)
	dir = choose([Vector2.RIGHT, Vector2.LEFT, Vector2.ZERO]) # random start direction

func _physics_process(delta):
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	
	Global.MshrmDamageAmount = damage_to_deal
	Global.MshrmDamageZone = damage_area
	player = Global.playerBody

	# --- stop logic during hurt/attack/death ---
	if dead or taking_damage or is_dealing_damage:
		velocity.x = 0
		move_and_slide()
		return

	# --- chase mode ---
	if is_mushroom_chase:
		sprite.play("Walk")
		var dir_to_player = position.direction_to(player.position) * SPEED
		sprite.flip_h = dir_to_player.x < 0
		velocity.x = dir_to_player.x
	else:
		# roaming / patrolling
		velocity.x = dir.x * SPEED
		if dir == Vector2.ZERO:
			sprite.play("Idle")
		else:
			sprite.play("Walk")
			sprite.flip_h = dir.x < 0

		# edge/wall detection
		if dir != Vector2.ZERO and floor_check and wall_check:
			floor_check.target_position.x = dir.x * 10
			wall_check.target_position.x = dir.x * 10
			if not floor_check.is_colliding() or wall_check.is_colliding():
				dir.x *= -1
				
	# --- apply knockback on top of AI movement ---
	velocity += knockback
	knockback = knockback.lerp(Vector2.ZERO, clamp(knockback_recovery * delta, 0.0, 1.0))

	move_and_slide()
		
# --- Called externally (from tornado or player attack) ---
func apply_knockback(force: Vector2) -> void:
	knockback += force * knockback_resistance
		
func spawn_minions():
	if not mushroom_scene:
		print("Mushroom scene not assigned in inspector!")
		return

	for i in range(2):
		var new_mushroom = mushroom_scene.instantiate()
		get_parent().add_child(new_mushroom)
		# Position them slightly offset from this mushroom
		new_mushroom.global_position = global_position + Vector2(40 * (i * 2 - 1), 0)

func _on_direction_timer_timeout():
	# pick a new random roaming direction (can idle too)
	dir = choose([Vector2.RIGHT, Vector2.LEFT, Vector2.ZERO])
	$DirectionTimer.wait_time = choose([0.5, 0.8, 0.5])

func choose(array):
	array.shuffle()
	return array.front()


func _on_mushroom_hitbox_area_entered(area):
	var damage = Global.playerDamageAmount
	if area == Global.playerDamageZone:
		take_damage(damage)
		
func take_damage(damage):
	health -= damage
	taking_damage = true
	if not dead:
		sprite.play("Hurt")
		await get_tree().create_timer(0.8).timeout
		taking_damage = false
	print(str(self), "current health is ", health)
	if health <= 0:
		health = 0
		die()
	elif health <= health_max * 0.1 and not is_dealing_damage: # below 10%
		is_dealing_damage = true
		sprite.play("Attack3")
		await get_tree().create_timer(1.0).timeout
		spawn_minions()
		is_dealing_damage = false
	elif dead and is_roaming:
		is_roaming = false
	elif !dead and is_dealing_damage:
		sprite.play("deal_damage")
		
func die():
	dead = true
	sprite.play("Death")
	await get_tree().create_timer(1.0).timeout
	self.queue_free()  # remove this mushroom
	
func _on_animated_sprite_2d_animation_finished():
	match sprite.animation:
		"Hurt":
			taking_damage = false
			sprite.play("Idle")
		"Attack3":
			spawn_minions()
			is_dealing_damage = false
			sprite.play("Idle")
		"deal_damage":
			is_dealing_damage = false
			sprite.play("Idle")   # reset here so it never freezes
		"Death":
			queue_free()


func _on_mshrm_deal_damage_area_area_entered(area):
	if area == Global.playerHitbox and not is_dealing_damage:
		is_dealing_damage = true
		sprite.play("deal_damage")
		await sprite.animation_finished   # wait for attack animation to finish
		is_dealing_damage = false
		sprite.play("Idle")               # return to Idle (or Walk if chasing)
		
func apply_attack_damage():
	var p = Global.playerBody
	if p != null and is_instance_valid(p):
		if p.has_method("take_damage"):
			p.take_damage(damage_to_deal)
		else:
			push_warning("Player exists but has no take_damage() method. Did Player.gd compile?")
	else:
		push_warning("Global.playerBody is null or invalid at damage time")
		
func _on_sprite_frame_changed():
	if sprite.animation == "deal_damage":
		# Enable damage Area2D only on frames 6 and 7
		if sprite.frame in [6, 7]:
			damage_area.set_deferred("monitoring", true)
			damage_shape.set_deferred("disabled", false)
			apply_attack_damage()
		else:
			damage_area.set_deferred("monitoring", false)
			damage_shape.set_deferred("disabled", true)
