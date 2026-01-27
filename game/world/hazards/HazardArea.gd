extends Area2D

@export var damage_amount: int = 1
@export var hit_cooldown_ms: int = 250
@export var kill_on_touch: bool = true # Fase 0: deixa o teste inequívoco

var _last_hit_ms_by_body: Dictionary = {} # instance_id(int) -> last_hit_ms(int)

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return

	var id: int = body.get_instance_id()
	var now_ms: int = Time.get_ticks_msec()
	var last_ms: int = int(_last_hit_ms_by_body.get(id, -999999))
	if now_ms - last_ms < hit_cooldown_ms:
		return
	_last_hit_ms_by_body[id] = now_ms

	if not body.has_method("take_damage"):
		return

	var dir_sign: int = 1
	if body.global_position.x < global_position.x:
		dir_sign = -1

	# Fase 0: se o player tiver i-frames/HP alto, isso garante que "tocou = morreu"
	var dmg: int = 999999 if kill_on_touch else damage_amount
	body.call("take_damage", dmg, dir_sign)

	print("Hazard: dano aplicado em ", body.name, " @ ", global_position)
