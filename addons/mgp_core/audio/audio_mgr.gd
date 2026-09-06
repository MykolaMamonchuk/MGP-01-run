## Звук: SFX-пул, музика, голос. Поки без файлів — шини й API готові.
## Autoload: AudioMgr.
extends Node

var _sfx_players: Array[AudioStreamPlayer] = []
var _music: AudioStreamPlayer
var _voice: AudioStreamPlayer
var _cache: Dictionary = {}

func _ready() -> void:
	for i in 8:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_sfx_players.append(p)
	_music = AudioStreamPlayer.new()
	add_child(_music)
	_voice = AudioStreamPlayer.new()
	add_child(_voice)

func _load(path: String) -> AudioStream:
	if not _cache.has(path):
		_cache[path] = load(path) if ResourceLoader.exists(path) else null
	return _cache[path]

func sfx(sfx_name: String, pitch: float = 1.0) -> void:
	if not SaveService.setting("sfx", true):
		return
	var s := _load("res://assets/audio/sfx/%s.ogg" % sfx_name)
	if s == null:
		return
	for p in _sfx_players:
		if not p.playing:
			p.stream = s
			p.pitch_scale = pitch
			p.play()
			return

func music(music_name: String) -> void:
	if not SaveService.setting("music", true):
		_music.stop()
		return
	var s := _load("res://assets/audio/music/%s.ogg" % music_name)
	if s and _music.stream != s:
		_music.stream = s
		_music.play()

func voice(line: String) -> void:
	if not SaveService.setting("voice", true):
		return
	var lang := String(SaveService.setting("lang", "uk"))
	var s := _load("res://assets/audio/voice/%s/%s.ogg" % [lang, line])
	if s:
		_voice.stream = s
		_voice.play()
