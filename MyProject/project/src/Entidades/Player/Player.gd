extends CharacterBody2D
 
var max_walk_speed = 0
var gravity = 7
var jump_speed = -200
var acceleration = 0  # quanto menor maior a inercia
var friction = 0.20 # quanto menor mais o player desliza
var has_friction = true
var is_alive = true
var motion = Vector2(0,0)
var state = ANDANDO
var snapvector = Vector2(0,1)
var glidiando = false
var forca_horizontal = 0
enum {ANDANDO,SWING_ROPE,DESLIZANDO,MACHUCADO}

 
func _physics_process(delta):
	print(get_floor_normal())
	match (state):
		ANDANDO:
			andando()
		SWING_ROPE:
			swingando()
		DESLIZANDO:
			deslizando()
		MACHUCADO:
			machucando()
 
	animations()
 
func animations():
	if is_on_floor():
		if state == DESLIZANDO:
			$AnimationPlayer.play("Deslizando")
			return
		if motion.x != 0:
			if max_walk_speed > 100:
				$AnimationPlayer.play("Correndo")
				return
			else:
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

 
func player_input():
	if Input.is_action_pressed("left"):
		$Sprite2D.flip_h = true
		motion.x = max(motion.x-acceleration,-max_walk_speed)
	elif Input.is_action_pressed("right"):
		$Sprite2D.flip_h = false
		motion.x = min(motion.x+acceleration,max_walk_speed)
	
	if Input.is_action_pressed("jump") and motion.y > 0:
		glidiando = true
	else: 
		glidiando = false

	if is_on_floor():
		motion.y=0
		if Input.is_action_just_pressed("down") and get_floor_angle() != 0:
			state = DESLIZANDO
		if Input.is_action_just_pressed("jump"):
			motion.y = jump_speed
		if Input.is_action_pressed("run"):
			max_walk_speed = 150
			acceleration = 30
		else:
			max_walk_speed = 100
			acceleration = 20
	else:
		if motion.y < 0:
			if Input.is_action_just_released("jump"): 
				motion.y = motion.y/2

func inertia():
	if is_on_floor():
		if has_friction == true:
			motion.x=lerpf(motion.x,0,friction)
			if abs(motion.x) < 1: 
				motion.x = 0
	else:
		if has_friction == true:
			motion.x=lerpf(motion.x,0,friction/1.5)
			if abs(motion.x) < 1: 
				motion.x = 0


func andando():
	set_velocity(motion)
	# TODOConverter40 looks that snap in Godot 4.0 is float, not vector like in Godot 3 - previous value `snapvector`
	set_up_direction(Vector2(0, -1))
	set_floor_stop_on_slope_enabled(false)
	set_max_slides(4)
	set_floor_max_angle(deg_to_rad(65))
	move_and_slide()
	floor_snap_length = 5
	motion.y = velocity.y
	if glidiando:
		motion.y += gravity/4
		motion.y = min(motion.y,100)
	else:
		motion.y += gravity
		motion.y = min(motion.y,400)
	inertia()
	player_input()

func swingando():
	pass
	
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
		motion.y = 0
		motion.x = forca_horizontal
		forca_horizontal = lerpf(forca_horizontal,0,0.05)
	
	
	if Input.is_action_just_released("down"):
		state =ANDANDO
	

func machucando():
	pass

func is_sliding_right(normal_vec):
	return normal_vec.x >= 0 
	
