extends Area2D

@export var feet_depth_px: float = 8.0
@export var knee_depth_px: float = 28.0
@export var chest_depth_px: float = 56.0

@export var slowdown_multiplier_knee: float = 0.6
@export var slowdown_multiplier_feet: float = 0.85
@export var swim_multiplier: float = 0.5

@export var buoyancy_force: float = -200.0
@export var splash_on_enter: bool = true
@export var splash_on_exit: bool = true

#@onready var splash_particles: Node = has_node("SplashParticles") ? get_node("SplashParticles") : null

# tracks bodies currently inside this water area
var _inside: Dictionary = {}

func _ready() -> void:
	monitoring = true
	connect("body_entered", Callable(self, "_on_body_entered"))
	connect("body_exited", Callable(self, "_on_body_exited"))
	set_physics_process(true)

func _on_body_entered(body: Node) -> void:
	# only track valid physics bodies
	if not is_instance_valid(body):
		return
	_inside[body] = true
	_update_body_state(body, true)

func _on_body_exited(body: Node) -> void:
	if _inside.has(body):
		_inside.erase(body)
		_reset_body(body)
		#if splash_on_exit and is_instance_valid(body):
			#_spawn_splash(body.global_position)

func _physics_process(delta: float) -> void:
	# iterate over a copy of keys (bodies may be freed during loop)
	for b in _inside.keys():
		if not is_instance_valid(b):
			_inside.erase(b)
			continue
		_update_body_state(b, false, delta)

func _update_body_state(body: Node, entering: bool=false, delta: float=0.0) -> void:
	# compute the surface Y:
	var surface_y: float = global_position.y
	if has_node("SurfaceMarker"):
		surface_y = get_node("SurfaceMarker").global_position.y
	else:
		var cs: CollisionShape2D = get_node_or_null("CollisionShape2D")
		if cs and cs.shape and cs.shape is RectangleShape2D:
			var rect_extents: Vector2 = (cs.shape as RectangleShape2D).extents
			# Area2D position is the center; surface is center.y - extents.y
			surface_y = global_position.y - rect_extents.y

	# submersion: positive when body is below surface
	var submersion: float = body.global_position.y - surface_y
	if submersion < 0.0:
		submersion = 0.0

	# classify depth state
	var state: String = "none"
	if submersion <= 0.0:
		state = "none"
	elif submersion < feet_depth_px:
		state = "feet"
	elif submersion < knee_depth_px:
		state = "knee"
	else:
		state = "chest"

	# initial entry splash
	#if entering and splash_on_enter:
		#_spawn_splash(body.global_position + Vector2(0, feet_depth_px))

	# prefer explicit API on bodies (cleanest)
	if body.has_method("update_water"):
		# body handles effects itself
		body.update_water(submersion, state, self)
		return

	# CharacterBody2D fallback support
	if body is CharacterBody2D:
		var cb: CharacterBody2D = body as CharacterBody2D

		# notify entry if body provides enter_water
		if entering and cb.has_method("enter_water"):
			cb.enter_water(self)

		# provide submersion & state if supported
		if cb.has_method("set_water_submersion"):
			cb.set_water_submersion(submersion, state)
		else:
			# fallback: create/overwrite 'water_speed_multiplier' property so movement code can use it
			if state == "feet":
				cb.set_deferred("water_speed_multiplier", slowdown_multiplier_feet)
			elif state == "knee":
				cb.set_deferred("water_speed_multiplier", slowdown_multiplier_knee)
			elif state == "chest":
				cb.set_deferred("water_speed_multiplier", swim_multiplier)
			else:
				cb.set_deferred("water_speed_multiplier", 1.0)

		# simple buoyancy: nudge upward if submerged at least a little
		if submersion >= feet_depth_px:
			if cb.has_method("apply_knockback"):
				cb.apply_knockback(Vector2(0.0, buoyancy_force * delta))
			else:
				# fallback touching CharacterBody2D.velocity safely
				cb.velocity = Vector2(cb.velocity.x, min(cb.velocity.y, buoyancy_force * delta))

func _reset_body(body: Node) -> void:
	if not is_instance_valid(body):
		return

	if body.has_method("exit_water"):
		body.call_deferred("exit_water", self)
		return

	# fallback: reset multiplier if we set it earlier
	if body is CharacterBody2D:
		var cb: CharacterBody2D = body as CharacterBody2D
		cb.set_deferred("water_speed_multiplier", 1.0)

#func _spawn_splash(position: Vector2) -> void:
	#if not splash_particles:
		#return
	# position & emit particles
	#splash_particles.global_position = position
	# restart emitter safely
	#splash_particles.emitting = false
	#splash_particles.set_deferred("emitting", true)
