# Persistent music playback shared by menus and gameplay. Reusing the current
# track keeps playback continuous unless the caller requests a restart.
extends Node

@onready var music_player: AudioStreamPlayer = $MusicPlayer


func play_music(
	music: AudioStream,
	restart: bool = false
) -> void:
	if not music:
		return

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
