extends Node2D

export (NodePath) var player_path
onready var player = get_node(player_path)

#export (NodePath) var game_over_path
#onready var game_over_ui = get_node(game_over_path)
#
#func _ready():
#	game_over_ui.visible = false
