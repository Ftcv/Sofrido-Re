extends Node

#vida,score,itens coletados... etc
var start_lives = 3
var actual_lives 
var gemas

var test_checkpoint_pos: Vector2 = Vector2.ZERO
var has_test_checkpoint: bool = false


func set_test_checkpoint(pos: Vector2) -> void:
	test_checkpoint_pos = pos
	has_test_checkpoint = true
	print("Global: test checkpoint salvo -> ", test_checkpoint_pos)

func clear_test_checkpoint() -> void:
	has_test_checkpoint = false
	test_checkpoint_pos = Vector2.ZERO
	print("Global: test checkpoint limpo")


func _ready():
	pass # Replace with function body.
