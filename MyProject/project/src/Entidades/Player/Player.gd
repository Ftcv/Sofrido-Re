extends KinematicBody2D
 
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
enum {ANDANDO,SWING_ROPE,DESLIZANDO,MACHUCADO}

 
func _physics_process(delta):
	print(max_walk_speed) #DEBUG
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
	if Input.is_action_pressed("ui_left"):
		$Sprite.flip_h = true
		motion.x = max(motion.x-acceleration,-max_walk_speed)
	elif Input.is_action_pressed("ui_right"):
		$Sprite.flip_h = false
		motion.x = min(motion.x+acceleration,max_walk_speed)
	
	if Input.is_action_pressed("ui_zb") and motion.y > 0:
		glidiando = true
	else: 
		glidiando = false

	if is_on_floor():
		motion.y=0
		if Input.is_action_just_pressed("ui_zb"):
			motion.y = jump_speed
			snapvector = Vector2(0,0)
		if Input.is_action_pressed("ui_xy"):
			max_walk_speed = 150
			acceleration = 30
		else:
			max_walk_speed = 100
			acceleration = 20
	else:
		if motion.y < 0:
			if Input.is_action_just_released("ui_zb"): 
				motion.y = motion.y/2
		snapvector = Vector2(0,6)

func inertia():
	if is_on_floor():
		if has_friction == true:
			motion.x=lerp(motion.x,0,friction)
			if abs(motion.x) < 1: 
				motion.x = 0
	else:
		if has_friction == true:
			motion.x=lerp(motion.x,0,friction/1.5)
			if abs(motion.x) < 1: 
				motion.x = 0


func andando():
	motion.y = move_and_slide_with_snap(motion,snapvector,Vector2(0, -1),false,4,deg2rad(65)).y
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
	pass

func machucando():
	pass


