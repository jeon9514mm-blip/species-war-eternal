extends SceneTree
const FEEDBACK=preload('res://scripts/presentation/HeroSkillFeedbackCatalog.gd')
const STYLE=preload('res://scripts/combat/CombatNumberStyle.gd')
const NUMBERS=preload('res://scripts/combat/DamageNumberManager.gd')
var failures: Array[String]=[]
var checks:=0
class SpatialField:
	extends Node
	var world: Node3D
	var viewport_3d: SubViewport
	func _ready() -> void:
		viewport_3d=SubViewport.new();viewport_3d.own_world_3d=true;add_child(viewport_3d)
		world=Node3D.new();viewport_3d.add_child(world)
		var camera:=Camera3D.new();camera.position=Vector3(0,40,28);camera.current=true;world.add_child(camera)
func _init() -> void:_run.call_deferred()
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures.append(message);push_error(message)
func _run() -> void:
	var patterns: Dictionary={};var paths: Dictionary={};var waveforms: Dictionary={}
	var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string('res://audio/ultra-skills/manifest.json'))
	check(FEEDBACK.HEROES.size()==30 and manifest.unique_waveforms==120,'all 30 registered heroes have 120 original skill cues')
	for hero_id in HeroRosterCatalog.HEROES:
		for slot in FEEDBACK.SLOTS:
			var profile: Dictionary=FEEDBACK.profile(str(hero_id),str(slot))
			check(not profile.is_empty(),'registered hero/slot has feedback '+str(hero_id)+':'+str(slot))
			if profile.is_empty():continue
			paths[profile.path]=true;patterns[JSON.stringify(profile.haptic)]=true
			var hash:=FileAccess.get_sha256(str(profile.path));waveforms[hash]=true
			var stream: AudioStream=load(str(profile.path))
			check(stream is AudioStreamWAV and stream.get_length()>0.0 and stream.get_length()<=.73,'short PCM skill cue decodes '+str(hero_id)+':'+str(slot))
	check(paths.size()==120 and patterns.size()==120 and waveforms.size()==120,'120 paths, waveform bytes and haptic patterns are distinct')
	check(int(manifest.sample_bytes)<2100000,'all original skill audio fits within 2.1 MB on disk')
	check(FEEDBACK.profile('unknown','a1').is_empty() and FEEDBACK.profile('leonhardt','fake').is_empty(),'unknown hero or fabricated slot has no cue')
	var audio:=GameAudioDirector.new();root.add_child(audio);audio.set_process(false);audio.configure({},true)
	var field:=SpatialField.new();root.add_child(field)
	seed(2026100814);var first:=randi()
	check(audio.play_hero_skill('leonhardt','a1',field,Vector2(-3,7)),'confirmed skill accepts a world-space hero cue')
	var second:=randi();seed(2026100814)
	check(randi()==first and randi()==second,'hero cue variation never consumes global combat RNG')
	check(audio.spatial_voices.size()==4 and audio.spatial_voices[0].position==Vector3(-3,.15,7),'hero cue uses actual battle listener and bounded 3D voices')
	check(not audio.play_hero_skill('leonhardt','a1',field,Vector2.ZERO),'same cast sound is throttled immediately')
	for hero_id in FEEDBACK.HEROES:
		for slot in FEEDBACK.SLOTS:
			audio._process(1.0)
			check(audio.play_hero_skill(str(hero_id),str(slot),field,Vector2.ZERO),'real cue can play '+str(hero_id)+':'+str(slot))
		await process_frame
	check(audio.max_active_voices<=8 and audio._cue_cache.size()<=120 and field.world.get_child_count()==5,'all 120 cues reuse fixed world nodes and shared eight-voice budget')
	audio.combat_paused=true
	check(not audio.play_hero_skill('mira','ultimate',field),'pause rejects hero-specific ultimate audio')
	audio.combat_paused=false;audio._process(1.0);audio.configure({'effects_volume':0.0},true)
	check(not audio.play_hero_skill('mira','a2',field),'saved effects volume opt-out rejects hero cue')
	audio.configure({},true);audio.set_suspended(true)
	check(not audio.play_hero_skill('mira','a1',field),'application suspension rejects hero cue')
	var haptic:=HapticDirector.new();var pulses: Array=[]
	haptic.sink=func(duration: int,strength: float):pulses.append([duration,strength])
	check(not haptic.pulse_hero_skill('mira','ultimate',0),'saved haptic default remains off')
	haptic.mode='light'
	check(haptic.pulse_hero_skill('mira','ultimate',0) and not haptic.pulse_hero_skill('mira','a1',10),'hero haptic patterns share one common throttle')
	await create_timer(.28,false,false,true).timeout
	check(pulses.size()==3 and pulses[0][0]<=80 and pulses[2][1]<=.375,'accepted ultimate emits exactly three bounded light-mode pulses')
	check(haptic.pulse_hero_skill('mira','ultimate',800),'next real cast can play after shared cooldown')
	haptic.suspended=true
	await create_timer(.28,false,false,true).timeout
	check(pulses.size()==4,'background cancellation retires remaining scheduled haptic pulses')
	haptic.suspended=false;haptic.combat_paused=true
	check(not haptic.pulse_hero_skill('mira','a1',1800) and haptic.pulse('ui_click',1800),'combat pause rejects skill pattern while leaving UI feedback available')
	var pool:=NUMBERS.new();root.add_child(pool)
	var bounds:=Rect2(0,0,1280,400)
	var number: Label=pool.spawn_damage('',Color.WHITE,Vector2(300,250),false,0,bounds,'damage','target',100)
	check(STYLE.font_size('damage')==18 and number.get_theme_constant('outline_size')==3 and NUMBERS.CAPACITY==50,'18px face, 3px outline and fifty pooled number ceiling')
	check(number.text=='100' and number.amount==100 and number._visual_amount<100,'visual count-up preserves exact semantic text and settled amount')
	number.issued_at=Time.get_ticks_msec()-91;number._process(.10)
	check(number._visual_amount==100,'visual count-up reaches exact settled amount within 90 ms')
	var combined: Label=pool.spawn_damage('',Color.WHITE,Vector2(300,250),false,1,bounds,'damage','target',80)
	check(combined==number and combined.text=='180' and combined.amount==180,'same-target multi-hit counts still sum exact actual totals')
	var gold: Label=pool.spawn_damage('',Color.WHITE,Vector2(800,250),true,2,bounds,'damage','crit',200)
	var diamond: Label=pool.spawn_damage('',Color.WHITE,Vector2(800,250),true,3,bounds,'damage','ult',240,{'ultimate_critical':true})
	check(gold._number_color==Color('#ffd700') and diamond._number_color==Color('#00ffff'),'gold remains normal critical and cyan requires explicit confirmed ultimate critical context')
	var life=number._life_tween;life.pause();life.custom_step(.50)
	check(number.visible and number.modulate.a==1.0 and is_equal_approx(number.scale.x,1.5),'number reaches 1.5 scale and stays opaque for the readable hold')
	life.custom_step(.29);check(number.visible,'number remains visible before .80 seconds')
	life.custom_step(.02);check(not number.visible and number.feedback_context.is_empty(),'number retires after .80 seconds and clears reused context')
	pool.queue_free();audio.shutdown();audio.queue_free();field.queue_free()
	await create_timer(.3).timeout
	print('ultra_damage_audio checks=%d failures=%s actual_haptic_device_test=false'%[checks,JSON.stringify(failures)])
	quit(0 if failures.is_empty() else 1)
