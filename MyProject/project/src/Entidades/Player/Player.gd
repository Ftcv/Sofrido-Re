extends KinematicBody2D

export var walk_speed = 200
export var gravity = 150
export var jump_speed = - 100
var is_alive = true
var velocity = Vector2(0,0)
var state
enum {CORRENDO,IDLE,ANDANDO,NADANDO,SWING_ROPE,GLIDING,DESLIZANDO,PULANDO}

func _ready():
	pass # Replace with function body.

func _physics_process(delta):
	
	match state:
		CORRENDO:
			pass
		IDLE:
			pass
		ANDANDO:
			pass
		NADANDO:
			pass
		SWING_ROPE:
			pass
		GLIDING:
			pass
		DESLIZANDO:
			pass
		PULANDO:
			pass
		
	
	
	if is_alive == true:
		if velocity.x != 0:
			$AnimationPlayer.play("Correndo")
		else:
			$AnimationPlayer.play("Respirando")
		move_and_slide(velocity, Vector2(0, -1))
		velocity.y += delta * gravity
		if Input.is_action_pressed("ui_up"):
			if is_on_floor():
				velocity.y = jump_speed
		if Input.is_action_pressed("ui_left"):
			$Sprite.flip_h = true
			velocity.x = -walk_speed
		elif Input.is_action_pressed("ui_right"):
			$Sprite.flip_h = false
			velocity.x = walk_speed
		else:
			velocity.x = 0


