extends Node2D

#func _ready():
#	$"../AudioStreamPlayer2D".play()

func _physics_process(delta):
	if Input.is_action_pressed("ui_r"): 
		get_tree().reload_current_scene()
