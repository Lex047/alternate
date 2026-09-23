extends Node

@onready var music_player: AudioStreamPlayer = $MusicPlayer


func play_music(
	music: AudioStream,
	restart: bool = false
) -> void:
	if not music:
		return

	# Don't restart the same song unless explicitly requested.
	if (
		music_player.stream == music
		and music_player.playing
		and not restart
	):
		return

	music_player.stream = music
	music_player.play(0.0)


func stop_music() -> void:
	music_player.stop()
	music_player.stream = null
