extends RefCounted
## Routes confirmed simulation notifications; never decides or applies a skill.
const FEEDBACK=preload('res://scripts/presentation/HeroSkillFeedbackCatalog.gd')
const TOKEN_LIMIT:=64

static func _field(main) -> Control:
	var field: Control
	if main.active_screen=='combat':field=main.combat_labels.get('terrain')
	elif main.active_screen=='raid' and is_instance_valid(main.content_root):
		var view=main.content_root.get_node_or_null('PortraitRaidView')
		if is_instance_valid(view):field=view.get('battlefield_3d')
	return field

static func emit(main,hero_id: String,target_index: int,aoe: bool,profile: Dictionary,ultimate: bool = false) -> void:
	var slot:=str(profile.get('fx_slot',profile.get('slot','ultimate' if ultimate else 'a1')))
	if FEEDBACK.profile(hero_id,slot).is_empty():return
	var field:=_field(main)
	var overlay: Node=field.get('skill_overlay') if is_instance_valid(field) else null
	if is_instance_valid(overlay) and overlay.has_method('cast'):
		overlay.cast(hero_id,target_index,aoe,profile,ultimate)
		# Audio/haptics remain independent of the optional VFX toggle, while a
		# stopped battlefield never accepts a new skill feedback event.
		var serial:=int(profile.get('fx_cast_serial',0))
		var raid: bool=bool(field.get('raid_mode'))
		var encounter: int=int(main.raid_encounter_serial) if raid else int(main.hunt_ai.encounter_id)
		var token: String='%d:%s:%s:%d'%[encounter,hero_id,slot,serial]
		var running: bool=field.has_method('battle_clock_running') and bool(field.battle_clock_running())
		if running and (serial<=0 or not main._skill_audio_tokens.has(token)) and is_instance_valid(main.presentation_runtime):
			if main._skill_audio_tokens.size()>=TOKEN_LIMIT:main._skill_audio_tokens.clear()
			main._skill_audio_tokens[token]=true
			var point: Vector2=field.raid_to_world(main.raid_positions.get(hero_id,Vector2.ZERO)) if raid else main._hero_field_position(hero_id)
			if is_instance_valid(main.presentation_runtime.audio):
				main.presentation_runtime.audio.play_hero_skill(hero_id,slot,field,point,ultimate)
			main.presentation_runtime.haptics.pulse_hero_skill(hero_id,slot)
	elif ultimate:
		# Challenge/legacy battlefields retain their existing ultimate audio path.
		main._presentation_event('ultimate')

static func passive(main,hero_id: String,target_index: int,profile: Dictionary,lowest_id: String) -> void:
	# HeroKitRuntime calls this once only after a real proc increments its
	# counter. Unconfirmed conditions/cooldowns cannot invent visual procs.
	if not main.hero_skill_runtime.has(hero_id):return
	var serial:=int(main.hero_skill_runtime[hero_id].get('passive_procs',0))
	if serial<=0:return
	var visual:=profile.duplicate(true)
	visual['fx_slot']='passive';visual['slot']='passive';visual['fx_cast_serial']=serial
	visual['fx_targets']=[];visual['fx_target_hits']={};visual['fx_allies']=[]
	var action:=str(profile.get('action',''))
	if action=='damage':
		if target_index>=0 or main.active_screen=='raid':
			visual.fx_targets.append(target_index)
			visual.fx_target_hits[target_index]=1
	else:
		var recipient: String=lowest_id if action.begins_with('ally_') else hero_id
		if not recipient.is_empty() and main.hero_battle_state.has(recipient) and int(main.hero_battle_state[recipient].get('hp',0))>0:
			var mode:=action.trim_prefix('ally_')
			visual.fx_allies.append({'hero_id':recipient,'mode':mode})
	emit(main,hero_id,target_index,false,visual,false)

static func cutin(main,hero_id: String,detail: String) -> void:
	var field:=_field(main)
	var overlay: Node=field.get('skill_overlay') if is_instance_valid(field) else null
	if is_instance_valid(overlay) and overlay.has_method('show_ultimate'):
		overlay.show_ultimate(hero_id,detail)
