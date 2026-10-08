extends 'res://tests/support/V83UpgradeTestBase.gd'
## The filename is retained for historical suites. The latest user request
## enables real skill feedback; its opt-out must still remove every skill FX.
const KITS = preload('res://scripts/heroes/HeroKitRuntime.gd')
const SKILLS = preload('res://scripts/presentation/HeroSkillVfxPresenter.gd')
func _init() -> void:run.call_deferred()
func run() -> void:
	var main=await make_main('aurelia',3)
	root.content_scale_size=Vector2i(1280,720);root.size=Vector2i(1120,630)
	for raid in [false,true]:
		if raid:main._build_raid_screen();await settle();main._start_raid();await settle()
		else:main._build_combat_screen();await settle();main.combat_running=true
		if is_instance_valid(main.combat_timer):main.combat_timer.stop()
		main.combat_effects_enabled=true;main.combat_fx.enabled=true
		var field=main.content_root.get_node('PortraitRaidView').battlefield_3d if raid else main.combat_labels.terrain
		var skill=field.skill_overlay
		skill.set_process(false)
		var node_count: int=field.get_child_count()
		var panels: int=main.content_root.get_child_count()
		var visual_children: int=main.skill_fx_layer.get_child_count()
		var serial: int=int(main.hero_skill_runtime.leonhardt.get('casts_a1',0))+1
		main.hero_skill_runtime.leonhardt.remaining=0.0
		main.hero_battle_state.leonhardt.guard=0.0
		var accepted: int=skill.accepted_casts
		KITS.cast(main,'leonhardt','a1',-1 if raid else 0)
		check(float(main.hero_battle_state.leonhardt.guard)>0,'real cast settles guard before presentation')
		check(skill.accepted_casts==accepted+1,'one settled cast emits exactly one skill on '+('raid' if raid else 'hunt'))
		check(not skill.cast('leonhardt',0,false,{'fx_slot':'a1','fx_cast_serial':serial},false),'repeated settlement metadata cannot duplicate the cast')
		var state:=JSON.stringify([main.hero_battle_state,main.hero_skill_runtime,main.enemy_wave,main.raid_boss_hp,main.wallet_gold,main.wallet_gems])
		var rng_state: int=main.loot_rng.state
		for i in 100:
			main._emit_skill_cast_fx('mira',-1 if raid else 0,true,{'kind':'damage','slot':'a1','fx_targets':[-1 if raid else 0],'fx_cast_serial':i+1000},i%5==0)
			check(skill.casts.size()<=SKILLS.MAX_CASTS,'burst is bounded without per-particle nodes')
		check(field.get_child_count()==node_count and main.content_root.get_child_count()==panels and main.skill_fx_layer.get_child_count()==visual_children,'skill bursts allocate no canvas or particle nodes')
		check(JSON.stringify([main.hero_battle_state,main.hero_skill_runtime,main.enemy_wave,main.raid_boss_hp,main.wallet_gold,main.wallet_gems])==state and main.loot_rng.state==rng_state,'skill drawing does not change HP/status/gauge/economy or combat RNG')
		var ages:=[]
		for item in skill.casts:ages.append(float(item.age))
		main.combat_running=false;main.raid_running=false
		skill.advance(.3)
		for i in skill.casts.size():check(is_equal_approx(float(skill.casts[i].age),float(ages[i])),'pause freezes cast age')
		check(not skill.cast('mira',0,false,{'kind':'damage'},false),'paused battle cannot emit a new skill')
		main.combat_running=not raid;main.raid_running=raid
		skill.advance(2.0)
		check(skill.casts.is_empty(),'finished casts retire without holding the combat clock')
		main.combat_effects_enabled=false
		main._emit_skill_cast_fx('mira',0,true,{'kind':'damage'},true)
		skill.advance(.01)
		check(skill.casts.is_empty(),'effects opt-out clears skill feedback')
		main.presentation_runtime.contact_time.restore()
		check(Engine.time_scale==1.0,'effects opt-out restores the bounded ultimate slowdown')
		main.combat_effects_enabled=true
		if raid:
			main.boss_telegraph_pending=true;main.boss_telegraph_remaining=1.0;main.boss_telegraph_skill='테스트 위험 경고'
		main._emit_boss_telegraph('테스트 위험 경고',1.0)
		if raid:check(main.content_root.get_node('PortraitRaidView').telegraph.active,'raid danger remains readable alongside skills')
		main.combat_running=false;main.raid_running=false
	var observed: Dictionary={}
	for id in ROSTER.HEROES:observed[SKILLS.element_for(str(id),{})]=true
	check(observed.size()==4,'the deployed roster supports fire/ice/light/dark paint')
	var presenter=SKILLS.new()
	check(presenter.hero_statuses({'guard':0,'shield':12,'shield_seconds':0}).is_empty(),'expired protection does not show a fake buff')
	check(presenter.hero_statuses({'guard':.5,'shield':12,'shield_seconds':2})==['guard','shield'],'buff badges reflect active production protection')
	check(presenter.enemy_statuses({'stun_seconds':1,'weaken_seconds':0,'vulnerable_seconds':2})==['stun','vulnerable'],'debuff badges omit expired statuses')
	presenter.free()
	await dispose(main);done('BOUNDED_HERO_SKILL_VFX')
