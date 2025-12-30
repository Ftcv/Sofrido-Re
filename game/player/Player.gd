# res://game/player/Player.gd
extends CharacterBody2D

enum State {
	IDLE,
	ANDANDO,
	PULANDO,
	CAINDO,
	GLIDANDO,
	SWING_ROPE,
	DESLIZANDO,
	MACHUCADO
}

@export_group("Config")
@export var debug_print: bool = false
@export var stats: PlayerStats

# Nós (use get_node_or_null pra não explodir caso você renomeie algo)
@onready var coyote_jump_timer: Timer = get_node_or_null("CoyoteTimer")
@onready var sprite: Sprite2D = get_node_or_null("Sprite2D")
@onready var anim: AnimationPlayer = get_node_or_null("AnimationPlayer")
@onready var player_input: PlayerInput = get_node_or_null("PlayerInput")

# Estado
var state: State = State.IDLE
var is_alive: bool = true

# Run (modo de locomoção: “embalo” do chão pro ar)
var _is_running: bool = false

# Slide runtime
var _slide_speed: float = 0.0
var _slope_direction: int = 0

# Coyote bookkeeping
var _was_on_floor: bool = false

func _ready() -> void:
	# Segurança: stats precisa existir (Resource de tuning)
	if stats == null:
		push_warning("Player.stats está vazio. Atribua um PlayerStats .tres no Inspector.")
		stats = PlayerStats.new()

	# Segurança: nós essenciais
	if coyote_jump_timer == null:
		push_error("Faltando Timer 'CoyoteTimer' como child do Player.")
		return
	if sprite == null:
		push_error("Faltando Sprite2D 'Sprite2D' como child do Player.")
		return
	if anim == null:
		push_error("Faltando AnimationPlayer 'AnimationPlayer' como child do Player.")
		return
	if player_input == null:
		push_error("Faltando PlayerInput 'PlayerInput' como child do Player.")
		return

	# CharacterBody2D snap em rampas
	floor_snap_length = stats.floor_snap_length

	# Timer de coyote (rodar no physics é mais consistente)
	coyote_jump_timer.one_shot = true
	coyote_jump_timer.process_callback = Timer.TIMER_PROCESS_PHYSICS
	coyote_jump_timer.wait_time = stats.coyote_seconds

	# Input buffer (se for 0, funciona como “just pressed” normal)
	player_input.configure_from_stats(stats)

	_slide_speed = stats.slide_speed_start
	_was_on_floor = is_on_floor()

	# Estado inicial coerente
	if is_on_floor():
		set_state(State.IDLE)
	else:
		set_state(State.CAINDO)

func _physics_process(delta: float) -> void:
	if not is_alive:
		return

	# dt_ticks amarrado ao tick real do engine
	var dt_ticks := delta * float(Engine.physics_ticks_per_second)

	# 1) Atualiza snapshot de intenção (Player NÃO usa Input.*)
	player_input.poll()
	var input := player_input.snapshot

	# 2) Facing
	_update_facing(input.axis)

	# 3) Run instantâneo (sem mutar exports)
	_update_run_latch(input)

	# 4) State governa: decide transições
	_update_state(input)

	# 5) Simulação por estado
	match state:
		State.DESLIZANDO:
			_apply_slide(dt_ticks, input)
		State.MACHUCADO:
			# Sem controle (placeholder); só desacelera/gravidade etc.
			_apply_inertia(dt_ticks)
		_:
			_apply_walk(dt_ticks, input)

	# 6) Pulo (coyote + buffer)
	_apply_jump_logic()

	# 7) Jump cut
	if input.jump_released and velocity.y < 0.0:
		velocity.y *= stats.jump_cut_multiplier

	# 8) Gravidade por estado
	_apply_gravity(dt_ticks)

	# 9) Move
	move_and_slide()

	# 10) Pós-move (coyote + correções)
	_post_move()

	# 11) Animações
	_play_animations()

	if debug_print:
		print("vel:", velocity,
			" state:", state,
			" on_floor:", is_on_floor(),
			" floor_angle:", get_floor_angle(),
			" running:", _is_running,
			" slide_speed:", _slide_speed
		)

# ---------------------------
# Facing / Run
# ---------------------------
func _update_facing(axis: int) -> void:
	if axis < 0:
		sprite.flip_h = true
	elif axis > 0:
		sprite.flip_h = false

func _update_run_latch(input: PlayerInput.Snapshot) -> void:
	if is_on_floor():
		# Run liga instantâneo no chão
		_is_running = input.run_held
	else:
		# No ar: mantém se estava correndo e ainda segura run
		if not input.run_held:
			_is_running = false

func _current_speed_cap(input: PlayerInput.Snapshot) -> float:
	# - Run “de verdade” vem do embalo do chão
	# - Se segurar run no ar sem embalo: bônus leve
	var cap := stats.max_run_speed if _is_running else stats.max_walk_speed

	if not is_on_floor() and input.run_held and not _is_running:
		cap = maxf(cap, stats.max_walk_speed + stats.run_air_speed_bonus)

	return cap

# ---------------------------
# State machine (centralizada)
# ---------------------------
func set_state(next: State) -> void:
	if next == state:
		return
	if not _can_transition(state, next):
		return

	_exit_state(state)
	state = next
	_enter_state(state)

func _can_transition(_from: State, _to: State) -> bool:
	# Regras mínimas agora; endurecemos quando tiver corda/dano/barril.
	return true

func _enter_state(s: State) -> void:
	match s:
		State.DESLIZANDO:
			_slide_speed = stats.slide_speed_start

func _exit_state(s: State) -> void:
	match s:
		State.DESLIZANDO:
			_slide_speed = stats.slide_speed_start

func _update_state(input: PlayerInput.Snapshot) -> void:
	# 1) Slide: prioridade no chão
	if state != State.MACHUCADO and _should_slide(input):
		set_state(State.DESLIZANDO)
		return

	# 2) Se estava em slide e parou condição, sai (decisão aqui — centralizado)
	if state == State.DESLIZANDO and not _should_slide(input):
		if is_on_floor():
			set_state(State.ANDANDO if absf(velocity.x) > 0.1 else State.IDLE)
		else:
			set_state(State.CAINDO)
		return

	# 3) Aéreo
	if not is_on_floor():
		if input.glide_held and velocity.y >= 0.0:
			set_state(State.GLIDANDO)
		else:
			set_state(State.PULANDO if velocity.y < 0.0 else State.CAINDO)
		return

	# 4) Chão
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
# Movimento horizontal
# ---------------------------
func _apply_walk(dt_ticks: float, input: PlayerInput.Snapshot) -> void:
	var cap := _current_speed_cap(input)

	var accel := stats.acceleration
	var friction := stats.friction

	# Ar: um pouco menos “autoridade” que no chão
	if not is_on_floor():
		accel *= stats.air_accel_multiplier
		friction *= stats.air_friction_multiplier

	if input.axis != 0:
		velocity.x += accel * float(input.axis) * dt_ticks
		velocity.x = clampf(velocity.x, -cap, cap)
	else:
		_apply_friction(dt_ticks, friction)

# ✅ Wrapper que faltava (conserta seu erro)
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

# ---------------------------
# Slide
# ---------------------------
func _apply_slide(dt_ticks: float, input: PlayerInput.Snapshot) -> void:
	# Se _should_slide falhar por algum motivo, não transiciona aqui (centralizado em _update_state)
	if not _should_slide(input):
		_slide_speed = stats.slide_speed_start
		return

	_slide_speed = minf(_slide_speed + stats.slide_acceleration * dt_ticks, stats.max_slide_speed)

	_slope_direction = int(signf(get_floor_normal().x))
	if _slope_direction == 0:
		_slope_direction = 1

	velocity.x = _slide_speed * float(_slope_direction) * stats.gravity
	sprite.flip_h = _slope_direction < 0

# ---------------------------
# Pulo / Coyote / Buffer
# ---------------------------
func _apply_jump_logic() -> void:
	if not player_input.peek_jump():
		return

	if is_on_floor():
		player_input.consume_jump()
		_jump_now()
		return

	if coyote_jump_timer.time_left > 0.0:
		player_input.consume_jump()
		_jump_now()

func _jump_now() -> void:
	var mult := stats.run_jump_multiplier if _is_running else 1.0
	velocity.y = stats.jump_speed * mult
	set_state(State.PULANDO)

# ---------------------------
# Gravidade
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

# ---------------------------
# Pós-move / colisões / coyote
# ---------------------------
func _post_move() -> void:
	if is_on_wall():
		velocity.x = 0.0
	if is_on_ceiling():
		velocity.y = maxf(velocity.y, 0.0)

	# Zera Y no chão (exceto slide)
	if is_on_floor() and state != State.DESLIZANDO:
		velocity.y = 0.0

	var now_on_floor := is_on_floor()
	if _was_on_floor and not now_on_floor and velocity.y >= 0.0:
		coyote_jump_timer.start()

	if now_on_floor and not _was_on_floor:
		coyote_jump_timer.stop()

	_was_on_floor = now_on_floor

# ---------------------------
# Animações
# ---------------------------
func _play_animations() -> void:
	if is_on_floor():
		if state == State.DESLIZANDO and absf(get_floor_angle()) > stats.slope_threshold:
			anim.play("Deslizando")
			return

		if absf(velocity.x) > 0.1:
			anim.play("Correndo" if _is_running else "Andando")
			return

		anim.play("Respirando")
		return

	# No ar:
	if state == State.GLIDANDO:
		anim.play("gliding")
		return

	anim.play("Pulo_subindo" if velocity.y < 0.0 else "Pulo_caindo")

func ataque() -> void:
	pass
