extends CharacterBody2D

enum State { ANDANDO, SWING_ROPE, DESLIZANDO, MACHUCADO }

# Member variables
var type_move: String
var max_walk_speed = 0
var gravity = 7
var jump_speed = -300
var acceleration = 0  # quanto menor maior a inercia
var friction = 0.10  # quanto menor mais o player desliza
var has_friction = true
var is_alive = true
var motion = Vector2(0,0)
var state = State.ANDANDO
var snapvector = Vector2(0,1)
var glidiando = false
var forca_horizontal = 0

# Onready variables
@onready var coyote_jump_timer = $CoyoteTimer

func _ready():
	set_floor_snap_length(2)
	

# Physics process handler
func _physics_process(delta):
	print("gravity: ", gravity, " motion.y: ",motion.y, " motion.X: ", motion.x, " força horizontal : ",forca_horizontal)
	handle_collision()
	state_machine()
	animations()
	process_movement()

# Collision handling
func handle_collision():
	if is_on_wall():
		motion.x = 0
	if is_on_ceiling():
		motion.y = max(motion.y, 0)

# State machine logic
func state_machine():
	match state:
		State.ANDANDO:
			andando()
		State.SWING_ROPE:
			swingando()
		State.DESLIZANDO:
			deslizando()
		State.MACHUCADO:
			machucando()

# Movement processing
func process_movement():
	var was_on_floor = is_on_floor()
	move_and_slide()
	var just_left_ledge = was_on_floor and not is_on_floor() and motion.y >= 0
	if just_left_ledge:
		coyote_jump_timer.start()

# Animations handler
func animations():
	if is_on_floor():
		if state == State.DESLIZANDO:
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
	var direction = 0
	if Input.is_action_pressed("left"):
		$Sprite2D.flip_h = true
		direction = -1
	elif Input.is_action_pressed("right"):
		$Sprite2D.flip_h = false
		direction = 1

# Calcula a aceleração baseada na direção e aplica ao motion.x
	if direction != 0:
		motion.x += (acceleration + max_walk_speed) * direction 
	elif state != State.DESLIZANDO:	
		inertia()
	
	if Input.is_action_pressed("ui_rs") and motion.y > 0:
		glidiando = true
	else: 
		glidiando = false

	if is_on_floor():
		motion.y=0
		if Input.is_action_just_pressed("down"): #and get_floor_angle() != 0:
			state = State.DESLIZANDO
		if Input.is_action_just_pressed("jump"):
			if type_move == "correndo":
				motion.y = jump_speed * 1.25
			else:
				motion.y = jump_speed
			
					
		if Input.is_action_pressed("run"):
			type_move = "correndo"
			max_walk_speed = 45
			acceleration = 2
		else:
			type_move = "andando"
			max_walk_speed = 30
			acceleration = 2
	else:
		if Input.is_action_just_pressed("jump") and coyote_jump_timer.time_left > 0.0:
			if type_move == "correndo":
				motion.y = jump_speed * 1.25
			else:
				motion.y = jump_speed
		if motion.y < 0:
			if Input.is_action_just_released("jump"): 
				motion.y = motion.y/2
				
	

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
	apply_gravity()
	player_input()
	set_velocity(motion)
	inertia()


# Swinging logic
func swingando():
	pass

# Sliding logic
func deslizando():
	set_velocity(motion)
	move_and_slide()
	if get_floor_angle() != 0:
		if is_sliding_right(get_floor_normal()):
			$Sprite2D.flip_h = false
		else: 
			$Sprite2D.flip_h = true
		forca_horizontal = motion.y * sin(get_floor_angle()) * (1 if is_sliding_right(get_floor_normal()) else -1)
		if is_on_floor():
			motion.y += gravity
			motion.y = min(motion.y,600)
	if get_floor_angle() == 0:
		state=State.ANDANDO
		motion.y = 0
		forca_horizontal = lerpf(forca_horizontal,0,0.05)
		motion.x = forca_horizontal

	if Input.is_action_just_released("down"):
		state =State.ANDANDO

# Hurting logic
func machucando():
	pass

# Gravity application
func apply_gravity():
	if not is_on_floor(): #or state == State.DESLIZANDO:
		if glidiando:
			motion.y += gravity / 4
			motion.y = min(motion.y, 100)
		else:
			motion.y += gravity
			motion.y = min(motion.y, 400)
#			if is_on_floor():
#				motion.y=0
	else:
		motion.y =0

# Check if sliding right
func is_sliding_right(normal_vec):
	return normal_vec.x > 0
