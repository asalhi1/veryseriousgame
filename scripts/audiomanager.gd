extends Node

var music_player: AudioStreamPlayer = AudioStreamPlayer.new()
var playing_intro: bool = true

var intro_track: AudioStream = preload("res://assets/music/intro.wav")
var loop_track: AudioStream = preload("res://assets/music/loop.wav")

func _ready() -> void:
  music_player = AudioStreamPlayer.new()
  add_child(music_player)
  
  music_player.finished.connect(_on_music_finished)

func start_soundtrack() -> void:
  if music_player.playing:
    return
  
  music_player.stream = intro_track
  music_player.play()
  playing_intro = true

func _on_music_finished() -> void:
  if playing_intro:
    playing_intro = false
    music_player.stream = loop_track
    music_player.play()
