extends Node

var sounds = {
	"click": preload("res://audio/ui/click.ogg"),
	"hover": preload("res://audio/ui/hover.ogg"),
	"card_play": preload("res://audio/effects/card_play.ogg"),
	"resource_gain": preload("res://audio/effects/resource_gain.ogg"),
	"resource_loss": preload("res://audio/effects/resource_loss.ogg"),
	"move": preload("res://audio/effects/move.ogg")
}

# Фоновая музыка
var music_player: AudioStreamPlayer
var current_music: String = ""

func _ready():
	# Создаем отдельный плеер для музыки
	music_player = AudioStreamPlayer.new()
	add_child(music_player)
	
	# Настраиваем зацикливание
	music_player.finished.connect(func(): 
		if current_music != "":
			music_player.play()
	)

func play_sound(sound_name: String):
	if sounds.has(sound_name):
		var player = AudioStreamPlayer.new()
		add_child(player)
		player.stream = sounds[sound_name]
		player.play()
		await player.finished
		player.queue_free()

func play_music(track_path: String, volume: float = -10):
	if current_music == track_path:
		return
		
	current_music = track_path
	
	var music = load(track_path)
	if music:
		music_player.stream = music
		music_player.volume_db = volume
		music_player.play()

func stop_music():
	music_player.stop()
	current_music = ""
	
func set_music_volume(volume: float):
	music_player.volume_db = volume
