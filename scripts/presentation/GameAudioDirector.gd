class_name GameAudioDirector
extends Node
## Sample playback only. Voice budget is shared by UI and world-space feedback.
const ROOT := "res://audio/v82/"
const CUES := {"ui_click": ["ui_click", "ui", 3, 0.055], "equip": ["equip", "ui", 4, 0.12],
	"upgrade": ["upgrade", "ui", 4, 0.20], "reward": ["res://audio/final-feedback/Gold.wav", "ui", 4, 0.3],
	"summon": ["summon", "ui", 5, 0.7], "victory": ["victory", "ui", 6, 1.0],
	"defeat": ["defeat", "ui", 6, 1.0], "sword": ["sword", "effects", 1, 0.09],
	"bow": ["bow", "effects", 1, 0.09], "magic": ["magic", "effects", 1, 0.12],
	"guard": ["guard", "effects", 2, 0.22], "heal": ["heal", "effects", 2, 0.22],
	"control": ["control", "effects", 2, 0.22], "ultimate": ["ultimate", "effects", 5, 0.5],
	"critical": ["res://audio/final-feedback/Crit.wav", "effects", 3, 0.18], "boss_warning": ["boss_warning", "effects", 7, 0.65],
	"hit": ["res://audio/final-feedback/Hit.wav", "effects", 1, 0.09],
	"skill": ["res://audio/final-feedback/Skill.wav", "effects", 4, 0.20],
	"gold": ["res://audio/final-feedback/Gold.wav", "ui", 4, 0.30],
	"phase_change": ["boss_warning", "effects", 7, 0.65],
	"shield_break": ["shield_break", "effects", 5, 0.45],
	"monster_bold":["monster_bold","effects",1,.5],"monster_pack":["monster_pack","effects",1,.5],
	"monster_cautious":["monster_cautious","effects",1,.5],"monster_flanker":["monster_flanker","effects",1,.5]}
const VOICE_LIMIT := 8
const SPATIAL_LIMIT := 4
var options: Dictionary = PresentationSettings.DEFAULTS.duplicate(true)
var sound_enabled: bool = true
var suspended: bool = false
var combat_paused: bool = false:
	set(value):
		combat_paused=value
		if value:
			_stop_spatial()
			for index in voices.size():
				if _voice_channel[index]=='effects':voices[index].stop();_voice_until[index]=_clock
var _closing: bool = false
var music_players: Array[AudioStreamPlayer] = []
var ambient_player: AudioStreamPlayer
var voices: Array[AudioStreamPlayer] = []
var _cue_cache: Dictionary = {}
var _last_cue: Dictionary = {}
var _voice_until: Array[float] = []
var _voice_priority: Array[int] = []
var _voice_channel: Array[String] = []
var _voice_variation: Array[float] = []
var spatial_voices: Array[AudioStreamPlayer3D] = []
var _spatial_until: Array[float] = []
var _spatial_priority: Array[int] = []
var _spatial_channel: Array[String] = []
var _spatial_variation: Array[float] = []
var _spatial_field: Node
var _feedback_rng:=RandomNumberGenerator.new()
var positional_accepted:=0
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
	_feedback_rng.seed=20261008+get_instance_id()
	for index in 2:
		var p := AudioStreamPlayer.new(); p.name = "Music%d" % index; add_child(p); music_players.append(p)
	ambient_player = AudioStreamPlayer.new(); ambient_player.name = "Ambience"; add_child(ambient_player)
	for index in VOICE_LIMIT:
		var p := AudioStreamPlayer.new(); p.name = "Voice%d" % index; add_child(p); voices.append(p)
		_voice_until.append(0.0); _voice_priority.append(0); _voice_channel.append("effects");_voice_variation.append(1.0)
	_apply_gains()

func _process(delta: float) -> void:
	if suspended: return
	if is_instance_valid(_spatial_field) and (_spatial_field.get('presentation_visible')==false or _spatial_field.get('presentation_suspended')==true):_stop_spatial()
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
		_stop_spatial()
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
		_stop_spatial()

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
	for index in voices.size(): voices[index].volume_linear = _gain(_voice_channel[index]) * 0.60*_voice_variation[index]
	for index in spatial_voices.size():
		if is_instance_valid(spatial_voices[index]):spatial_voices[index].volume_linear=_gain(_spatial_channel[index])*.60*_spatial_variation[index]

func _stream(key: String, looped: bool) -> AudioStream:
	var path: String = key if key.begins_with('res://') else ROOT + key + (".ogg" if looped else ".wav")
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
	if not _admit_event(event):return false
	var cue: Array = CUES[event]
	if not _reserve_budget(int(cue[2])):return false
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
	_voice_variation[index]=_feedback_rng.randf_range(.92,1.0)
	player.pitch_scale=_feedback_rng.randf_range(.94,1.06) if _voice_channel[index]=='effects' else _feedback_rng.randf_range(.98,1.02)
	player.volume_linear = _gain(_voice_channel[index]) * 0.60*_voice_variation[index]
	player.play(); _voice_until[index] = _clock + maxf(0.04, stream.get_length()/player.pitch_scale)
	_record_event(event)
	return true

func _admit_event(event: String) -> bool:
	if _closing or suspended or not CUES.has(event) or voices.is_empty():return false
	var cue: Array=CUES[event]
	if _gain(str(cue[1]))<=0 or (combat_paused and str(cue[1])=='effects'):return false
	if _clock-_window_start>=1.0:_window_start=_clock;_window_count=0
	if _clock-float(_last_cue.get(event,-100.0))<float(cue[3]) or (_window_count>=18 and int(cue[2])<5):
		suppressed+=1;return false
	return true

func _record_event(event: String) -> void:
	_last_cue[event]=_clock;_window_count+=1;accepted+=1
	max_active_voices=maxi(max_active_voices,active_voice_count())

func _reserve_budget(priority: int) -> bool:
	if active_voice_count()<VOICE_LIMIT:return true
	var lowest:=priority;var chosen:=-1;var spatial:=false
	for i in _voice_until.size():
		if _voice_until[i]>_clock and _voice_priority[i]<lowest:lowest=_voice_priority[i];chosen=i
	for i in _spatial_until.size():
		if _spatial_until[i]>_clock and _spatial_priority[i]<lowest:lowest=_spatial_priority[i];chosen=i;spatial=true
	if chosen<0:suppressed+=1;return false
	if spatial:
		if is_instance_valid(spatial_voices[chosen]):spatial_voices[chosen].stop()
		_spatial_until[chosen]=_clock
	else:voices[chosen].stop();_voice_until[chosen]=_clock
	return true

func _stop_spatial() -> void:
	for i in spatial_voices.size():
		if is_instance_valid(spatial_voices[i]):spatial_voices[i].stop()
		_spatial_until[i]=_clock

func _bind_spatial(field: Node) -> bool:
	if not is_instance_valid(field) or not is_instance_valid(field.get('world')) or not is_instance_valid(field.get('viewport_3d')):return false
	if _spatial_field==field and spatial_voices.size()==SPATIAL_LIMIT and is_instance_valid(spatial_voices[0]):return true
	_stop_spatial()
	for player in spatial_voices:
		if is_instance_valid(player):player.queue_free()
	spatial_voices.clear();_spatial_until.clear();_spatial_priority.clear();_spatial_channel.clear();_spatial_variation.clear()
	_spatial_field=field
	# Each embedded battle owns a World3D. Enable that viewport's current camera listener.
	field.viewport_3d.audio_listener_enable_3d=true
	for index in SPATIAL_LIMIT:
		var player:=AudioStreamPlayer3D.new();player.name='WorldFeedbackVoice%d'%index
		player.unit_size=48.0;player.max_distance=160.0;player.panning_strength=1.6
		player.attenuation_filter_cutoff_hz=12000;player.max_polyphony=1
		field.world.add_child(player);spatial_voices.append(player)
		_spatial_until.append(0.0);_spatial_priority.append(0);_spatial_channel.append('effects');_spatial_variation.append(1.0)
	return true

func play_positional(event: String,field: Node,point: Vector2) -> bool:
	if not _admit_event(event):return false
	if not _bind_spatial(field):return play_cue(event)
	var cue: Array=CUES[event]
	if not _reserve_budget(int(cue[2])):return false
	var index:=-1
	for i in spatial_voices.size():
		if _spatial_until[i]<=_clock:index=i;break
	if index<0:
		var lowest:=int(cue[2])
		for i in spatial_voices.size():
			if _spatial_priority[i]<lowest:lowest=_spatial_priority[i];index=i
	if index<0:suppressed+=1;return false
	if not _cue_cache.has(event):
		var sample:=_stream(str(cue[0]),false)
		if sample==null:return false
		_cue_cache[event]=sample
	var stream: AudioStream=_cue_cache[event]
	var player: AudioStreamPlayer3D=spatial_voices[index];player.stop();player.stream=stream
	player.position=Vector3(point.x,.15,point.y)
	_spatial_channel[index]=str(cue[1]);_spatial_priority[index]=int(cue[2]);_spatial_variation[index]=_feedback_rng.randf_range(.92,1.0)
	player.pitch_scale=_feedback_rng.randf_range(.94,1.06);player.volume_linear=_gain(_spatial_channel[index])*.60*_spatial_variation[index]
	player.play();_spatial_until[index]=_clock+maxf(.04,stream.get_length()/player.pitch_scale)
	positional_accepted+=1;_record_event(event);return true

func active_voice_count() -> int:
	var count: int = 0
	for until in _voice_until:
		if until > _clock: count += 1
	for index in _spatial_until.size():
		if is_instance_valid(spatial_voices[index]) and _spatial_until[index]>_clock:count+=1
	return count

func diagnostics() -> Dictionary:
	return {"music": _music_key, "ambient": _ambient_key, "accepted": accepted, "suppressed": suppressed,
		"active_voices": active_voice_count(), "max_voices": max_active_voices, "voice_nodes": voices.size(),
		"sample_loads": sample_loads, "cached_sfx": _cue_cache.size(), "suspended": suspended,
		"positional_accepted":positional_accepted,"spatial_voice_nodes":spatial_voices.size(),"shared_voice_limit":VOICE_LIMIT}

func shutdown() -> void:
	_closing = true; suspended = true; set_process(false)
	for index in _voice_until.size(): _voice_until[index] = _clock
	for p in music_players: p.stop(); p.stream = null
	for p in voices: p.stop(); p.stream = null
	_stop_spatial()
	for p in spatial_voices:
		if is_instance_valid(p):p.stream=null;p.queue_free()
	spatial_voices.clear();_spatial_until.clear();_spatial_priority.clear();_spatial_channel.clear();_spatial_variation.clear();_spatial_field=null
	if is_instance_valid(ambient_player): ambient_player.stop(); ambient_player.stream = null
	_cue_cache.clear()

func _exit_tree() -> void:
	shutdown()
