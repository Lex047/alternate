# Persists whether the tutorial has been dismissed across sessions. Gameplay
# uses this flag to decide whether to show the introductory splash.
extends Node


const PROGRESS_PATH := "user://progress.cfg"

const TUTORIAL_SECTION := "tutorial"
const TUTORIAL_SEEN_KEY := "seen"


var config := ConfigFile.new()


func _ready() -> void:
	_load_progress()


func _load_progress() -> void:
	var error := config.load(PROGRESS_PATH)

	if error != OK and error != ERR_FILE_NOT_FOUND:
		push_warning(
			"ProgressManager: Could not load progress file."
		)


func has_seen_tutorial() -> bool:
	return config.get_value(
		TUTORIAL_SECTION,
		TUTORIAL_SEEN_KEY,
		false
	)


func mark_tutorial_seen() -> void:
	config.set_value(
		TUTORIAL_SECTION,
		TUTORIAL_SEEN_KEY,
		true
	)

	var error := config.save(PROGRESS_PATH)

	if error != OK:
		push_error(
			"ProgressManager: Could not save progress."
		)
