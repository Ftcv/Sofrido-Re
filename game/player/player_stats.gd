# res://game/player/player_stats.gd
extends Resource
class_name PlayerStats

@export_group("Snap")
@export var floor_snap_length: float = 7.0

@export_group("Movimento - chão")
@export var max_walk_speed: float = 200.0
@export var max_run_speed: float = 300.0
@export var acceleration: float = 50.0
@export var friction: float = 0.18 # maior = para mais rápido (menos escorregadio)
@export var stop_threshold: float = 1.0

@export_group("Movimento - ar (controle)")
@export var air_accel_multiplier: float = 0.85
@export var air_friction_multiplier: float = 1.0
@export var run_air_speed_bonus: float = 35.0

@export_group("Pulo / Gravidade")
@export var jump_speed: float = -225.0
@export var run_jump_multiplier: float = 1.25
@export var jump_cut_multiplier: float = 0.5
@export var gravity: float = 8.0
@export var max_fall_speed: float = 300.0

@export_group("Glide")
@export var glide_gravity_divisor: float = 4.0
@export var max_glide_fall_speed: float = 100.0
@export var glide_open_brake: float = 40.0
@export var glide_open_upward_cap: float = 0.0 # 0.0 = não permite “subir”, só freia a queda (recomendado)

@export_group("Coyote / Buffer")
@export var coyote_seconds: float = 0.12
@export var jump_buffer_seconds: float = 0.0 # 0 = desliga (comportamento “padrão”)

@export_group("Slide")
@export var slide_speed_start: float = 5.0
@export var max_slide_speed: float = 50.0
@export var slide_acceleration: float = 0.5
@export var slope_threshold: float = 0.2 # rad
