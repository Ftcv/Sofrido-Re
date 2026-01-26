# res://game/player/Player.gd
# Docs oficiais úteis (Godot 4.5):
# https://docs.godotengine.org/en/4.5/classes/class_characterbody2d.html
# https://docs.godotengine.org/en/4.5/classes/class_animatedsprite2d.html
# https://docs.godotengine.org/en/4.5/classes/class_area2d.html
# https://docs.godotengine.org/en/4.5/classes/class_input.html

extends CharacterBody2D

enum State {
	IDLE,
	ANDANDO,
	PULANDO,
	CAINDO,
	GLIDANDO,
	SWING_ROPE,
	DESLIZANDO,
	AGACHADO,
	GROUND_POUND,
	GROUND_POUND_LAND,
	CARTWHEEL,
	MACHUCADO,
	MORTO
}

@export_group("Config")
@export var debug_print: bool = false
@export var stats: PlayerStats

@export_group("HP (MVP)")
@export var max_hp: int = 3
@export var invuln_seconds: float = 0.60
@export var hurt_lock_seconds: float = 0.25
@export var knockback_x: float = 220.0
@export var knockback_y: float = -170.0

@export_group("Ground Pound (MVP)")
@export var ground_pound_start_speed: float = 250.0
@export var ground_pound_max_speed: float = 520.0
@export var ground_pound_gravity_multiplier: float = 2.0
@export var ground_pound_land_seconds: float = 0.16 # segura a animação no chão antes de voltar ao controle

@export_group("Crouch (MVP)")
@export var crouch_speed_cap: float = 120.0

@export_group("Cartwheel / Attack (MVP - DKC-like)")
@export var attack_start_speed: float = 260.0
@export var attack_max_speed: float = 520.0
@export var attack_seconds: float = 0.40
@export var attack_extend_seconds_on_hit: float = 0.40
@export var attack_speed_boost_on_hit: float = 90.0
@export var attack_friction: float = 0.04
@export var attack_allow_start_still: bool = true # se true, pode atacar mesmo parado (usa facing)

# Nós
@onready var coyote_jump_timer: Timer = get_node_or_null("CoyoteTimer")
@onready var anim_sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D")
@onready var player_input: PlayerInput = get_node_or_null("PlayerInput")
@onready var attack_hitbox: Area2D = get_node_or_null("AttackHitbox")

# Estado
var state: State = State.IDLE
var is_alive: bool = true

# HP runtime
var hp: int = 0
var _invuln_left: float = 0.0
var _hurt_left: float = 0.0

# Run latch (igual ao original)
var _is_running: bool = false

# Slide runtime (igual ao original)
var _slide_speed: float = 0.0
var _slope_direction: int = 0

# Facing
var _facing: int = 1

# Coyote bookkeeping
var _was_on_floor: bool = false

# Detectar "apertou down agora"
var _down_was_held: bool = false

# Ground pound land lock
var _gp_land_left: float = 0.0

# Attack runtime
var _attack_left: float = 0.0
var _attack_dir: int = 1
var _cartwheel_air_jump_charges: int = 0 # “pulo duplo” do cartwheel (recarrega ao acertar inimigo)


func _ready() -> void:
	if stats == null:
		push_warning("Player.stats está vazio. Atribua um PlayerStats .tres no Inspector.")
		stats = PlayerStats.new()

	if coyote_jump_timer == null:
		push_error("Faltando Timer 'CoyoteTimer' como child do Player.")
		return
	if anim_sprite == null:
		push_error("Faltando AnimatedSprite2D 'AnimatedSprite2D' como child do Player.")
		return
	if player_input == null:
		push_error("Faltando PlayerInput 'PlayerInput' como child do Player.")
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

	# AttackHitbox (opcional, mas recomendado)
	if attack_hitbox != null:
		attack_hitbox.monitoring = false
		attack_hitbox.body_entered.connect(_on_attack_body_entered)
		attack_hitbox.area_entered.connect(_on_attack_area_entered)
	else:
		push_warning("Sem 'AttackHitbox' (Area2D). O ataque CARTWHEEL não vai acertar inimigos.")

	# Estado inicial coerente
	if is_on_floor():
		set_state(State.IDLE)
	else:
		set_state(State.CAINDO)


func _physics_process(delta: float) -> void:
	if not is_alive:
		return

	var dt_ticks := delta * float(Engine.physics_ticks_per_second)

	# Timers de dano
	if _invuln_left > 0.0:
		_invuln_left = maxf(0.0, _invuln_left - delta)
	if _hurt_left > 0.0:
		_hurt_left = maxf(0.0, _hurt_left - delta)
		if _hurt_left <= 0.0 and state == State.MACHUCADO:
			if is_on_floor():
				set_state(State.IDLE)
			else:
				set_state(State.CAINDO)

	# Timers do ground pound land
	if _gp_land_left > 0.0:
		_gp_land_left = maxf(0.0, _gp_land_left - delta)
		if _gp_land_left <= 0.0 and state == State.GROUND_POUND_LAND:
			# volta ao controle normal após "impacto"
			player_input.poll()
			var input_after := player_input.snapshot
			if input_after.down_held:
				set_state(State.AGACHADO)
			else:
				set_state(State.ANDANDO if absf(velocity.x) > 0.1 else State.IDLE)

	# Timers do ataque
	if _attack_left > 0.0:
		_attack_left = maxf(0.0, _attack_left - delta)
		if _attack_left <= 0.0 and state == State.CARTWHEEL:
			_end_cartwheel()

	# Se morreu, não processa input
	if state == State.MORTO:
		_apply_gravity(dt_ticks)
		move_and_slide()
		_play_animations()
		return

	# Snapshot de intenção
	player_input.poll()
	var input := player_input.snapshot

	# down "pressed"
	var down_pressed := input.down_held and not _down_was_held
	_down_was_held = input.down_held

	# ataque "pressed" (Action no InputMap)
	var attack_pressed := Input.is_action_just_pressed("attack")

	# Facing / run latch (igual)
	_update_facing(input.axis)
	_update_run_latch(input)

	# State machine
	_update_state(input, down_pressed, attack_pressed)

	# Simulação por estado
	match state:
		State.DESLIZANDO:
			_apply_slide(dt_ticks, input)
		State.MACHUCADO:
			_apply_inertia(dt_ticks)
		State.AGACHADO:
			_apply_crouch(dt_ticks, input)
		State.GROUND_POUND:
			_apply_ground_pound(dt_ticks)
		State.GROUND_POUND_LAND:
			_apply_land_lock(dt_ticks)
		State.CARTWHEEL:
			_apply_cartwheel(dt_ticks)
		_:
			_apply_walk(dt_ticks, input)

	# Pulo (coyote + buffer) - bloqueios
	_apply_jump_logic_cartwheel_aware()

	# Jump cut
	if input.jump_released and velocity.y < 0.0:
		velocity.y *= stats.jump_cut_multiplier

	# Gravidade por estado
	_apply_gravity(dt_ticks)

	# Move
	move_and_slide()

	# Pós-move (coyote + hooks)
	_post_move()

	# Animações
	_play_animations()

	if debug_print:
		print(
			"vel:", velocity,
			" state:", state,
			" on_floor:", is_on_floor(),
			" gp_land:", _gp_land_left,
			" atk_left:", _attack_left,
			" atk_air_charges:", _cartwheel_air_jump_charges,
			" hp:", hp, "/", max_hp
		)


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


# ---------------------------
# State machine
# ---------------------------
func set_state(next: State) -> void:
	if next == state:
		return
	if not _can_transition(state, next):
		return

	_exit_state(state)
	state = next
	_enter_state(state)


func _can_transition(from: State, to: State) -> bool:
	if from == State.MORTO:
		return false
	# durante machucado, bloqueia coisas “agressivas”
	if from == State.MACHUCADO and to in [State.DESLIZANDO, State.GROUND_POUND, State.CARTWHEEL]:
		return false
	return true


func _enter_state(s: State) -> void:
	match s:
		State.DESLIZANDO:
			_slide_speed = stats.slide_speed_start

		State.GLIDANDO:
			_apply_glide_open_pop()

		State.GROUND_POUND:
			if velocity.y < ground_pound_start_speed:
				velocity.y = ground_pound_start_speed

		State.GROUND_POUND_LAND:
			_gp_land_left = ground_pound_land_seconds

		State.CARTWHEEL:
			_attack_left = attack_seconds
			_attack_dir = _facing
			_cartwheel_air_jump_charges = 0

			# garante uma velocidade inicial “boa”
			var base := absf(velocity.x)
			var start := maxf(base, attack_start_speed)
			velocity.x = start * float(_attack_dir)

			_set_attack_hitbox_enabled(true)


func _exit_state(s: State) -> void:
	match s:
		State.DESLIZANDO:
			_slide_speed = stats.slide_speed_start
		State.CARTWHEEL:
			_set_attack_hitbox_enabled(false)


func _update_state(input: PlayerInput.Snapshot, down_pressed: bool, attack_pressed: bool) -> void:
	# trava durante o “impacto” do ground pound
	if state == State.GROUND_POUND_LAND:
		return

	# 1) Ground pound no ar (prioridade)
	if state != State.MACHUCADO and state != State.CARTWHEEL and (not is_on_floor()) and down_pressed:
		set_state(State.GROUND_POUND)
		return

	# 2) Cartwheel (no chão)
	if state not in [State.MACHUCADO, State.GROUND_POUND, State.GROUND_POUND_LAND] and is_on_floor() and attack_pressed:
		if input.axis != 0:
			_facing = input.axis
			set_state(State.CARTWHEEL)
			return
		elif attack_allow_start_still:
			set_state(State.CARTWHEEL)
			return

	# 3) Enquanto está no cartwheel: mantém até timer acabar
	if state == State.CARTWHEEL:
		return

	# 4) Slide (igual original)
	if state != State.MACHUCADO and _should_slide(input):
		set_state(State.DESLIZANDO)
		return

	if state == State.DESLIZANDO and not _should_slide(input):
		if is_on_floor():
			set_state(State.ANDANDO if absf(velocity.x) > 0.1 else State.IDLE)
		else:
			set_state(State.CAINDO)
		return

	# 5) Se está em ground pound e ainda está no ar, mantém
	if state == State.GROUND_POUND and not is_on_floor():
		return

	# 6) Aéreo (igual original + glide)
	if not is_on_floor():
		if input.glide_held and velocity.y >= 0.0:
			set_state(State.GLIDANDO)
		else:
			set_state(State.PULANDO if velocity.y < 0.0 else State.CAINDO)
		return

	# 7) Se acabou de aterrissar do ground pound, _post_move cuida (vira GROUND_POUND_LAND)

	# 8) Chão: agachado
	if input.down_held:
		set_state(State.AGACHADO)
		return

	# 9) Chão normal
	if absf(velocity.x) > 0.1:
		set_state(State.ANDANDO)
	else:
		set_state(State.IDLE)


func _should_slide(input: PlayerInput.Snapshot) -> bool:
	if not is_on_floor():
		return false
	if not input.down_held:
		return false
	return absf(get_floor_angle()) > stats.slope_threshold


# ---------------------------
# Movimento
# ---------------------------
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


func _apply_crouch(dt_ticks: float, input: PlayerInput.Snapshot) -> void:
	var friction := stats.friction
	if input.axis != 0:
		velocity.x += stats.acceleration * float(input.axis) * dt_ticks
		velocity.x = clampf(velocity.x, -crouch_speed_cap, crouch_speed_cap)
	else:
		_apply_friction(dt_ticks, friction)


func _apply_inertia(dt_ticks: float) -> void:
	var friction := stats.friction
	if not is_on_floor():
		friction *= stats.air_friction_multiplier
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


func _apply_ground_pound(dt_ticks: float) -> void:
	velocity.x = lerpf(velocity.x, 0.0, 0.25)
	velocity.y += (stats.gravity * ground_pound_gravity_multiplier) * dt_ticks
	velocity.y = minf(velocity.y, ground_pound_max_speed)


func _apply_land_lock(dt_ticks: float) -> void:
	# mantém um “peso” no impacto, sem virar agachado imediatamente
	_apply_friction(dt_ticks, stats.friction)


func _apply_cartwheel(dt_ticks: float) -> void:
	# mantém velocidade pra frente e dá um “peso” leve
	var target := clampf(absf(velocity.x), attack_start_speed, attack_max_speed) * float(_attack_dir)
	velocity.x = lerpf(velocity.x, target, _lerp_factor_per_ticks(0.18, dt_ticks))
	_apply_friction(dt_ticks, attack_friction)


func _end_cartwheel() -> void:
	_set_attack_hitbox_enabled(false)

	# sai do cartwheel pra um estado coerente
	if is_on_floor():
		set_state(State.ANDANDO if absf(velocity.x) > 0.1 else State.IDLE)
	else:
		set_state(State.CAINDO)


func _set_attack_hitbox_enabled(enabled: bool) -> void:
	if attack_hitbox == null:
		return
	attack_hitbox.monitoring = enabled


# ---------------------------
# Pulo (com suporte ao cartwheel air-jump)
# ---------------------------
func _apply_jump_logic_cartwheel_aware() -> void:
	if state in [State.MACHUCADO, State.MORTO, State.GROUND_POUND, State.GROUND_POUND_LAND]:
		return

	if not player_input.peek_jump():
		return

	# normal (chão/coyote)
	if is_on_floor():
		player_input.consume_jump()
		_jump_now()
		return

	if coyote_jump_timer.time_left > 0.0:
		player_input.consume_jump()
		_jump_now()
		return

	# “pulo duplo” do cartwheel (no ar)
	if state == State.CARTWHEEL and _cartwheel_air_jump_charges > 0:
		player_input.consume_jump()
		_cartwheel_air_jump_charges -= 1
		_jump_now()
		return


func _jump_now() -> void:
	var mult := stats.run_jump_multiplier if _is_running else 1.0
	velocity.y = stats.jump_speed * mult
	set_state(State.PULANDO)


# ---------------------------
# Gravidade / Glide
# ---------------------------
func _apply_gravity(dt_ticks: float) -> void:
	if is_on_floor():
		return

	if state == State.GLIDANDO:
		velocity.y += (stats.gravity / stats.glide_gravity_divisor) * dt_ticks
		velocity.y = minf(velocity.y, stats.max_glide_fall_speed)
	else:
		velocity.y += stats.gravity * dt_ticks
		velocity.y = minf(velocity.y, stats.max_fall_speed)


func _apply_glide_open_pop() -> void:
	if is_on_floor():
		return
	if velocity.y <= 0.0:
		return

	var upward_cap := -stats.glide_open_upward_cap
	velocity.y = maxf(velocity.y - stats.glide_open_brake, upward_cap)


# ---------------------------
# Pós-move / coyote + hooks
# ---------------------------
func _post_move() -> void:
	if is_on_wall():
		velocity.x = 0.0
	if is_on_ceiling():
		velocity.y = maxf(velocity.y, 0.0)

	if is_on_floor() and state != State.DESLIZANDO:
		velocity.y = 0.0

	var now_on_floor := is_on_floor()

	# Coyote
	if _was_on_floor and not now_on_floor and velocity.y >= 0.0:
		coyote_jump_timer.start()
	if now_on_floor and not _was_on_floor:
		coyote_jump_timer.stop()

	# Se aterrissou após ground pound -> entra no lock (GROUND_POUND_LAND)
	if now_on_floor and not _was_on_floor and state == State.GROUND_POUND:
		set_state(State.GROUND_POUND_LAND)

	# Cartwheel: se saiu do chão enquanto atacando, ganha 1 carga de “air jump”
	# (e hits recarregam essa carga)
	if (not now_on_floor) and _was_on_floor and state == State.CARTWHEEL:
		_cartwheel_air_jump_charges = max(_cartwheel_air_jump_charges, 1)

	_was_on_floor = now_on_floor


# ---------------------------
# Ataque: quando o hitbox encosta em algo
# ---------------------------
func _on_attack_body_entered(body: Node) -> void:
	_handle_attack_hit(body)


func _on_attack_area_entered(area: Area2D) -> void:
	_handle_attack_hit(area)


func _handle_attack_hit(target: Node) -> void:
	if state != State.CARTWHEEL:
		return
	if target == null:
		return
	if target == self:
		return

	# tenta causar dano
	var dir := _attack_dir
	var did_something := false

	if target.has_method("take_damage"):
		target.call("take_damage", 1, dir)
		did_something = true
	elif target.has_method("die"):
		target.call("die")
		did_something = true

	if not did_something:
		return

	# “DKC feel”: reinicia o timer e dá boost de velocidade ao acertar inimigo
	_attack_left = maxf(_attack_left, attack_extend_seconds_on_hit)
	velocity.x = clampf(velocity.x + (attack_speed_boost_on_hit * float(dir)), -attack_max_speed, attack_max_speed)

	# “pulo duplo” do cartwheel: recarrega 1 air jump quando acerta inimigo
	_cartwheel_air_jump_charges = 1


# ---------------------------
# HP / Dano / Morte
# ---------------------------
func take_damage(amount: int, from_dir: int) -> void:
	if state == State.MORTO:
		return
	if _invuln_left > 0.0:
		return

	hp -= amount
	if hp <= 0:
		_die()
		return

	_invuln_left = invuln_seconds
	_hurt_left = hurt_lock_seconds
	set_state(State.MACHUCADO)

	var dir := clampi(from_dir, -1, 1)
	if dir == 0:
		dir = -_facing
	velocity.x = knockback_x * float(dir)
	velocity.y = knockback_y


func heal(amount: int) -> void:
	hp = clampi(hp + amount, 0, max_hp)


func _die() -> void:
	is_alive = false
	set_state(State.MORTO)
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
		if state == State.AGACHADO:
			_play_anim("crouch")
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
	if anim_sprite.sprite_frames == null:
		return
	if not anim_sprite.sprite_frames.has_animation(StringName(anim_name)):
		return
	anim_sprite.play(StringName(anim_name))


# Se algum dia o timeout estiver conectado no editor, esse método evita erro.
func _on_coyote_timer_timeout() -> void:
	pass
