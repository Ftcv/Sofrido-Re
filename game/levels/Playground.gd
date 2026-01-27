extends Node2D

func _ready() -> void:
	var current_path := ""
	if get_tree().current_scene:
		current_path = get_tree().current_scene.scene_file_path

	print("Playground _ready() em cena atual: ", current_path)
	print("Playground: Global.has_test_checkpoint=", Global.has_test_checkpoint, " pos=", Global.test_checkpoint_pos)

	if not Global.has_test_checkpoint:
		return

	var players := get_tree().get_nodes_in_group("player")
	print("Playground: players no grupo 'player' = ", players.size())

	if players.is_empty():
		return

	var player := players[0] as Node2D
	if player == null:
		return

	player.global_position = Global.test_checkpoint_pos
	print("Playground: spawn aplicado no checkpoint -> ", Global.test_checkpoint_pos)
