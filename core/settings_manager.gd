# Autoload owning persistent audio, display, and seed-visibility preferences.
# Setters apply changes immediately and save them; web fullscreen requests are
# retried on user input when browser restrictions block the initial request.
extends Node


const SETTINGS_PATH := "user://settings.cfg"


signal show_seed_changed(enabled: bool)


var master_volume: float = 100.0
var music_volume: float = 40.0
var sfx_volume: float = 100.0
var ui_volume: float = 100.0

var fullscreen: bool = true
var show_seed: bool = true

var fullscreen_retry_pending: bool = false


func _ready() -> void:
	load_settings()
	apply_settings()

	if (
		fullscreen
		and OS.has_feature("web")
		and not _is_fullscreen_active()
	):
		fullscreen_retry_pending = true


func _process(_delta: float) -> void:
	if not fullscreen:
		fullscreen_retry_pending = false
		return

	if _is_fullscreen_active():
		fullscreen_retry_pending = false
		return

	if OS.has_feature("web"):
		fullscreen_retry_pending = true
	else:
		_apply_fullscreen()


func _input(event: InputEvent) -> void:
	if not fullscreen_retry_pending:
		return

	if not fullscreen:
		fullscreen_retry_pending = false
		return

	if _is_fullscreen_active():
		fullscreen_retry_pending = false
		return

	if not _is_fullscreen_activation_event(event):
		return

	_apply_fullscreen()


func set_master_volume(value: float) -> void:
	master_volume = clampf(
		value,
		0.0,
		100.0
	)

	_set_bus_volume(
		"Master",
		master_volume
	)

	save_settings()


func set_music_volume(value: float) -> void:
	music_volume = clampf(
		value,
		0.0,
		100.0
	)

	_set_bus_volume(
		"Music",
		music_volume
	)

	save_settings()


func set_sfx_volume(value: float) -> void:
	sfx_volume = clampf(
		value,
		0.0,
		100.0
	)

	_set_bus_volume(
		"SFX",
		sfx_volume
	)

	save_settings()


func set_ui_volume(value: float) -> void:
	ui_volume = clampf(
		value,
		0.0,
		100.0
	)

	_set_bus_volume(
		"UI",
		ui_volume
	)

	save_settings()


func set_fullscreen(enabled: bool) -> void:
	fullscreen = enabled

	if not fullscreen:
		fullscreen_retry_pending = false

	_apply_fullscreen()
	save_settings()


func set_show_seed(enabled: bool) -> void:
	show_seed = enabled

	save_settings()

	show_seed_changed.emit(show_seed)


func _apply_fullscreen() -> void:
	if fullscreen:
		if OS.has_feature("web"):
			DisplayServer.window_set_mode(
				DisplayServer.WINDOW_MODE_FULLSCREEN
			)
		else:
			DisplayServer.window_set_mode(
				DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
			)

	else:
		DisplayServer.window_set_mode(
			DisplayServer.WINDOW_MODE_WINDOWED
		)


func _is_fullscreen_active() -> bool:
	var window_mode := DisplayServer.window_get_mode()

	return (
		window_mode
		== DisplayServer.WINDOW_MODE_FULLSCREEN
		or window_mode
		== DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	)


func _is_fullscreen_activation_event(
	event: InputEvent
) -> bool:
	if event is InputEventKey:
		return event.pressed

	if event is InputEventMouseButton:
		return event.pressed

	if event is InputEventJoypadButton:
		return event.pressed

	if event is InputEventScreenTouch:
		return event.pressed

	return false


func apply_settings() -> void:
	_set_bus_volume(
		"Master",
		master_volume
	)

	_set_bus_volume(
		"Music",
		music_volume
	)

	_set_bus_volume(
		"SFX",
		sfx_volume
	)

	_set_bus_volume(
		"UI",
		ui_volume
	)

	_apply_fullscreen()


func _set_bus_volume(
	bus_name: String,
	value: float
) -> void:
	var bus_index := AudioServer.get_bus_index(
		bus_name
	)

	if bus_index == -1:
		push_warning(
			"SettingsManager: Audio bus not found: "
			+ bus_name
		)
		return

	if value <= 0.0:
		AudioServer.set_bus_mute(
			bus_index,
			true
		)
		return

	AudioServer.set_bus_mute(
		bus_index,
		false
	)

	var linear_volume := (
		value / 100.0
	)

	AudioServer.set_bus_volume_db(
		bus_index,
		linear_to_db(linear_volume)
	)


func save_settings() -> void:
	var config := ConfigFile.new()

	config.set_value(
		"audio",
		"master_volume",
		master_volume
	)

	config.set_value(
		"audio",
		"music_volume",
		music_volume
	)

	config.set_value(
		"audio",
		"sfx_volume",
		sfx_volume
	)

	config.set_value(
		"audio",
		"ui_volume",
		ui_volume
	)

	config.set_value(
		"display",
		"fullscreen",
		fullscreen
	)

	config.set_value(
		"gameplay",
		"show_seed",
		show_seed
	)

	config.save(SETTINGS_PATH)


func load_settings() -> void:
	var config := ConfigFile.new()

	var error := config.load(
		SETTINGS_PATH
	)

	if error != OK:
		return

	master_volume = config.get_value(
		"audio",
		"master_volume",
		100.0
	)

	music_volume = config.get_value(
		"audio",
		"music_volume",
		40.0
	)

	sfx_volume = config.get_value(
		"audio",
		"sfx_volume",
		100.0
	)

	ui_volume = config.get_value(
		"audio",
		"ui_volume",
		100.0
	)

	fullscreen = config.get_value(
		"display",
		"fullscreen",
		true
	)

	show_seed = config.get_value(
		"gameplay",
		"show_seed",
		true
	)
