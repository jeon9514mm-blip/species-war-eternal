extends SceneTree
const ROUTER=preload('res://scripts/presentation/HeroSkillPresentationRouter.gd')
const FEEDBACK=preload('res://scripts/presentation/HeroSkillFeedbackCatalog.gd')
const VISUAL=preload('res://scripts/presentation/HeroSkillVfxCatalog.gd')
const KITS=preload('res://scripts/heroes/HeroKitRuntime.gd')
const ROSTER=preload('res://scripts/heroes/HeroRosterCatalog.gd')
var checks:=0
var failures: Array[String]=[]
class AudioSink:
	extends Node
	var events: Array=[]
	func play_hero_skill(hero_id: String,slot: String,_field: Node,point: Vector2,ultimate: bool) -> bool:
		events.append({'hero':hero_id,'slot':slot,'point':point,'ultimate':ultimate});return true
class HapticSink:
	extends RefCounted
	var events: Array=[]
	func pulse_hero_skill(hero_id: String,slot: String) -> bool:
		events.append([hero_id,slot]);return true
class RuntimeSink:
	extends Node
	var audio:=AudioSink.new()
	var haptics:=HapticSink.new()
	func _ready() -> void:add_child(audio)
class OverlaySink:
	extends Control
	var events: Array=[]
	var ultimates: Array=[]
	func cast(hero_id: String,target: int,aoe: bool,profile: Dictionary,ultimate: bool) -> bool:
		events.append({'hero':hero_id,'target':target,'aoe':aoe,'profile':profile.duplicate(true),'ultimate':ultimate});return true
	func show_ultimate(hero_id: String,detail: String) -> bool:
		ultimates.append([hero_id,detail]);return true
class FieldSink:
	extends Control
	var skill_overlay:=OverlaySink.new()
	var running:=true
	var raid_mode:=false
	func _ready() -> void:add_child(skill_overlay)
	func battle_clock_running() -> bool:return running
	func raid_to_world(point: Vector2) -> Vector2:return point*.125
class HuntIdentity:
	extends RefCounted
	var encounter_id:=7
class RaidViewSink:
	extends Control
	var battlefield_3d: Control
class RouterHost:
	extends Node
	var active_screen: String='combat'
	var content_root: Control
	var combat_labels: Dictionary={}
	var presentation_runtime:=RuntimeSink.new()
	var _skill_audio_tokens: Dictionary={}
	var raid_encounter_serial:=4
	var hunt_ai:=HuntIdentity.new()
	var raid_positions: Dictionary={}
	var hero_battle_state: Dictionary={}
	var hero_skill_runtime: Dictionary={}
	var enemy_wave: Array=[{'hp':100,'max_hp':100,'elite':false}]
	var fallback_events: Array=[]
	var passive_hooks:=0
	var earned_energy:=0.0
	var loot_rng:=RandomNumberGenerator.new()
	func _ready() -> void:add_child(presentation_runtime)
	func _hero_field_position(hero_id: String) -> Vector2:return Vector2(hero_id.length(),3)
	func _presentation_event(event: String) -> void:fallback_events.append(event)
	func _lowest_hp_hero_id() -> String:return 'mira'
	func _alive_hero_ids() -> Array[String]:return ['leonhardt','mira']
	func _gain_ultimate(_hero_id: String,amount: float) -> void:earned_energy+=amount
	func _emit_passive_proc_fx(hero_id: String,target: int,profile: Dictionary,lowest: String) -> void:
		passive_hooks+=1
		preload('res://scripts/presentation/HeroSkillPresentationRouter.gd').passive(self,hero_id,target,profile,lowest)
func _init() -> void:_run.call_deferred()
func check(ok: bool,note: String) -> void:
	checks+=1
	if not ok:failures.append(note);push_error(note)
func _run() -> void:
	var main:=RouterHost.new();root.add_child(main)
	var field:=FieldSink.new();root.add_child(field);main.combat_labels.terrain=field
	main.loot_rng.seed=1478
	for hero_id in ROSTER.HEROES:
		main.hero_battle_state[hero_id]={'hp':100,'max_hp':100,'guard':0.0,'shield':0,'slot':0}
		main.hero_skill_runtime[hero_id]={'passive_procs':0,'passive_count':0,'passive_remaining':0.0}
	var state:=main.hero_battle_state.duplicate(true);var runtime:=main.hero_skill_runtime.duplicate(true);var rng: int=main.loot_rng.state
	var identities: Dictionary={}
	for hero_id in ROSTER.HEROES:
		for slot in FEEDBACK.SLOTS:
			var profile: Dictionary=ROSTER.skill(str(hero_id),str(slot))
			profile['fx_slot']=slot;profile['fx_cast_serial']=1
			var snapshot:=profile.duplicate(true)
			ROUTER.emit(main,str(hero_id),0,false,profile,slot=='ultimate')
			var event: Dictionary=main.presentation_runtime.audio.events.back()
			check(event.hero==hero_id and event.slot==slot and event.ultimate==(slot=='ultimate'),'routes actual hero/slot '+str(hero_id)+':'+str(slot))
			check(profile==snapshot and not VISUAL.profile(str(hero_id),str(slot)).is_empty(),'registered cast profile remains unchanged and has native visual identity')
			identities[FEEDBACK.profile(str(hero_id),str(slot)).path]=true
	check(identities.size()==120 and main.presentation_runtime.audio.events.size()==120 and main.presentation_runtime.haptics.events.size()==120,'all 120 unique identities reach audio and haptic sinks')
	check(main._skill_audio_tokens.size()<=64 and main.hero_battle_state==state and main.hero_skill_runtime==runtime and main.loot_rng.state==rng,'routing is bounded and cannot change combat state or RNG')
	var cast:=ROSTER.skill('selene','ultimate');cast['fx_slot']='ultimate';cast['fx_cast_serial']=1
	var count: int=main.presentation_runtime.audio.events.size()
	ROUTER.emit(main,'selene',0,false,cast,true)
	check(main.presentation_runtime.audio.events.size()==count,'duplicate confirmed cast cannot play audio or haptics twice')
	field.running=false;cast.fx_cast_serial=2
	ROUTER.emit(main,'selene',0,false,cast,true)
	check(main.presentation_runtime.audio.events.size()==count,'stopped battlefield rejects fresh skill feedback')
	field.running=true;main.hunt_ai.encounter_id+=1
	ROUTER.emit(main,'selene',0,false,cast,true)
	check(main.presentation_runtime.audio.events.size()==count+1,'new encounter accepts its own cast identity')
	ROUTER.cutin(main,'selene','붉은 운명')
	check(field.skill_overlay.ultimates==[['selene','붉은 운명']],'confirmed ultimate cut-in reaches the active field presenter')
	var ally:=ROSTER.skill('elisia','passive');var ally_snapshot:=ally.duplicate(true)
	main.hero_skill_runtime.elisia.passive_procs=1
	ROUTER.passive(main,'elisia',0,ally,'mira')
	var observed: Dictionary=field.skill_overlay.events.back().profile
	check(observed.fx_slot=='passive' and observed.fx_cast_serial==1 and observed.fx_targets.is_empty() and observed.fx_allies==[{'hero_id':'mira','mode':'guard'}],'ally passive routes actual lowest ally, without invented enemy hit')
	check(ally==ally_snapshot,'passive observer never mutates its registered gameplay profile')
	var damage:=ROSTER.skill('mira','passive');main.hero_skill_runtime.mira.passive_procs=2
	ROUTER.passive(main,'mira',0,damage,'mira')
	observed=field.skill_overlay.events.back().profile
	check(observed.fx_targets==[0] and observed.fx_allies.is_empty(),'offensive passive retains its real enemy target')
	count=field.skill_overlay.events.size()
	ROUTER.passive(main,'astel',0,ROSTER.skill('astel','passive'),'mira')
	check(field.skill_overlay.events.size()==count,'zero proc count cannot invent a passive cast')
	# Exercise the real guarded passive hook, including failed condition and
	# internal cooldown. The sink only observes confirmed simulation callbacks.
	main.hero_skill_runtime.leonhardt.passive_procs=0
	KITS.event(main,'leonhardt','hit',0)
	check(main.passive_hooks==0 and main.earned_energy==0.0,'real failed passive condition has no visual callback or energy')
	main.hero_battle_state.leonhardt.guard=1.0
	KITS.event(main,'leonhardt','hit',0)
	observed=field.skill_overlay.events.back().profile
	check(main.passive_hooks==1 and main.earned_energy==4.0 and main.hero_skill_runtime.leonhardt.passive_procs==1,'real confirmed guarded proc emits once and keeps original energy effect')
	check(observed.fx_targets.is_empty() and observed.fx_allies==[{'hero_id':'leonhardt','mode':'energy'}],'energy passive paints only its actual hero')
	KITS.event(main,'leonhardt','hit',0)
	check(main.passive_hooks==1 and main.earned_energy==4.0,'real internal cooldown cannot retrigger presentation')
	main.hero_skill_runtime.leonhardt.passive_remaining=0.0
	KITS.event(main,'leonhardt','hit',0)
	check(main.passive_hooks==2 and main.hero_skill_runtime.leonhardt.passive_procs==2,'next confirmed proc receives the incremented serial')
	main.content_root=Control.new();main.add_child(main.content_root)
	var raid_view:=RaidViewSink.new();raid_view.name='PortraitRaidView';raid_view.battlefield_3d=field;main.content_root.add_child(raid_view)
	main.active_screen='raid';field.raid_mode=true;main.raid_positions.selene=Vector2(80,120)
	cast.fx_cast_serial=3;ROUTER.emit(main,'selene',-1,true,cast,true)
	check(main.presentation_runtime.audio.events.back().point==Vector2(10,15),'raid routes its real hero position through raid_to_world')
	ROUTER.cutin(main,'selene','레이드 궁극기')
	check(field.skill_overlay.ultimates.back()==['selene','레이드 궁극기'],'raid cut-in locates the embedded PortraitRaid battlefield')
	main.active_screen='combat';field.raid_mode=false
	main.combat_labels.clear()
	ROUTER.emit(main,'selene',0,false,cast,true)
	check(main.fallback_events==['ultimate'],'legacy or missing field preserves the original ultimate presentation event')
	main.queue_free();field.queue_free();await process_frame
	print('ultra_skill_router checks=%d failures=%s'%[checks,JSON.stringify(failures)])
	quit(0 if failures.is_empty() else 1)
