extends Node2D

@onready var SceneTransitionAnimation = $SceneTransitionAnimation/AnimationPlayer
@onready var player_camera = $Player/Camera2D
@onready var boss_trigger = $BossTrigger

@export var watcher_scene: PackedScene
@export var mushroom_scene: PackedScene
@export var skeleton_boss_scene: PackedScene
@export var warp_point_scene: PackedScene
@export var boss_scene: PackedScene
@export var warp_scene: PackedScene

var boss_defeated: bool = false
var boss_spawned: bool = false
var boss_position: Vector2

# --- ENEMY SPAWN POINTS ---

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	SceneTransitionAnimation.get_parent().get_node("ColorRect").color.a = 255
	SceneTransitionAnimation.play("fade_out")
	player_camera.enabled = true
	
# Called every frame
func _process(_delta: float) -> void:
	if not Global.playerAlive:
		Global.gameStarted = false
		SceneTransitionAnimation.play("fade_in")
		call_deferred("_return_to_lobby")

# Safely handle returning to lobby
func _return_to_lobby() -> void:
	await get_tree().create_timer(0.5).timeout
	get_tree().change_scene_to_file("res://Scenes/lobby_level.tscn")

# --- Boss trigger handling ---
func _on_boss_trigger_body_entered(body: Node) -> void:
	if body.name == "Player" and not boss_defeated:
		boss_trigger.call_deferred("set", "monitoring", false)
		boss_position = $BossSpawnPoint.global_position
		var boss = boss_scene.instantiate()
		boss.global_position = boss_position
		call_deferred("add_child", boss)
		boss.boss_defeated.connect(_on_boss_defeated)

func _on_boss_defeated(_boss_position: Vector2) -> void:
	print("Boss defeated! Spawning warp at:", boss_position)
	var warp = warp_point_scene.instantiate()
	add_child(warp)
	warp.global_position = boss_position
	boss_defeated = true
