extends Area2D

var is_active: bool = false
@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if is_active:
		return
	if not body.is_in_group("player"):
		return
	activate()

func activate() -> void:
	is_active = true
	if sprite:
		sprite.modulate = Color.GREEN

	print("CHECKPOINT ATIVADO EM: ", global_position)

	# Fase 0: contrato direto com Autoload
	Global.set_test_checkpoint(global_position)
