class_name Inimigo extends CharacterBody2D


# Sinal para interações específicas
signal enemy_defeated
signal enemy_triggered(player)

# Enum para tipos de movimento
enum MovementType { GROUND, AIR, WATER, PLATFORM }

# Propriedades gerais do inimigo
var health: int 
var speed: Vector2
var sprite_path: String
var animation_tree_path: String
var sound_path: String
var movement_type: MovementType
var invert_on_edge: bool
var loop_movement: bool
var can_jump: bool
var follow_player: bool
var attack_on_sight: bool
var throw_projectiles: bool
var immortal: bool
var interacts_with_objects: bool
var interacts_with_enemies: bool
var slippery: bool
var explode_on_death: bool

# Propriedades para comportamento específico
var jump_interval: float
var attack_range: float
var projectile_scene: PackedScene
var follow_distance: float
var follow_speed: float
#var path_to_follow: PoolVector2Array

# Variáveis de estado internas
var _is_alive: bool = true
var _current_path_index: int = 0
var _timer_since_last_jump: float = 0.0

# Componentes
@onready var sprite: = $Sprite2D
#@onready var animation_tree: AnimationTree = $AnimationTree
@onready var sound_player: = $AudioStreamPlayer2D

func _ready():
	load_resources()
	setup_movement()

func load_resources():
	sprite.texture = load(sprite_path)
#	animation_tree.set_animation_tree(load(animation_tree_path))
	if sound_path:
		sound_player.stream = load(sound_path)

func setup_movement():
	match movement_type:
		MovementType.GROUND:
			# Configure ground movement
			pass
		MovementType.AIR:
			# Configure air movement
			pass
		MovementType.WATER:
			# Configure water movement
			pass
		MovementType.PLATFORM:
			# Configure platform-specific movement
			pass

func set_health(value):
	health = value
	if health <= 0:
		die()

func die():
	_is_alive = false
	emit_signal("enemy_defeated")
	if explode_on_death:
		# Handle explosion logic here
		pass
	queue_free()

func _physics_process(delta):
	if not _is_alive:
		return

	handle_movement(delta)
	handle_interactions()
	check_environment()

	if can_jump and is_on_floor():
		_timer_since_last_jump += delta
		if _timer_since_last_jump >= jump_interval:
			jump()

func handle_movement(delta):
	# Logic for movement based on the movement type
	pass

func handle_interactions():
	# Logic for interaction with player, objects, and other enemies
	pass

func check_environment():
	# Logic for checking edges, platforms, ice, etc.
	pass

func jump():
	_timer_since_last_jump = 0.0
	# Execute jump logic

func attack_player(player):
	if attack_on_sight and player.global_position.distance_to(global_position) <= attack_range:
		# Attack logic
		emit_signal("enemy_triggered", player)

#func throw_projectile():
#    if throw_projectiles:
#		# Preload da cena do projétil
#	var projectile_scene = preload("res://path_to_projectile_scene.tscn")
#    var projectile = projectile_scene.instance()
#    # Define a posição inicial do projétil
#    projectile.position = self.position + Vector2(10, 0) # Ajuste conforme necessário
#    # Adiciona o projétil ao mundo do jogo
#    get_parent().add_child(projectile)
#    # Configura a direção e a velocidade do projétil
#    projectile.set_direction_and_speed(Vector2(1, 0), 300) # Exemplo de direção e velocidade


func follow_player_logic(player):
	if follow_player and player.global_position.distance_to(global_position) <= follow_distance:
		var direction = (player.global_position - global_position).normalized()
		move_and_slide()

func _on_PlayerDetector_body_entered(body):
	if body.is_in_group("player"):
		attack_player(body)

func _on_PlayerDetector_body_exited(body):
	pass
	# Optional: Logic for when the player exits detection range

#func interact_with_object(object):
#    if interacts_with_objects:
		# Interaction logic

#func interact_with_enemy(enemy):
#    if interacts_with_enemies:
#        # Interaction logic

# ... More methods for specific behaviors
