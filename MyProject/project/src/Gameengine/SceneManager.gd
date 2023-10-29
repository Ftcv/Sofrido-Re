extends Node2D

@export var player_path : NodePath
@onready var player = get_node(player_path)



#export (NodePath) var game_over_path
#onready var game_over_ui = get_node(game_over_path)
#
#func _ready():
#	game_over_ui.visible = false

func _physics_process(delta):
	if Input.is_action_pressed("ui_r"): 
		get_tree().reload_current_scene()
