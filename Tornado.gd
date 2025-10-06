extends StaticBody2D
class_name Tornado

@export var rise_speed: float = -120.0
@export var duration: float = 2.0
@export var jump_boost: float = -500.0
@export var knockback_force: float = 1800.0
@export var enter_impulse: float = 800.0
@export var deals_damage: bool = true
@export var damage_amount: int = 10

@onready var area: Area2D = get_node("Area2D")

var _damaged_enemies := {}
var _players_inside := {}
var _enemies_inside := {}

func _ready():
	# Auto-destroy tornado after duration
	get_tree().create_timer(duration).timeout.connect(queue_free)
	area.monitoring = true
	area.monitorable = true

func _physics_process(delta: float) -> void:
	var bodies = area.get_overlapping_bodies()
	for b in bodies:
		if b.is_in_group("player"):
			if not _players_inside.has(b):
				_players_inside[b] = true
				if "velocity" in b:
					b.velocity.y = jump_boost
			b.global_position.y += rise_speed * delta

		elif b.is_in_group("enemies"):
			var dir = (b.global_position - global_position).normalized()
			if not _enemies_inside.has(b):
				_enemies_inside[b] = true
				if b.has_method("apply_knockback"):
					b.apply_knockback(dir * enter_impulse)
			if b.has_method("apply_knockback"):
				b.apply_knockback(dir * (knockback_force * delta))
			elif "velocity" in b:
				b.velocity += dir * (knockback_force * delta)
			elif b is RigidBody2D:
				b.apply_central_impulse(dir * (knockback_force * delta))
			if deals_damage and not _damaged_enemies.has(b):
				if b.has_method("take_damage"):
					b.take_damage(damage_amount)
				_damaged_enemies[b] = true

	for p in _players_inside.keys():
		if p not in bodies:
			_players_inside.erase(p)
	for e in _enemies_inside.keys():
		if e not in bodies:
			_enemies_inside.erase(e)
