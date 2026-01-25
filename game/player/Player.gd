extends CharacterBody2D

enum State {
	IDLE,
	ANDANDO,
	PULANDO,
	CAINDO,
	GLIDANDO,
	SWING_ROPE,
	DESLIZANDO,

	CARTWHEEL,          # attack/roll estilo DKC
	GROUND_POUND,       # descendo forte
	GROUND_POUND_LAND,  # trava curta no chão mantendo a animação

	MACHUCADO,
	MORTO
}

@export_group("Config")
@export var debug_print: bool = false
@export var stats: PlayerStats

@export_group("HP (MVP)")
@export var max_hp: int = 3
@export var invuln_seconds: float = 0.6
@export var hurt_lock_seconds: float = 0.25
@export var knockback_x: float = 220.0
@export var knockback_y: float = -170.0

@export_group("Attack (Cartwheel / DKC-like)")
@export var cartwheel_frames: int = 24          # duração do roll (frames)
@export var cartwheel_min_speed: float = 320.0  # garante “entra com força”
@export var cartwheel_max_speed: float = 460.0
@export var cartwheel_hit_speed_boost: float = 80.0  # boost ao acertar inimigo (e reseta timer)

@export_group("Ground Pound")
@export var ground_pound_start_speed: float = 260.0
@export var ground_pound_gravity_mult: float = 2.2
@export var ground_pound_max_fall: float = 650.0
@export var ground_pound_land_frames: int = 10  # “segura” animação no chão

# Nós
@onready var coyote_jump_timer: Timer = get_node_or_null("CoyoteTimer")
@onready var anim_sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D")
@onready var player_input: PlayerInput = get_node_or_null("PlayerInput")

# Estado
var state: State = State.IDLE
var is_alive: bool = true

# HP runtime
var hp: int = 0
var _invuln_left: float = 0.0
var _hurt_left: float = 0.0

# Run
var _is_running: bool = false

# Slide runtime
var _slide_speed: float = 0.0
var _slope_direction: int = 0

# Facing
var _facing: int = 1

# Coyote bookkeeping
var _was_on_floor: bool = false

# Attack runtime (ticks)
var _cartwheel_ticks_left: int = 0
var _bonus_jump_available: bool = false

# Ground pound runtime (ticks)
var _gp_land_ticks_left: int = 0

# Segurança
var _ok := true


func _ready() -> void:
	if stats == null:
		push_warning("Player.stats está vazio. Atribua um PlayerStats .tres no Inspector.")
		stats = PlayerStats.new()

	if coyote_jump_timer == null:
		push_error("Faltando Timer 'CoyoteTimer' como child do Player.")
		_disable_runtime()
		return

	if anim_sprite == null:
		push_error("Faltando AnimatedSprite2D 'AnimatedSprite2D' como child do Player.")
		_disable_runtime()
		return

	if player_input == null:
		push_error("Faltando PlayerInput 'PlayerInput' como child do Player.")
		_disable_runtime()
		return

	floor_snap_length = stats.floor_snap_length

	coyote_jump_timer.one_shot = true
	coyote_jump_timer.process_callback = Timer.TIMER_PROCESS_PHYSICS
	coyote_jump_timer.wait_time = stats.coyote_seconds

	player_input.configure_from_stats(stats)

	_slide_speed = stats.slide_speed_start
	_was_on_floor = is_on_floor()

	hp = max_hp
	is_alive = true
	state = State.IDLE


func _disable_runtime() -> void:
	_ok = false
	set_physics_process(false)
	set_process(false)


func _physics_process(delta: float) -> void:
	if not _ok:
		return

	# timers de dano
	if _invuln_left > 0.0:
		_invuln_left = maxf(0.0, _invuln_left - delta)
	if _hurt_left > 0.0:
		_hurt_left = maxf(0.0, _hurt_left - delta)
		if _hurt_left <= 0.0 and state == State.MACHUCADO and is_alive:
			state = State.IDLE

	# ticks (1 por physics frame)
	_tick_attack_and_gp()

	# morto: só física + animação
	if not is_alive or state == State.MORTO:
		_apply_gravity(delta * float(Engine.physics_ticks_per_second))
		move_and_slide()
		_play_animations()
		return

	# machucado: trava input, só física
	if state == State.MACHUCADO:
		_apply_gravity(delta * float(Engine.physics_ticks_per_second))
		move_and_slide()
		_post_move()
		_play_animations()
		return

	player_input.poll()
	var input := player_input.snapshot
	var dt_ticks := delta * float(Engine.physics_ticks_per_second)

	_update_facing(input.axis)
	_update_run_latch(input)

	# trava curta depois do ground pound (mantém animação no chão)
	if state == State.GROUND_POUND_LAND:
		velocity.x = 0.0
		velocity.y = 0.0
		move_and_slide()
		_post_move()
		_play_animations()
		return

	# inicia cartwheel (somente se não estiver travado em outro estado especial)
	if _can_start_cartwheel(input):
		_start_cartwheel()

	# inicia ground pound (no ar)
	if _can_start_ground_pound(input):
		_start_ground_pound()

	# atualiza estado “normal” (não pisa por cima de CARTWHEEL / GROUND_POUND)
	_update_state(input)

	match state:
		State.DESLIZANDO:
			_apply_slide(dt_ticks, input)
		State.CARTWHEEL:
			_apply_cartwheel(dt_ticks, input)
		State.GROUND_POUND:
			_apply_ground_pound(dt_ticks)
		_:
			_apply_walk(dt_ticks, input)

	_apply_jump_logic(input)

	if input.jump_released and velocity.y < 0.0:
		velocity.y *= stats.jump_cut_multiplier

	_apply_gravity(dt_ticks)
	move_and_slide()

	_handle_cartwheel_hits() # detecta hit em inimigo durante roll

	_post_move()
	_play_animations()

	if debug_print:
		print("vel:", velocity, " state:", state, " on_floor:", is_on_floor(), " hp:", hp, "/", max_hp)


func _tick_attack_and_gp() -> void:
	if _cartwheel_ticks_left > 0:
		_cartwheel_ticks_left -= 1

	if _gp_land_ticks_left > 0:
		_gp_land_ticks_left -= 1
		if _gp_land_ticks_left <= 0 and state == State.GROUND_POUND_LAND and is_alive:
			state = State.IDLE


func _update_facing(axis: int) -> void:
	if axis < 0:
		_facing = -1
	elif axis > 0:
		_facing = 1
	anim_sprite.flip_h = _facing < 0


func _update_run_latch(input: PlayerInput.Snapshot) -> void:
	if is_on_floor():
		_is_running = input.run_held
	else:
		if not input.run_held:
			_is_running = false


func _current_speed_cap(input: PlayerInput.Snapshot) -> float:
	var cap := stats.max_run_speed if _is_running else stats.max_walk_speed
	if not is_on_floor() and input.run_held and not _is_running:
		cap = maxf(cap, stats.max_walk_speed + stats.run_air_speed_bonus)
	return cap


func _update_state(input: PlayerInput.Snapshot) -> void:
	# estados “donos” do controle
	if state == State.CARTWHEEL:
		# se acabou o roll, volta para estados normais
		if _cartwheel_ticks_left <= 0:
			if is_on_floor():
				state = State.IDLE
			else:
				state = State.PULANDO if velocity.y < 0.0 else State.CAINDO
		return

	if state == State.GROUND_POUND:
		# quando tocar o chão, vira LAND
		if is_on_floor():
			state = State.GROUND_POUND_LAND
			_gp_land_ticks_left = max(1, ground_pound_land_frames)
		return

	# normal
	if is_on_floor():
		if _should_slide(input):
			state = State.DESLIZANDO
		elif absf(velocity.x) > 0.1:
			state = State.ANDANDO
		else:
			state = State.IDLE
		return

	if input.glide_held and velocity.y >= 0.0:
		state = State.GLIDANDO
	else:
		state = State.PULANDO if velocity.y < 0.0 else State.CAINDO


func _should_slide(input: PlayerInput.Snapshot) -> bool:
	if not is_on_floor():
		return false
	if not input.down_held:
		return false
	return absf(get_floor_angle()) > stats.slope_threshold


func _apply_walk(dt_ticks: float, input: PlayerInput.Snapshot) -> void:
	var cap := _current_speed_cap(input)

	var accel := stats.acceleration
	var friction := stats.friction

	if not is_on_floor():
		accel *= stats.air_accel_multiplier
		friction *= stats.air_friction_multiplier

	if input.axis != 0:
		velocity.x += accel * float(input.axis) * dt_ticks
		velocity.x = clampf(velocity.x, -cap, cap)
	else:
		_apply_friction(dt_ticks, friction)


func _apply_friction(dt_ticks: float, friction_factor: float) -> void:
	var t := _lerp_factor_per_ticks(friction_factor, dt_ticks)
	velocity.x = lerpf(velocity.x, 0.0, t)
	if absf(velocity.x) < stats.stop_threshold:
		velocity.x = 0.0


func _lerp_factor_per_ticks(base_t: float, ticks: float) -> float:
	var t := clampf(base_t, 0.0, 1.0)
	return 1.0 - pow(1.0 - t, maxf(0.0, ticks))


func _apply_slide(dt_ticks: float, input: PlayerInput.Snapshot) -> void:
	if not _should_slide(input):
		_slide_speed = stats.slide_speed_start
		return

	_slide_speed = minf(_slide_speed + stats.slide_acceleration * dt_ticks, stats.max_slide_speed)

	_slope_direction = int(signf(get_floor_normal().x))
	if _slope_direction == 0:
		_slope_direction = 1

	velocity.x = _slide_speed * float(_slope_direction) * stats.gravity
	anim_sprite.flip_h = _slope_direction < 0


# ---------------------------
# CARTWHEEL (Attack / Roll)
# ---------------------------
func _can_start_cartwheel(input: PlayerInput.Snapshot) -> bool:
	if state == State.GROUND_POUND or state == State.GROUND_POUND_LAND:
		return false
	if not is_on_floor():
		return false
	if not input.attack_pressed:
		return false
	return true


func _start_cartwheel() -> void:
	state = State.CARTWHEEL
	_cartwheel_ticks_left = max(1, cartwheel_frames)

	var target := cartwheel_min_speed * float(_facing)
	if absf(velocity.x) < absf(target):
		velocity.x = target


func _apply_cartwheel(_dt_ticks: float, input: PlayerInput.Snapshot) -> void:
	var dir := _facing
	if input.axis != 0:
		dir = input.axis
		_facing = dir
		anim_sprite.flip_h = _facing < 0

	var target := cartwheel_min_speed * float(dir)
	if absf(velocity.x) < absf(target):
		velocity.x = target
	velocity.x = clampf(velocity.x, -cartwheel_max_speed, cartwheel_max_speed)


func _handle_cartwheel_hits() -> void:
	if state != State.CARTWHEEL:
		return

	var count := get_slide_collision_count()
	for i in range(count):
		var col := get_slide_collision(i)
		var other := col.get_collider()
		if other == null:
			continue

		if other is Node and other.is_in_group("enemies"):
			_on_cartwheel_hit_enemy(other)


func _on_cartwheel_hit_enemy(enemy: Node) -> void:
	if enemy.has_method("take_damage"):
		enemy.call("take_damage", 1, _facing)
	elif enemy.has_method("die"):
		enemy.call("die")

	_cartwheel_ticks_left = max(1, cartwheel_frames)

	var boosted := absf(velocity.x) + cartwheel_hit_speed_boost
	velocity.x = clampf(boosted * float(_facing), -cartwheel_max_speed, cartwheel_max_speed)

	_bonus_jump_available = true


# ---------------------------
# GROUND POUND
# ---------------------------
func _can_start_ground_pound(input: PlayerInput.Snapshot) -> bool:
	if is_on_floor():
		return false
	if state == State.CARTWHEEL:
		return false
	if state == State.GROUND_POUND or state == State.GROUND_POUND_LAND:
		return false
	return input.down_pressed


func _start_ground_pound() -> void:
	state = State.GROUND_POUND
	velocity.x *= 0.6
	velocity.y = maxf(velocity.y, ground_pound_start_speed)


func _apply_ground_pound(dt_ticks: float) -> void:
	velocity.y += stats.gravity * ground_pound_gravity_mult * dt_ticks
	velocity.y = minf(velocity.y, ground_pound_max_fall)


# ---------------------------
# Pulo / Coyote / Bonus Jump
# ---------------------------
func _apply_jump_logic(input: PlayerInput.Snapshot) -> void:
	if not player_input.peek_jump():
		return

	if is_on_floor():
		player_input.consume_jump()
		_jump_now()
		return

	if coyote_jump_timer.time_left > 0.0:
		player_input.consume_jump()
		_jump_now()
		return

	if _bonus_jump_available:
		player_input.consume_jump()
		_bonus_jump_available = false
		_jump_now()
		return


func _jump_now() -> void:
	var mult := stats.run_jump_multiplier if _is_running else 1.0
	velocity.y = stats.jump_speed * mult


func _apply_gravity(dt_ticks: float) -> void:
	if is_on_floor():
		return

	if state == State.GLIDANDO:
		velocity.y += (stats.gravity / stats.glide_gravity_divisor) * dt_ticks
		velocity.y = minf(velocity.y, stats.max_glide_fall_speed)
	else:
		velocity.y += stats.gravity * dt_ticks
		velocity.y = minf(velocity.y, stats.max_fall_speed)


func _post_move() -> void:
	if is_on_wall():
		velocity.x = 0.0
	if is_on_ceiling():
		velocity.y = maxf(velocity.y, 0.0)

	if is_on_floor() and state != State.DESLIZANDO and state != State.GROUND_POUND_LAND:
		velocity.y = 0.0

	var now_on_floor := is_on_floor()
	if _was_on_floor and not now_on_floor and velocity.y >= 0.0:
		coyote_jump_timer.start()
	if now_on_floor and not _was_on_floor:
		coyote_jump_timer.stop()

	if now_on_floor and state != State.CARTWHEEL:
		_bonus_jump_available = false

	_was_on_floor = now_on_floor


# ---------------------------
# HP / Dano / Morte (MVP)
# ---------------------------
func take_damage(amount: int, from_dir: int) -> void:
	if not is_alive:
		return
	if _invuln_left > 0.0:
		return

	hp -= amount
	if hp <= 0:
		_die()
		return

	_invuln_left = invuln_seconds
	_hurt_left = hurt_lock_seconds
	state = State.MACHUCADO

	var dir := clampi(from_dir, -1, 1)
	if dir == 0:
		dir = -_facing
	velocity.x = knockback_x * float(dir)
	velocity.y = knockback_y


func heal(amount: int) -> void:
	hp = clampi(hp + amount, 0, max_hp)


func _die() -> void:
	is_alive = false
	state = State.MORTO
	velocity = Vector2.ZERO


# ---------------------------
# Animações (AnimatedSprite2D + SpriteFrames)
# ---------------------------
func _play_animations() -> void:
	if state == State.MORTO:
		_play_anim("death")
		return

	if state == State.MACHUCADO:
		_play_anim("hurt")
		return

	if state == State.CARTWHEEL:
		_play_anim("attack")
		return

	if state == State.GROUND_POUND or state == State.GROUND_POUND_LAND:
		_play_anim("ground_pound")
		return

	if is_on_floor():
		if state == State.DESLIZANDO and absf(get_floor_angle()) > stats.slope_threshold:
			_play_anim("slope_slide")
			return

		if absf(velocity.x) > 0.1:
			_play_anim("run" if _is_running else "walk")
			return

		_play_anim("idle")
		return

	if state == State.GLIDANDO:
		_play_anim("glide")
		return

	_play_anim("jump_up" if velocity.y < 0.0 else "jump_down")


func _play_anim(anim_name: String) -> void:
	if anim_sprite.animation == StringName(anim_name) and anim_sprite.is_playing():
		return

	if anim_sprite.sprite_frames == null or not anim_sprite.sprite_frames.has_animation(StringName(anim_name)):
		push_warning("SpriteFrames não tem animação: " + anim_name)
		return

	anim_sprite.play(StringName(anim_name))


func _on_coyote_timer_timeout() -> void:
	pass
