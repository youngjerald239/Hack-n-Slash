extends Node

# --- Game / flow state ---
var gameStarted: bool = false
var current_wave: int = 0
var moving_to_next_wave: bool = false

# --- Player references & persistent stats ---
var playerBody: CharacterBody2D = null
var playerAlive: bool = true
var playerHitbox: Area2D = null
var playerDamageZone: Area2D = null
var playerDamageAmount: int = 8
var player_health: int = 100

# --- Persistent unlocked skills ---
var tornado_unlocked: bool = false
var tornado_scene: PackedScene = null    # store the tornado PackedScene so it persists
var has_air_slash: bool = false

# --- Enemy damage refs (kept for compatibility) ---
var watcherDamageZone: Area2D = null
var watcherDamageAmount: int = 0

var MshrmDamageZone: Area2D = null
var MshrmDamageAmount: int = 0

var SkelDamageZone: Area2D = null
var SkelDamageAmount: int = 0

# --- Misc ---
var Gold: int = 0
var key_found: Array = []
