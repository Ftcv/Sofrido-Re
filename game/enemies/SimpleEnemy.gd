# res://game/enemies/SimpleEnemy.gd
extends EnemyBase
class_name SimpleEnemy

@export_group("Movement")
@export var speed: float = 80.0
@export var turn_at_edges: bool = true

@export_group("Edge Check")
@export var edge_check_ahead: float = 10.0
@export var edge_check_depth: float = 26.0
@export var only_check_edges_on_floor: bool = true

@export_group("Visual Variant")
@export var tint_turn_at_edge: Color = Color(1.0, 0.45, 0.45, 1.0) # “vermelho”
@export var tint_fall_off: Color = Color(0.55, 1.0, 0.55, 1.0)     # “verde”
@export var use_tint_variant: bool = true

@onready var edge_ray: RayCast2D = get_node_or_null("EdgeRay")

var dir: int = -1


func _ready() -> void:
	super._ready()
	_apply_variant_visual()
	_configure_edge_ray()


func _physics_process(delta: float) -> void:
	if not alive:
		return

	_apply_gravity(delta)

	# Movimento base: patrulha constante
	velocity.x = float(dir) * speed

	move_and_slide()

	# Se bater em parede, vira
	if is_on_wall():
		_turn()

	# Checar beirada só se esse tipo vira em penhasco
	if turn_at_edges:
		if (not only_check_edges_on_floor) or is_on_floor():
			if _is_at_edge():
				_turn()

	# Visual: espelha sprite conforme direção
	if sprite:
		sprite.flip_h = (dir > 0)


func _turn() -> void:
	dir *= -1
	_configure_edge_ray()


func _is_at_edge() -> bool:
	if edge_ray == null:
		# Sem EdgeRay: não tenta inventar. Para esse tipo, considere que “não tem edge check”.
		return false

	_configure_edge_ray()
	edge_ray.force_raycast_update()
	return not edge_ray.is_colliding()


func _configure_edge_ray() -> void:
	if edge_ray == null:
		return

	# Coloca o ray um pouco à frente do inimigo e aponta pra baixo
	edge_ray.position = Vector2(edge_check_ahead * float(dir), 0.0)
	edge_ray.target_position = Vector2(0.0, edge_check_depth)

	# Garante que o ray está ativo
	edge_ray.enabled = true
	edge_ray.exclude_parent = true


func _apply_variant_visual() -> void:
	if not use_tint_variant:
		return
	if sprite == null:
		return

	# self_modulate tinge só o Sprite2D, sem “vazar” pra filhos
	sprite.self_modulate = tint_turn_at_edge if turn_at_edges else tint_fall_off
