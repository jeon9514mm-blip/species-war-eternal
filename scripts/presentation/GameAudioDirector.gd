class_name GameAudioDirector
extends Node
## Sample playback only. No runtime wave synthesis and no gameplay RNG use.
const ROOT := "res://audio/v82/"
const CUES := {"ui_click": ["ui_click", "ui", 3, 0.055], "equip": ["equip", "ui", 4, 0.12],
	"upgrade": ["upgrade", "ui", 4, 0.20], "reward": ["reward", "ui", 4, 0.3],
	"summon": ["summon", "ui", 5, 0.7], "victory": ["victory", "ui", 6, 1.0],
	"defeat": ["defeat", "ui", 6, 1.0], "sword": ["sword", "effects", 1, 0.09],
	"bow": ["bow", "effects", 1, 0.09], "magic": ["magic", "effects", 1, 0.12],
	"guard": ["guard", "effects", 2, 0.22], "heal": ["heal", "effects", 2, 0.22],
	"control": ["control", "effects", 2, 0.22], "ultimate": ["ultimate", "effects", 5, 0.5],
	"critical": ["critical", "effects", 3, 0.18], "boss_warning": ["boss_warning", "effects", 7, 0.65],
	"shield_break": ["shield_break", "effects", 5, 0.45]}
const VOICE_LIMIT := 8
var options: Dictionary = PresentationSettings.DEFAULTS.duplicate(true)
var sound_enabled: bool = true
var suspended: bool = false
var combat_paused: bool = false
var _closing: bool = false
var music_players: Array[AudioStreamPlayer] = []
var ambient_player: AudioStreamPlayer
var voices: Array[AudioStreamPlayer] = []
var _cue_cache: Dictionary = {}
var _last_cue: Dictionary = {}
var _voice_until: Array[float] = []
var _voice_priority: Array[int] = []
var _voice_channel: Array[String] = []
var _clock: float = 0.0
var _window_start: float = 0.0
var _window_count: int = 0
var _fade_time: float = 0.0
var _active_music: int = 0
var _music_key: String = ""
var _ambient_key: String = ""
var _target_music: String = ""
var _target_ambient: String = ""
var accepted: int = 0
var suppressed: int = 0
var max_active_voices: int = 0
var sample_loads: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for index in 2:
		var p := AudioStreamPlayer.new(); p.name = "Music%d" % index; add_child(p); music_players.append(p)
	ambient_player = AudioStreamPlayer.new(); ambient_player.name = "Ambience"; add_child(ambient_player)
	for index in VOICE_LIMIT:
		var p := AudioStreamPlayer.new(); p.name = "Voice%d" % index; add_child(p); voices.append(p)
		_voice_until.append(0.0); _voice_priority.append(0); _voice_channel.append("effects")
	_apply_gains()

func _process(delta: float) -> void:
	if suspended: return
	_clock += maxf(0.0, delta)
	if _fade_time > 0.0:
		_fade_time = maxf(0.0, _fade_time - delta)
		_apply_gains()
		if _fade_time <= 0.0:
			var previous: AudioStreamPlayer = music_players[1 - _active_music]
			previous.stop(); previous.stream = null

func configure(raw: Dictionary, effects_enabled: bool) -> void:
	if _closing: return
	options = PresentationSettings.sanitize(raw); sound_enabled = effects_enabled
	if music_players.is_empty(): return
	if not sound_enabled:
		for index in voices.size(): voices[index].stop(); _voice_until[index] = _clock
		ambient_player.stop(); ambient_player.stream = null; _ambient_key = ""
	if not options["music_enabled"] or float(options["music_volume"]) <= 0.0:
		for player in music_players: player.stop(); player.stream = null
		_music_key = ""; _fade_time = 0.0
	_apply_gains()
	set_scene(_target_music, _target_ambient)

func set_suspended(value: bool) -> void:
	suspended = value
	for p in music_players: p.stream_paused = value
	if is_instance_valid(ambient_player): ambient_player.stream_paused = value
	if value:
		for index in voices.size(): voices[index].stop(); _voice_until[index] = _clock

func _gain(channel: String) -> float:
	if channel == "music": return float(options["music_volume"]) if options["music_enabled"] else 0.0
	if not sound_enabled: return 0.0
	return float(options.get(channel + "_volume", 0.0))

func _apply_gains() -> void:
	if music_players.size() != 2: return
	var incoming: float = 1.0 - _fade_time / 0.65 if _fade_time > 0.0 else 1.0
	music_players[_active_music].volume_linear = _gain("music") * incoming
	music_players[1 - _active_music].volume_linear = _gain("music") * (1.0 - incoming)
	ambient_player.volume_linear = _gain("ambient")
	for index in voices.size(): voices[index].volume_linear = _gain(_voice_channel[index]) * 0.60

func _stream(key: String, looped: bool) -> AudioStream:
	var path: String = ROOT + key + (".ogg" if looped else ".wav")
	if not ResourceLoader.exists(path): return null
	var original: Resource = load(path)
	if not original is AudioStream: return null
	var stream: AudioStream = original.duplicate() as AudioStream
	if stream is AudioStreamOggVorbis: stream.loop = looped
	sample_loads += 1
	return stream

func set_scene(music_key: String, ambient_key: String = "") -> void:
	_target_music = music_key; _target_ambient = ambient_key
	if _closing or music_players.is_empty() or suspended: return
	if _gain("music") > 0.0 and music_key != _music_key:
		var next_stream: AudioStream = _stream(music_key, true) if not music_key.is_empty() else null
		if next_stream != null:
			_active_music = 1 - _active_music
			var player: AudioStreamPlayer = music_players[_active_music]
			player.stop(); player.stream = next_stream; player.volume_linear = 0.0; player.play()
			_music_key = music_key; _fade_time = 0.65
		else:
			for player in music_players: player.stop(); player.stream = null
			_music_key = ""
	if _gain("ambient") <= 0.0 or ambient_key.is_empty():
		ambient_player.stop(); ambient_player.stream = null; _ambient_key = ""
	elif ambient_key != _ambient_key:
		ambient_player.stop(); ambient_player.stream = _stream(ambient_key, true)
		if ambient_player.stream != null: ambient_player.play(); _ambient_key = ambient_key
	_apply_gains()

func play_cue(event: String) -> bool:
	if _closing or suspended or not CUES.has(event) or voices.is_empty(): return false
	var cue: Array = CUES[event]
	if _gain(str(cue[1])) <= 0.0 or (combat_paused and str(cue[1]) == "effects"): return false
	if _clock - _window_start >= 1.0: _window_start = _clock; _window_count = 0
	if _clock - float(_last_cue.get(event, -100.0)) < float(cue[3]) or (_window_count >= 18 and int(cue[2]) < 5):
		suppressed += 1; return false
	var index: int = -1
	for i in voices.size():
		if _voice_until[i] <= _clock: index = i; break
	if index < 0:
		var lowest: int = int(cue[2])
		for i in voices.size():
			if _voice_priority[i] < lowest: lowest = _voice_priority[i]; index = i
	if index < 0: suppressed += 1; return false
	if not _cue_cache.has(event):
		var sample: AudioStream = _stream(str(cue[0]), false)
		if sample == null: return false
		_cue_cache[event] = sample
	var stream: AudioStream = _cue_cache[event]
	var player: AudioStreamPlayer = voices[index]
	player.stop(); player.stream = stream
	_voice_channel[index] = str(cue[1]); _voice_priority[index] = int(cue[2])
	player.volume_linear = _gain(_voice_channel[index]) * 0.60
	player.play(); _voice_until[index] = _clock + maxf(0.04, stream.get_length())
	_last_cue[event] = _clock; _window_count += 1; accepted += 1
	max_active_voices = maxi(max_active_voices, active_voice_count())
	return true

func active_voice_count() -> int:
	var count: int = 0
	for until in _voice_until:
		if until > _clock: count += 1
	return count

func diagnostics() -> Dictionary:
	return {"music": _music_key, "ambient": _ambient_key, "accepted": accepted, "suppressed": suppressed,
		"active_voices": active_voice_count(), "max_voices": max_active_voices, "voice_nodes": voices.size(),
		"sample_loads": sample_loads, "cached_sfx": _cue_cache.size(), "suspended": suspended}

func shutdown() -> void:
	_closing = true; suspended = true; set_process(false)
	for index in _voice_until.size(): _voice_until[index] = _clock
	for p in music_players: p.stop(); p.stream = null
	for p in voices: p.stop(); p.stream = null
	if is_instance_valid(ambient_player): ambient_player.stop(); ambient_player.stream = null
	_cue_cache.clear()

func _exit_tree() -> void:
	shutdown()
