extends Node2D


# Called when the node enters the scene tree for the first time.
func _ready():
	pass


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if Input.is_action_just_pressed("Start"): #and qtd_chaves ==1 entao fase2 // se qtd ==2 entao fase3...
		get_tree().change_scene_to_file("res://dev/demo_lvl1.tscn")
