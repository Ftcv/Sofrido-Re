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

# VARIAVEIS
var jump_height : float = 50
var jump_time_to_peak : float = 0.5
var jump_time_to_descent: float = 0.5

var direction = 0
var type_move: String
var max_walk_speed = 200
var acceleration = 10  
var desaceleracao = 0.1
var friction = 0.10  # quanto menor mais o player desliza
var has_friction = true
var is_alive = true
var motion = Vector2(0,0)
var state = State.ANDANDO
var snapvector = Vector2(0,1)
var glidiando = false
var forca_horizontal = 0
var angulo_floor = Vector2(0,0)
var caindo_pra_direita = 2 # 1 é pra direita, 0 é pra esquerda
var impulso_inicial = 0

# VARIAVEIS ONREADY
@onready var coyote_jump_timer = $CoyoteTimer
@onready var jump_velocity : float = ((2.0 * jump_height) / jump_time_to_peak) * -1.0
@onready var jump_gravity : float = ((-2.0 * jump_height) / (jump_time_to_peak * jump_time_to_peak)) * -1.0
@onready var fall_gravity : float = ((-2.0 * jump_height) / (jump_time_to_descent * jump_time_to_descent)) * -1.0

#CHAMADO ASSIM QUE INICIA O NODE:
func _ready():
	pass
#	set_floor_snap_length(7)

# Physics process handler
func _physics_process(delta):
	print(" motion.y: ", motion.y, " velocity: ",velocity, " State: ", state," apply_gravity: " ,apply_gravity())
	set_velocity(motion)
	move_and_slide()
	player_input()
	handle_collision()
	state_machine()
	animations()
	process_movement()
	apply_gravity()
	motion.y += apply_gravity() * delta

# Collision handling
func handle_collision():
	if is_on_wall():
		motion.x = 0
	if is_on_ceiling():
		motion.y = max(motion.y, 0)

# State machine logic
func state_machine():
	match state:
		State.IDLE:
			idle()
		State.ANDANDO:
			andando()
		State.PULANDO:
			pass
		State.CAINDO:
			pass
		State.GLIDANDO:
			pass
		State.SWING_ROPE:
			swingando()
		State.DESLIZANDO:
			deslizando()
		State.MACHUCADO:
			machucando()

# Movement processing
func process_movement():
	acceleration_calc()
	var was_on_floor = is_on_floor()
	move_and_slide()
	var just_left_ledge = was_on_floor and not is_on_floor() and motion.y >= 0
	if just_left_ledge:
		coyote_jump_timer.start()
		

# Calcula a aceleração baseada na direção e aplica ao motion.x
func acceleration_calc():
	if direction != 0:
		motion.x += acceleration * direction
		motion.x = clamp(motion.x,-max_walk_speed,max_walk_speed)
	else:
		inertia()
		

# Animations handler
func animations():
	if is_on_floor():
		if state == State.DESLIZANDO and get_floor_angle() != 0:
			$AnimationPlayer.play("Deslizando")
			return
		if motion.x != 0:
			if type_move == "correndo":
				$AnimationPlayer.play("Correndo")
				return
			else:
				if type_move == "andando":
					$AnimationPlayer.play("Andando")
					return
		else:
			state = State.IDLE
			$AnimationPlayer.play("Respirando")
			return
	else:
		if glidiando:
			$AnimationPlayer.play("gliding")
			return
		if motion.y < 0:
			$AnimationPlayer.play("Pulo_subindo")
			return
		else:
			$AnimationPlayer.play("Pulo_caindo")
			return

# Player input handler
func player_input():
	if Input.is_action_pressed("left"):
		$Sprite2D.flip_h = true
		direction = -1
	elif Input.is_action_pressed("right"):
		$Sprite2D.flip_h = false
		direction = 1
	else: 
		direction = 0

	
	if Input.is_action_pressed("ui_rs"): # and motion.y >= 0:
		glidiando = true
	else:
		glidiando = false

	if is_on_floor():
		motion.y=0
		if Input.is_action_pressed("down") and get_floor_angle() != 0:
			state = State.DESLIZANDO
			
		if Input.is_action_just_pressed("jump"):
			motion.y = jump_velocity
			
	if motion.y<0:
		if Input.is_action_just_released("jump"):
			motion.y = motion.y/2
			apply_gravity()
			
		
#		if Input.is_action_just_pressed("jump") and coyote_jump_timer.time_left > 0.0:
#			if type_move == "correndo":
#				velocity.y = jump_velocity * 1.25
#			else:
#				velocity.y = jump_velocity
#		if motion.y < 0:
#			if Input.is_action_just_released("jump"):
##				motion.y = motion.y/2
#				apply_gravity()
			
					
		if Input.is_action_pressed("run"):
			type_move = "correndo"
			max_walk_speed = 300
			acceleration = 5
		else:
			type_move = "andando"
			max_walk_speed = 200
			acceleration = 5
				
	

# Inertia calculation
func inertia():
	if is_on_floor():
		if has_friction == true:
			motion.x=lerpf(motion.x,0,friction)
			if abs(motion.x) < 1:
				motion.x = 0
	else:
		if has_friction == true:
			motion.x=lerpf(motion.x,0,friction/1.01)
			if abs(motion.x) < 1:
				motion.x = 0

# Walking logic
func andando():
	process_movement()
	apply_gravity()
	player_input()
	has_friction = true
	inertia()

#Idle logic
func idle():
	pass

# Swinging logic
func swingando():
	pass

# Sliding logic
func deslizando():
	var is_sliding = false  # Variável para rastrear se o personagem está escorregando
	var slide_speed = 5.0  # Velocidade inicial de escorregar
	var max_slide_speed = 600  # Velocidade máxima de escorregar
	var slide_acceleration = 20  # Aceleração ao escorregar
	var slope_threshold = 0.2  # Ângulo máximo para considerar uma superfície como uma ladeira

	# Verifique se o personagem está em uma ladeira
	if is_on_floor() and get_floor_angle() > slope_threshold:
		is_sliding = true
		slide_speed += slide_acceleration

		# Limite a velocidade máxima
		if slide_speed > max_slide_speed:
			slide_speed = max_slide_speed

	# Se o personagem está escorregando
	if is_sliding:
		# Ajuste a velocidade horizontal de acordo com a inclinação
		var slope_direction = sign(get_floor_normal().x)
		set_velocity(Vector2(slide_speed * slope_direction * fall_gravity, get_velocity().y))

		# Vire o sprite do personagem na direção apropriada
		if slope_direction > 0:
			$Sprite2D.flip_h = false
		else:
			$Sprite2D.flip_h = true
	else:
		# Se não estiver escorregando, reinicialize a velocidade
		slide_speed = 0.0
		is_sliding = false 
		apply_gravity()
		inertia()

	if get_floor_angle() == 0:
		set_velocity(motion)

	if not is_on_floor():
		state =State.ANDANDO
	
	#Se largar o botão para baixo
	if Input.is_action_just_released("down"):
		state =State.ANDANDO

# Hurting logic
func machucando():
	pass

# Gravity application
func apply_gravity():
#	if not is_on_floor() or
	if glidiando == true:
		return jump_gravity if velocity.y < 0.0 else fall_gravity/8
	else:
		return jump_gravity if velocity.y < 0.0 else fall_gravity

func ataque():
	pass

