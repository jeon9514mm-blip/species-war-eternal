class_name HapticDirector
extends RefCounted
## One bounded pattern per event. Tests inject a sink, never vibrate hardware.
const HERO_FEEDBACK = preload('res://scripts/presentation/HeroSkillFeedbackCatalog.gd')
var _generation := 0
var mode: String = "off":
	set(value):
		if value != mode:_generation+=1
		mode=value
var suspended: bool = false:
	set(value):
		if value and not suspended:_generation+=1
		suspended=value
var combat_paused: bool = false:
	set(value):
		if value and not combat_paused:_generation+=1
		combat_paused=value
var sink: Callable
var _last_ms: int = -10000
var accepted: int = 0
const PULSES := {"ui_click": [12, 0.22], "equip": [18, 0.32], "upgrade": [25, 0.4],
	"reward": [22, 0.3], "summon": [40, 0.5], "victory": [55, 0.55], "ultimate": [30, 0.45],
	"boss_warning": [50, 0.65], "shield_break": [35, 0.5], "critical": [18, 0.34],
	"hit": [10, 0.14], "skill": [25, 0.36], "gold": [22, 0.3]}

func pulse(event: String, now_ms: int = -1) -> bool:
	if mode == "off" or suspended or not PULSES.has(event): return false
	if combat_paused and event not in ['ui_click','equip','upgrade','reward','summon','victory','gold']:return false
	var now: int = Time.get_ticks_msec() if now_ms < 0 else now_ms
	var gap: int = 200 if event in ["ui_click", "equip", "upgrade"] else 500
	if now - _last_ms < gap: return false
	var spec: Array = PULSES[event]
	var duration: int = mini(80, int(spec[0]))
	var strength: float = float(spec[1]) * (0.5 if mode == "light" else 1.0)
	if not _emit_pulse(duration,strength):return false
	_generation+=1
	_last_ms = now
	accepted += 1
	return true

func pulse_hero_skill(hero_id: String,slot: String,now_ms: int = -1) -> bool:
	if mode=='off' or suspended or combat_paused:return false
	var profile: Dictionary=HERO_FEEDBACK.profile(hero_id,slot)
	if profile.is_empty():return false
	var now: int=Time.get_ticks_msec() if now_ms<0 else now_ms
	var gap:=800 if slot=='passive' else 700 if slot=='ultimate' else 500
	if now-_last_ms<gap:return false
	var pattern: Array=profile.haptic
	var first: Array=pattern[0]
	var attenuation:=.5 if mode=='light' else 1.0
	if not _emit_pulse(int(first[1]),float(first[2])*attenuation):return false
	_generation+=1;_last_ms=now;accepted+=1
	if pattern.size()>1:_play_pattern_tail(pattern,_generation,attenuation)
	return true

func _emit_pulse(duration: int,strength: float) -> bool:
	duration=clampi(duration,1,80);strength=clampf(strength,0.0,.75)
	if sink.is_valid():sink.call(duration,strength);return true
	if OS.has_feature('android') or OS.has_feature('ios'):
		Input.vibrate_handheld(duration,strength);return true
	return false

func _play_pattern_tail(pattern: Array,generation: int,attenuation: float) -> void:
	var tree:=Engine.get_main_loop() as SceneTree
	if tree==null:return
	var offset:=0
	for index in range(1,pattern.size()):
		var step: Array=pattern[index]
		# At most two lightweight timers for a real accepted ultimate; no polling
		# node, allocation per frame, or unbounded pattern queue is created.
		await tree.create_timer(float(int(step[0])-offset)/1000.0,false,false,true).timeout
		if generation!=_generation or suspended or combat_paused or mode=='off':return
		_emit_pulse(int(step[1]),float(step[2])*attenuation)
		offset=int(step[0])
