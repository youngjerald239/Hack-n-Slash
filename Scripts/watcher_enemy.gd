extends CharacterBody2D
class_name WatcherEnemy

# --- Movement / AI ---
const speed = 30
var dir: Vector2 = Vector2.ZERO
var is_watcher_chase: bool = true
var is_roaming: bool = true
var player: CharacterBody2D

# --- Health / Damage ---
var health: int = 20
var health_max: int = 20
var dead: bool = false
var taking_damage: bool = false
var damage_to_deal: int = 10

# --- Knockback support ---
var knockback: Vector2 = Vector2.ZERO
@export var knockback_resistance: float = 1.0
@export var knockback_recovery: float = 8.0

# --- Setup ---
func _ready() -> void:
	add_to_group("enemies")   # essential for tornado detection

# --- Main process ---
func _process(delta: float) -> void:
	Global.watcherDamageAmount = damage_to_deal
	Global.watcherDamageZone = $WatcherDealDamageArea

	if Global.playerAlive:
		is_watcher_chase = true
	else:
		is_watcher_chase = false

	if is_on_floor() and dead:
		await get_tree().create_timer(3.0).timeout
		queue_free()

	move(delta)
	handle_animations()

# --- Movement / AI ---
func move(delta: float) -> void:
	player = Global.playerBody

	if not dead:
		is_roaming = true
		if not taking_damage and is_watcher_chase and Global.playerAlive:
			velocity = position.direction_to(player.position) * speed
			dir.x = abs(velocity.x) / velocity.x
		elif taking_damage:
			var knockback_dir = position.direction_to(player.position) * -50
			velocity = knockback_dir
		else:
			velocity += dir * speed * delta

		# --- Apply tornado knockback on top of normal movement ---
		velocity += knockback
		knockback = knockback.lerp(Vector2.ZERO, clamp(knockback_recovery * delta, 0.0, 1.0))
	else:
		velocity.y += 10 * delta
		velocity.x = 0

	move_and_slide()

# --- AI helper ---
func _on_timer_timeout():
	$Timer.wait_time = choose([0.5, 0.8])
	if not is_watcher_chase:
		dir = choose([Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN])

func handle_animations():
	var animated_sprite = $AnimatedSprite2D
	if not dead and not taking_damage:
		animated_sprite.play("Fly")
		if dir.x == 1:
			animated_sprite.flip_h = false
		elif dir.x == -1:
			animated_sprite.flip_h = true
	elif not dead and taking_damage:
		animated_sprite.play("Hit")
		await get_tree().create_timer(0.8).timeout
		taking_damage = false
	elif dead and is_roaming:
		is_roaming = false
		animated_sprite.play("Death")
		set_collision_layer_value(1, true)
		set_collision_layer_value(2, false)
		set_collision_mask_value(1, true)
		set_collision_mask_value(2, false)

func choose(array):
	array.shuffle()
	return array.front()

# --- Damage handling ---
func _on_watcher_hit_box_area_entered(area):
	if area == Global.playerDamageZone:
		var damage = Global.playerDamageAmount
		take_damage(damage)

func take_damage(damage: int) -> void:
	health -= damage
	taking_damage = true
	if health <= 0:
		health = 0
		dead = true

# --- Tornado / external knockback ---
func apply_knockback(force: Vector2) -> void:
	# Called by tornado or other attacks
	knockback += force * knockback_resistance
