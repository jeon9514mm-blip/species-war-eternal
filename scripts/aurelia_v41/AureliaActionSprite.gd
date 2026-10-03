extends "res://scripts/HeroSpriteController.gd"
## Presentation-only. Read state; never write HP, world position, damage, RNG, cooldowns,
## force IDs, roster, skills, currency or save files. 16 presentation tracks; skeletal rendering supplies joint movement.
const CATALOG = preload("res://scripts/aurelia_v41/AureliaMotionCatalog.gd")
const ACTIONS: Array[String] = ["idle","walk","run","attack_1","attack_2","skill","ultimate","hit","knockback","dodge","guard","buff","debuff","victory","death","spawn"]
const LOOPS: Array[String] = ["idle","walk","run","debuff"]
const PIVOT := Vector2(72,122)
const BODY_HEIGHT: float = 64.0
var visual_action: String = "idle"
var observe_game: bool = true
var hold_demo: bool = false
var playback_log: Array[String] = []
var _main_ref: WeakRef
var _strike: int = 0
var _locked: bool = false
var _last_hp: int = -1
var _last_guard: float = 0.0
var _last_shield: int = 0
var _last_hits: int = 0
var _last_kills: int = -1
var _last_stun: float = 0.0
signal visual_action_finished(action_name: String)

func configure_actions(hero_id: String) -> void:
	assert(CATALOG.has_hero(hero_id),"Unapproved identity: "+hero_id)
	atlas_key=hero_id
	sheet_layout="aurelia_v41_skinned_illustration"
	texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	material=null
	_build_sprite_frames()
	play_visual("idle")

func _build_sprite_frames() -> void:
	var resource: SpriteFrames=CATALOG.frames_for(atlas_key)
	if resource==null:
		_frames_ready=false
		return
	# Duplicate metadata (not images) so adding legacy aliases never mutates shared source data.
	var frames: SpriteFrames=resource.duplicate(false) as SpriteFrames
	for facing: String in DIRECTIONS:
		for legacy: String in STATES:
			var source: String="attack_1" if legacy=="attack" else legacy
			var alias: String=legacy+"_"+facing
			if frames.has_animation(alias):continue
			frames.add_animation(alias)
			frames.set_animation_speed(alias,frames.get_animation_speed(source))
			frames.set_animation_loop(alias,frames.get_animation_loop(source))
			for i: int in frames.get_frame_count(source):
				frames.add_frame(alias,frames.get_frame_texture(source,i),frames.get_frame_duration(source,i))
	preload("res://scripts/portrait/HeroRigMotionCatalog.gd").add_spawn_track(frames)
	sprite_frames=frames
	native_visual_height=BODY_HEIGHT
	centered=false
	offset=-PIVOT
	_frames_ready=true

func _ready() -> void:
	super._ready()
	_find_game()

func _find_game() -> Node:
	if _main_ref!=null:
		var found: Node=_main_ref.get_ref() as Node
		if is_instance_valid(found):return found
	var parent: Node=get_parent()
	while parent!=null:
		if parent.has_method("_deployed_hero_ids"):
			_main_ref=weakref(parent)
			return parent
		parent=parent.get_parent()
	return null

func _legacy_state(action: String) -> String:
	if action in ["walk","run"]:return "walk"
	if action=="death":return "death"
	if action in ["hit","knockback"]:return "hit"
	if action in ["attack_1","attack_2","skill","ultimate"]:return "attack"
	return "idle"

func play_visual(action: String,restart: bool=true) -> bool:
	if not _frames_ready or action not in ACTIONS:return false
	if not sprite_frames.has_animation(action):return false
	if action==visual_action and is_playing() and not restart:return true
	visual_sequence+=1
	visual_action=action
	state=_legacy_state(action)
	_locked=action not in LOOPS and action!="death"
	_death_time=0.0
	_hit_flash_time=0.16 if action in ["hit","knockback"] else 0.0
	modulate.a=1.0
	offset=-PIVOT
	rotation=0.0
	flip_h=direction=="left"
	stop()
	play(action)
	playback_log.append(action)
	if playback_log.size()>64:playback_log.pop_front()
	return true

func _intent_action() -> String:
	var game: Node=_find_game()
	if observe_game and game!=null:
		var runtimes: Dictionary=game.get("hero_skill_runtime")
		var runtime: Dictionary=runtimes.get(atlas_key,{})
		if bool(runtime.get("cast_ultimate",false)):return "ultimate"
		if bool(runtime.get("cast_secondary",false)) or bool(runtime.get("cast",false)):return "skill"
	_strike+=1
	return "attack_1" if _strike%2==1 else "attack_2"

func play_state(next_state: String,next_direction: String="") -> void:
	if next_direction in DIRECTIONS:direction=next_direction
	flip_h=direction=="left"
	if not _frames_ready:return
	if next_state=="death":
		if visual_action!="death":play_visual("death")
		return
	if visual_action=="death":
		# Only an already revived gameplay unit may return to an idle/walk presentation.
		var game: Node=_find_game()
		if game!=null and observe_game:
			var records: Dictionary=game.get("hero_battle_state")
			if int(records.get(atlas_key,{}).get("hp",0))<=0:return
		if next_state in ["idle","walk"]:play_visual(next_state)
		return
	if next_state=="attack":play_visual(_intent_action());return
	if next_state=="hit":play_visual("hit");return
	if _locked and next_state in ["idle","walk"]:return
	play_visual(next_state if next_state in ACTIONS else "idle",false)

func play_attack(next_direction: String="") -> void:
	if next_direction in DIRECTIONS:direction=next_direction
	if visual_action!="death":play_visual(_intent_action())

func play_walk(velocity: Vector2=Vector2.ZERO) -> void:
	if velocity.length_squared()>.0001:
		if absf(velocity.x)>absf(velocity.y):direction="right" if velocity.x>0 else "left"
		else:direction="down" if velocity.y>0 else "up"
	flip_h=direction=="left"
	if _locked or visual_action=="death":return
	play_visual("run" if velocity.length()>=1.25 else "walk",false)

func _on_animation_finished() -> void:
	var finished: String=visual_action
	_locked=false
	visual_action_finished.emit(finished)
	var legacy: String=_legacy_state(finished)
	if legacy in ["attack","hit"]:action_finished.emit(legacy)
	if finished=="death" or hold_demo:return
	play_visual("idle")

func _observe_main_state() -> void:
	if not observe_game or hold_demo:return
	var game: Node=_find_game()
	if game==null or str(game.get("active_screen"))!="combat":return
	var actors: Array=game.get("hero_map_sprites")
	if not actors.has(self):return
	var records: Dictionary=game.get("hero_battle_state")
	var record: Dictionary=records.get(atlas_key,{})
	if record.is_empty():return
	var hp: int=int(record.get("hp",0))
	var hp_max: int=maxi(1,int(record.get("max_hp",1)))
	var guard: float=float(record.get("guard",0.0))
	var shield: int=int(record.get("shield",0))
	var hits: int=int(record.get("incoming_hits",0))
	var kills: int=int(game.get("combat_kills"))
	var stun: float=maxf(float(record.get("stun_seconds",0.0)),float(record.get("stun",0.0)))
	var chosen: String=""
	if hp<=0:
		if visual_action!="death":chosen="death"
	elif _last_hp>=0 and hp<_last_hp:
		chosen="knockback" if _last_hp-hp>=int(hp_max*.12) else "hit"
	elif stun>0 and _last_stun<=0:chosen="debuff"
	elif hits>_last_hits and str(record.get("role_group",""))!="탱커":
		var cadence: int=19 if str(record.get("role_group",""))=="딜러" else 27
		if (hits+int(record.get("slot",0))*7)%cadence==0:chosen="dodge"
	elif not _locked:
		if _last_kills>=0 and kills>_last_kills:chosen="victory"
		elif guard>0 and _last_guard<=0:chosen="guard"
		elif shield>_last_shield:chosen="buff"
		elif visual_action=="debuff" and stun<=0:chosen="idle"
	if not chosen.is_empty():play_visual(chosen,visual_action!=chosen)
	_last_hp=hp;_last_guard=guard;_last_shield=shield
	_last_hits=hits;_last_kills=kills;_last_stun=stun

func _process(delta: float) -> void:
	if speed_scale<=0:return
	super._process(delta)
	_observe_main_state()
	# All limb/hair/cloak motion is baked in the frames. Never modify entity position.
	offset=-PIVOT
