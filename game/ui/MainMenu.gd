# MainMenu.gd
extends Control
@export var new_game_scene: String = "res://dev/demo_lvl1.tscn"

@onready var btn_new: Button = $CenterContainer/MenuVBox/NewGameButton
@onready var btn_load: Button = $CenterContainer/MenuVBox/LoadGameButton
@onready var btn_options: Button = $CenterContainer/MenuVBox/OptionsButton
@onready var btn_quit: Button = $CenterContainer/MenuVBox/QuitButton

@onready var music: AudioStreamPlayer = $MenuMusic
@onready var sfx_move: AudioStreamPlayer = $MenuSfxMove
@onready var sfx_select: AudioStreamPlayer = $MenuSfxConfirm

var _busy := false # Pra evita double press (Enquanto _busy for true, o menu ignora novos inputs.)

func _on_any_button_focused() -> void:
	if _busy:
		return
	sfx_move.stop()
	sfx_move.play()


func _ready():
	music.play()
# Foco inicial pra navegar no teclado/controle
	btn_new.grab_focus.call_deferred()

	
# SFX ao mudar seleção: toca quando o botão recebe foco
	btn_new.focus_entered.connect(_on_any_button_focused)
	btn_load.focus_entered.connect(_on_any_button_focused)
	btn_options.focus_entered.connect(_on_any_button_focused)
	btn_quit.focus_entered.connect(_on_any_button_focused)

func _set_buttons_enabled(enabled: bool) -> void:
	btn_new.disabled = not enabled
	btn_options.disabled = not enabled
	btn_quit.disabled = not enabled
	
func _play_confirm_and_wait() -> void:
	sfx_select.stop()
	sfx_select.play()
	await sfx_select.finished

func _on_new_game_button_pressed() -> void:
	if _busy:
		return
	_busy = true
	_set_buttons_enabled(false)
	await _play_confirm_and_wait()
	get_tree().change_scene_to_file(new_game_scene)


func _on_load_game_button_pressed() -> void:
	# placeholder
	if _busy:
		return
	_busy = true
	_set_buttons_enabled(false)
	await _play_confirm_and_wait()
	_busy = false
	_set_buttons_enabled(true)



func _on_options_button_pressed() -> void:
	# placeholder
	if _busy:
		return
	_busy = true
	_set_buttons_enabled(false)
	await _play_confirm_and_wait()
	_busy = false
	_set_buttons_enabled(true)


func _on_quit_button_pressed() -> void:
	if _busy:
		return
	_busy = true
	_set_buttons_enabled(false)
	await _play_confirm_and_wait()
	get_tree().quit()
