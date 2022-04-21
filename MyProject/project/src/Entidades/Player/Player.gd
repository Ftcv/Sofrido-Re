extends KinematicBody2D
 
var max_walk_speed = 0
var gravity = 7
var jump_speed = -200
var acceleration = 0  # quanto menor maior a inercia
var friction = 0.20 # quanto menor mais o player desliza
var has_friction = true
var is_alive = true
var motion = Vector2(0,0)
var state
#enum {CORRENDO,IDLE,ANDANDO,NADANDO,SWING_ROPE,GLIDING,DESLIZANDO,PULANDO}
 
 
func _physics_process(delta):
	#print(max_walk_speed) #DEBUG
#	match (state):
#		CORRENDO:
#			pass
#		IDLE:
#			pass
#		ANDANDO:
#			pass
#		NADANDO:
#			pass
#		SWING_ROPE:
#			pass
#		GLIDING:
#			pass
#		DESLIZANDO:
#			pass
#		PULANDO:
#			pass
#
	if is_alive == true:
 
		move_and_slide(motion, Vector2(0, -1))
		motion.y += gravity
		inertia()
		player_input()
 
	animations()
 
func animations():
	if is_on_floor():
		if motion.x != 0:
			if max_walk_speed > 100:
				$AnimationPlayer.play("Correndo")
			else:
				$AnimationPlayer.play("Andando")
		else:
			$AnimationPlayer.play("Respirando")
	else:
		if motion.y < 0:
			$AnimationPlayer.play("Pulo_subindo")
		else:
			$AnimationPlayer.play("Pulo_caindo")
 
func player_input():
	if Input.is_action_pressed("ui_left"):
		$Sprite.flip_h = true
		motion.x = max(motion.x-acceleration,-max_walk_speed)
	elif Input.is_action_pressed("ui_right"):
		$Sprite.flip_h = false
		motion.x = min(motion.x+acceleration,max_walk_speed)
 
	if is_on_floor():
		if Input.is_action_just_pressed("ui_zb"):
			motion.y = jump_speed
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
