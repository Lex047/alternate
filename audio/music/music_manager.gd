extends Node


@onready var music_player: AudioStreamPlayer = $MusicPlayer


func play_music(
	music: AudioStream
) -> void:
	if not music:
		return

	# Don't restart the same song if it's already playing.
	if (
		music_player.stream == music
		and music_player.playing
	):
		return

	music_player.stream = music
	music_player.play()


func stop_music() -> void:
	music_player.stop()
	music_player.stream = null
