extends KinematicBody2D

var max_walk_speed = 200
var gravity = 150
var jump_speed = - 100
var acceleration = 20 # quanto menor maior a inercia
var friction = 0.10 # quanto menor mais o player desliza
var has_friction = false
var is_alive = true
var motion = Vector2(0,0)
var state
#enum {CORRENDO,IDLE,ANDANDO,NADANDO,SWING_ROPE,GLIDING,DESLIZANDO,PULANDO}


func _physics_process(delta):
	
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
		motion.y += delta * gravity

		if is_on_floor():
			if Input.is_action_just_pressed("ui_up"):
				motion.y = jump_speed
			if has_friction == true:
				motion.x=lerp(motion.x,0,friction)
		else:
			if has_friction == true:
				motion.x=lerp(motion.x,0,friction/2)

		if Input.is_action_pressed("ui_left"):
			$Sprite.flip_h = true
			motion.x = max(motion.x-acceleration,-max_walk_speed)
		elif Input.is_action_pressed("ui_right"):
			$Sprite.flip_h = false
			motion.x = min(motion.x+acceleration,max_walk_speed)
		else:
			has_friction = true
			motion.x = lerp(motion.x,0,friction)
			if abs(motion.x) < 1: 
				motion.x = 0
	animations()

func animations():
	if is_on_floor():
		if motion.x != 0:
			$AnimationPlayer.play("Correndo")
		else:
			$AnimationPlayer.play("Respirando")
	else:
		if motion.y < 0:
			$AnimationPlayer.play("Pulo_subindo")
		else:
			$AnimationPlayer.play("Pulo_caindo")

