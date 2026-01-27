extends Node2D

#func _ready():
#	$"../AudioStreamPlayer2D".play()

func _physics_process(_delta: float) -> void:
	# Evita recarregar a cada frame enquanto segura a tecla
	if Input.is_action_just_pressed("ui_r"):
		# Evita problemas de recarregar/remover nós durante callback de física
		get_tree().call_deferred("reload_current_scene")
