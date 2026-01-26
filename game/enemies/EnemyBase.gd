# res://game/enemies/EnemyBase.gd
extends CharacterBody2D
class_name EnemyBase

@export var max_hp: int = 1
@export var gravity: float = 900.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var collider: CollisionShape2D = $CollisionShape2D

var hp: int
var alive := true

func _ready() -> void:
	hp = max_hp

func take_damage(amount: int, from_dir: int) -> void:
	if not alive:
		return
	hp -= amount
	if hp <= 0:
		die()

func die() -> void:
	if not alive:
		return
	alive = false

	# Evita “travar” o player por 1 frame: desliga colisão imediatamente
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	if collider:
		collider.set_deferred("disabled", true)

	# some visual e remove
	if sprite:
		sprite.visible = false
	call_deferred("queue_free")

func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		return
	velocity.y += gravity * delta
