extends Camera2D

# Look-ahead horizontal (reduzido)
@export var look_ahead_x_max: float = 36.0
@export var look_ahead_x_lerp_speed: float = 5.0

# Vertical (reduzido)
@export var base_y_bias: float = 6.0
@export var look_up_y: float = -6.0
@export var look_down_y: float = 14.0
@export var vertical_lerp_speed: float = 4.0
@export var vel_y_threshold: float = 60.0

# Sensibilidade: não mover offset em baixa velocidade (anti “micro jitter”)
@export var min_speed_for_lookahead: float = 60.0

var _facing_sign: int = 1

func _ready() -> void:
	make_current()

func _physics_process(delta: float) -> void:
	var player := get_parent() as CharacterBody2D
	if player == null:
		return

	if abs(player.velocity.x) > 1.0:
		_facing_sign = 1 if player.velocity.x >= 0.0 else -1

	# --- speed01 mais “calmo” e com zona morta ---
	var speed_x: float = abs(player.velocity.x)
	var max_for_scale: float = 260.0 # aumenta pra reduzir sensibilidade (antes 220)

	var t: float = 0.0
	if speed_x > min_speed_for_lookahead:
		t = clamp((speed_x - min_speed_for_lookahead) / (max_for_scale - min_speed_for_lookahead), 0.0, 1.0)

	# Smoothstep (reduz “nervosismo” perto do zero)
	var speed01: float = t * t * (3.0 - 2.0 * t)

	var target_x: float = float(_facing_sign) * look_ahead_x_max * speed01

	var target_y: float = base_y_bias
	if player.velocity.y < -vel_y_threshold:
		target_y += look_up_y
	elif player.velocity.y > vel_y_threshold:
		target_y += look_down_y

	var new_offset := offset
	new_offset.x = lerp(new_offset.x, target_x, clamp(delta * look_ahead_x_lerp_speed, 0.0, 1.0))
	new_offset.y = lerp(new_offset.y, target_y, clamp(delta * vertical_lerp_speed, 0.0, 1.0))
	offset = new_offset
