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

# ---------------------------
# Tuning (mantive seus valores)
# ---------------------------
@export_group("Snap / Debug")
@export var floor_snap: float = 7.0
@export var debug_print: bool = false

@export_group("Movimento Horizontal (legacy feel)")
@export var max_walk_speed: float = 200.0
@export var max_run_speed: float = 300.0
@export var acceleration: float = 50.0
@export var friction: float = 0.1 # fator de lerp por tick (0..1)
@export var has_friction: bool = true

@export_group("Pulo / Gravidade (legacy feel)")
@export var jump_speed: float = -225.0
@export var gravity: float = 8.0
@export var glide_gravity_divisor: float = 4.0
@export var max_fall_speed: float = 300.0
@export var max_glide_fall_speed: float = 100.0

@export_group("Sliding")
@export var slide_speed_start: float = 5.0
@export var max_slide_speed: float = 50.0
@export var slide_acceleration: float = 0.5
@export var slope_threshold: float = 0.2 # get_floor_angle() em radianos

# ---------------------------
# Estado / flags (mantidos)
# ---------------------------
var state: State = State.ANDANDO
var is_alive: bool = true

# Variáveis legacy que existiam (mantidas; não usadas ainda)
var snapvector: Vector2 = Vector2(0, 1)
var angulo_floor: Vector2 = Vector2.ZERO
var caindo_pra_direita: int = 2
var impulso_inicial: float = 0.0

# Slide runtime
var is_sliding: bool = false
var slide_speed: float = 0.0
var slope_direction: int = 0

# Input/runtime
var direction: int = 0
var type_move: String = "andando"
var glidiando: bool = false

# Coyote
@onready var coyote_jump_timer: Timer = $CoyoteTimer

# Cache de nós (evita get_node repetido)
@onready var sprite: Sprite2D = $Sprite2D
@onready var anim: AnimationPlayer = $AnimationPlayer

# Cache de input (1x por tick)
var _jump_pressed := false
var _jump_released := false
var _down_pressed := false
var _run_pressed := false
var _glide_pressed := false
var _axis := 0

# Para coyote “correto”
var _was_on_floor: bool = false

func _ready() -> void:
	# Em Godot 4, CharacterBody2D tem a propriedade floor_snap_length.
	floor_snap_length = floor_snap
	# Inicializa slide_speed como no seu “feel”
	slide_speed = slide_speed_start

	# Estado inicial
	state = State.ANDANDO
	type_move = "andando"
	_was_on_floor = is_on_floor()

func _physics_process(delta: float) -> void:
	if not is_alive:
		return

	# Escala “por tick” (seu jogo está em 60Hz; isso preserva o feel mesmo se delta variar um pouco)
	var dt_ticks := delta * 60.0

	# 1) Input (uma vez)
	_read_input()

	# 2) Pré-estado: glide só quando caindo (como você pediu)
	glidiando = _glide_pressed and velocity.y >= 0.0

	# 3) Atualiza estado (transições simples; sem “megazord” aqui)
	_update_state_pre_move()

	# 4) Aplica movimento horizontal conforme estado
	match state:
		State.DESLIZANDO:
			_apply_slide(dt_ticks)
		_:
			_apply_walk(dt_ticks)

	# 5) Pulo (antes do move_and_slide, como no seu código original)
	_apply_jump_logic()

	# 6) Jump cut (pulo variável)
	if _jump_released and velocity.y < 0.0:
		velocity.y *= 0.5

	# 7) Gravidade (apenas quando NÃO está no chão; igual ao original)
	_apply_gravity(dt_ticks)

	# 8) Move (uma vez por tick; CharacterBody2D usa velocity)
	move_and_slide()

	# 9) Pós-movimento: colisões + coyote + “zerar Y no chão”
	_post_move(delta)

	# 10) Animações
	animations()

	if debug_print:
		print("vel: ", velocity,
			" state: ", state,
			" on_floor: ", is_on_floor(),
			" floor_angle: ", get_floor_angle(),
			" sliding: ", is_sliding,
			" slide_speed: ", slide_speed,
			" slope_dir: ", slope_direction,
			" glide: ", glidiando
		)

# ---------------------------
# INPUT
# ---------------------------
func _read_input() -> void:
	# Input API oficial
	_axis = int(Input.get_axis("left", "right"))
	_run_pressed = Input.is_action_pressed("run")
	_down_pressed = Input.is_action_pressed("down")
	_glide_pressed = Input.is_action_pressed("ui_rs")
	_jump_pressed = Input.is_action_just_pressed("jump")
	_jump_released = Input.is_action_just_released("jump")

	# Direção + flip
	direction = _axis
	if direction < 0:
		sprite.flip_h = true
	elif direction > 0:
		sprite.flip_h = false

	# Run/Walk (mantém seu type_move)
	if _run_pressed and is_on_floor():
		type_move = "correndo"
		max_walk_speed = max_run_speed
	else:
		type_move = "andando"
		max_walk_speed = 200.0 # seu original

# ---------------------------
# STATE (pré-move)
# ---------------------------
func _update_state_pre_move() -> void:
	# Slide exige segurar down o tempo todo
	if state == State.DESLIZANDO and not _down_pressed:
		state = State.ANDANDO

	# Entrar em slide só no chão e em rampa
	if is_on_floor() and _down_pressed and get_floor_angle() != 0.0:
		state = State.DESLIZANDO
		return

	# Glide é “modo” de queda (não precisa forçar estado separado se você não usa)
	# Mantendo sua enum, mas sem obrigar transição para não quebrar outras lógicas futuras.

# ---------------------------
# MOVIMENTO HORIZONTAL
# ---------------------------
func _apply_walk(dt_ticks: float) -> void:
	# Aceleração “por tick” (preserva seu feel)
	if direction != 0:
		velocity.x += acceleration * float(direction) * dt_ticks
		velocity.x = clampf(velocity.x, -max_walk_speed, max_walk_speed)
	else:
		_apply_inertia(dt_ticks)

func _apply_inertia(dt_ticks: float) -> void:
	if not has_friction:
		return

	# Ajusta lerp por ticks: 1 - (1-t)^ticks
	var t := _lerp_factor_per_ticks(friction, dt_ticks)
	velocity.x = lerpf(velocity.x, 0.0, t)

	if absf(velocity.x) < 1.0:
		velocity.x = 0.0

func _lerp_factor_per_ticks(base_t: float, ticks: float) -> float:
	var t := clampf(base_t, 0.0, 1.0)
	return 1.0 - pow(1.0 - t, maxf(0.0, ticks))

# ---------------------------
# SLIDE
# ---------------------------
func _apply_slide(dt_ticks: float) -> void:
	# Só “escorrega” se ainda está em rampa acima do threshold
	if is_on_floor() and get_floor_angle() > slope_threshold and _down_pressed:
		is_sliding = true
		slide_speed += slide_acceleration * dt_ticks
		slide_speed = minf(slide_speed, max_slide_speed)
	else:
		is_sliding = false

	if is_sliding:
		slope_direction = int(signf(get_floor_normal().x))
		if slope_direction == 0:
			slope_direction = 1

		# Mantém sua “fórmula” (slide_speed * slope_direction * gravity)
		velocity.x = slide_speed * float(slope_direction) * gravity

		# Flip do sprite conforme direção da rampa
		sprite.flip_h = slope_direction < 0
	else:
		# Se não está deslizando, volta ao controle normal
		slide_speed = slide_speed_start
		state = State.ANDANDO

# ---------------------------
# PULO / COYOTE
# ---------------------------
func _apply_jump_logic() -> void:
	if not _jump_pressed:
		return

	# No chão: pula
	if is_on_floor():
		_jump_now()
		return

	# No ar: coyote
	if coyote_jump_timer.time_left > 0.0:
		_jump_now()

func _jump_now() -> void:
	velocity.y = (jump_speed * 1.25) if type_move == "correndo" else jump_speed
	state = State.PULANDO

# ---------------------------
# GRAVIDADE
# ---------------------------
func _apply_gravity(dt_ticks: float) -> void:
	if is_on_floor():
		return # igual ao seu original

	if glidiando:
		velocity.y += (gravity / glide_gravity_divisor) * dt_ticks
		velocity.y = minf(velocity.y, max_glide_fall_speed)
	else:
		velocity.y += gravity * dt_ticks
		velocity.y = minf(velocity.y, max_fall_speed)

# ---------------------------
# PÓS-MOVIMENTO (colisão/coyote)
# ---------------------------
func _post_move(_delta: float) -> void:
	# Colisões do CharacterBody2D após mover
	if is_on_wall():
		velocity.x = 0.0
	if is_on_ceiling():
		velocity.y = maxf(velocity.y, 0.0)

	# “Zerar Y no chão” somente depois de mover (não quebra o pulo)
	if is_on_floor() and state != State.DESLIZANDO:
		velocity.y = 0.0

	# Coyote: detecta saída do chão (referência do tick anterior)
	var now_on_floor := is_on_floor()
	if _was_on_floor and not now_on_floor and velocity.y >= 0.0:
		coyote_jump_timer.start()

	if now_on_floor and not _was_on_floor:
		# opcional: limpa para evitar sobras
		coyote_jump_timer.stop()

	_was_on_floor = now_on_floor

# ---------------------------
# ANIMAÇÕES (mantidas)
# ---------------------------
func animations() -> void:
	if is_on_floor():
		if state == State.DESLIZANDO and get_floor_angle() != 0.0:
			anim.play("Deslizando")
			return

		if velocity.x != 0.0:
			if type_move == "correndo":
				anim.play("Correndo")
				return
			else:
				anim.play("Andando")
				return

		anim.play("Respirando")
		return

	# No ar:
	if glidiando:
		anim.play("gliding")
		return

	if velocity.y < 0.0:
		anim.play("Pulo_subindo")
	else:
		anim.play("Pulo_caindo")

func ataque() -> void:
	pass
