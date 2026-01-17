# OptionsMenu.gd
extends Control

signal closed

@onready var sfx_move: AudioStreamPlayer = $"../MenuSfxMove"
@onready var sfx_accept: AudioStreamPlayer = $"../MenuSfxConfirm"

@onready var music_slider: HSlider = $OptionsCenter/OptionsPanel/OptionsVBox/MusicRow/MusicSlider
@onready var sfx_slider: HSlider = $OptionsCenter/OptionsPanel/OptionsVBox/SfxRow/SfxSlider
@onready var fullscreen_check: CheckButton = $OptionsCenter/OptionsPanel/OptionsVBox/FullscreenCheck
@onready var vsync_check: CheckButton = $OptionsCenter/OptionsPanel/OptionsVBox/VsyncCheck
@onready var back_button: Button = $OptionsCenter/OptionsPanel/OptionsVBox/BackButton

var _music_bus := -1
var _sfx_bus := -1

# Seus ranges desejados (UI em "porcentagem")
const MUSIC_MAX := 100.0
const SFX_MAX := 50.0

# Tick leve enquanto ajusta (com step grande, dá pra usar 1 tick por mudança)
var _last_music_tick := -999.0
var _last_sfx_tick := -999.0


func _play_select() -> void:
	sfx_move.stop()
	sfx_move.play()


func _play_accept() -> void:
	sfx_accept.stop()
	sfx_accept.play()


func _ready() -> void:
	visible = false

	# Garante o range do slider no código (evita cena mal configurada)
	music_slider.min_value = 0.0
	music_slider.max_value = MUSIC_MAX
	music_slider.step = 10.0

	sfx_slider.min_value = 0.0
	sfx_slider.max_value = SFX_MAX
	sfx_slider.step = 5.0

	_music_bus = AudioServer.get_bus_index(&"Music")
	_sfx_bus = AudioServer.get_bus_index(&"SFX")

	if _music_bus == -1:
		push_warning("Bus 'Music' nao encontrado. Confira o nome no painel Audio (buses).")
	if _sfx_bus == -1:
		push_warning("Bus 'SFX' nao encontrado. Confira o nome no painel Audio (buses).")

	# Navegação (select) ao trocar foco (teclado/controle)
	music_slider.focus_entered.connect(_play_select)
	sfx_slider.focus_entered.connect(_play_select)
	fullscreen_check.focus_entered.connect(_play_select)
	vsync_check.focus_entered.connect(_play_select)
	back_button.focus_entered.connect(_play_select)

	# Ações (accept) ao confirmar
	back_button.pressed.connect(_on_back_pressed)
	fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	vsync_check.toggled.connect(_on_vsync_toggled)

	# Sliders: aplica volume + feedback
	music_slider.value_changed.connect(_on_music_changed)
	sfx_slider.value_changed.connect(_on_sfx_changed)

	# Som ao começar a arrastar (feedback de "entrei em ajuste")
	music_slider.drag_started.connect(_play_accept)
	sfx_slider.drag_started.connect(_play_accept)

	_sync_ui_from_system()


func open() -> void:
	_sync_ui_from_system()
	visible = true
	back_button.grab_focus.call_deferred()


func close() -> void:
	visible = false
	closed.emit()


func _sync_ui_from_system() -> void:
	# BUS é 0..1 (linear). SLIDER é 0..MUSIC_MAX / 0..SFX_MAX.
	var m_lin := 1.0
	if _music_bus != -1:
		m_lin = AudioServer.get_bus_volume_linear(_music_bus)
	var m_ui := clampf(m_lin * MUSIC_MAX, 0.0, MUSIC_MAX)
	music_slider.set_value_no_signal(m_ui)
	_last_music_tick = m_ui

	var s_lin := 1.0
	if _sfx_bus != -1:
		s_lin = AudioServer.get_bus_volume_linear(_sfx_bus)
	var s_ui := clampf(s_lin * SFX_MAX, 0.0, SFX_MAX)
	sfx_slider.set_value_no_signal(s_ui)
	_last_sfx_tick = s_ui

	var mode := DisplayServer.window_get_mode()
	var is_fullscreen := (mode == DisplayServer.WINDOW_MODE_FULLSCREEN
		or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	fullscreen_check.set_pressed_no_signal(is_fullscreen)

	var vs := DisplayServer.window_get_vsync_mode()
	vsync_check.set_pressed_no_signal(vs != DisplayServer.VSYNC_DISABLED)


func _on_music_changed(v_ui: float) -> void:
	if _music_bus != -1:
		var v_lin := clampf(v_ui / MUSIC_MAX, 0.0, 1.0) # 0..100 -> 0..1
		AudioServer.set_bus_volume_linear(_music_bus, v_lin)

	# Com step=10, value_changed já é "degrau"; 1 tick por mudança fica ótimo
	if v_ui != _last_music_tick:
		_last_music_tick = v_ui
		_play_select()


func _on_sfx_changed(v_ui: float) -> void:
	if _sfx_bus != -1:
		var v_lin := clampf(v_ui / SFX_MAX, 0.0, 1.0) # 0..50 -> 0..1
		AudioServer.set_bus_volume_linear(_sfx_bus, v_lin)

	if v_ui != _last_sfx_tick:
		_last_sfx_tick = v_ui
		_play_select()


func _on_fullscreen_toggled(on: bool) -> void:
	_play_accept()
	var target_mode := DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(target_mode)


func _on_vsync_toggled(on: bool) -> void:
	_play_accept()
	var target_vsync := DisplayServer.VSYNC_ENABLED if on else DisplayServer.VSYNC_DISABLED
	DisplayServer.window_set_vsync_mode(target_vsync)


func _on_back_pressed() -> void:
	_play_accept()
	close()
