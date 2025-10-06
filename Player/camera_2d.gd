extends Camera2D

# --- Shake parameters ---
var shake_amount: float = 0.0
var shake_time: float = 0.0
var shake_decay: float = 1.0

var original_position: Vector2

func _ready() -> void:
	original_position = position

func _process(delta: float) -> void:
	if shake_time > 0.0:
		shake_time -= delta
		var _offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake_amount
		position = original_position + offset
		shake_amount = lerp(shake_amount, 0.0, shake_decay * delta)
	else:
		position = original_position

# Call this to trigger a camera shake
func start_shake(amount: float, duration: float) -> void:
	shake_amount = amount
	shake_time = duration
	shake_decay = amount / duration  # ensures smooth decay over time

# Helper
func randf_range(min_val: float, max_val: float) -> float:
	return randf() * (max_val - min_val) + min_val
