extends 'res://tests/support/V83UpgradeTestBase.gd'
## Actual portrait hunt/raid canvases must never recreate removed hero graphics.
func _init() -> void:run.call_deferred()
func run() -> void:
	var main=await make_main('aurelia',3)
	main.combat_effects_enabled=true;main.combat_fx.enabled=true
	for raid in [false,true]:
		if raid:main._build_raid_screen();await settle();main._start_raid();await settle()
		else:main._build_combat_screen();await settle();main.combat_running=true
		main.combat_effects_enabled=true;main.combat_fx.enabled=true
		if is_instance_valid(main.combat_timer):main.combat_timer.stop()
		var children: int=main.skill_fx_layer.get_child_count()
		var panels: int=main.content_root.get_child_count()
		var state:=JSON.stringify([main.hero_battle_state,main.hero_skill_runtime,main.enemy_wave,main.raid_boss_hp])
		var projectiles: int=main.combat_fx.projectile_sequence
		var indicators: int=main.combat_fx.aoe_sequence
		for id in ROSTER.HEROES:
			for slot in ['a1','a2','passive','ultimate']:
				var profile: Dictionary=ROSTER.skill(id,slot).duplicate(true)
				profile.fx_targets=[-1 if raid else 0];profile.fx_allies=[{'hero_id':'mira','mode':'shield'}]
				if slot=='passive':main._emit_passive_proc_fx(id,-1 if raid else 0,profile,'mira')
				else:main._emit_skill_cast_fx(id,-1 if raid else 0,true,profile,slot=='ultimate')
				if slot=='ultimate':main._emit_ultimate_cutin(id,str(profile.skill))
				check(main.skill_fx_layer.get_child_count()==children and main.content_root.get_child_count()==panels,id+'/'+slot+' emits no graphics on '+('raid' if raid else 'hunt'))
		main._emit_skill_cast_fx('mira',0,true,{'kind':'damage'})
		main._emit_v11_skill_signature(Vector2(640,360),{'kind':'heal'},Color.GREEN)
		check(main.combat_fx.projectile_sequence==projectiles and main.combat_fx.aoe_sequence==indicators,'legacy entry points emit no skill projectile or area')
		check(main.skill_fx_layer.get_child_count()==children and main.content_root.get_child_count()==panels,'legacy entry points emit no overlay')
		check(JSON.stringify([main.hero_battle_state,main.hero_skill_runtime,main.enemy_wave,main.raid_boss_hp])==state,'removed presentation does not touch battle state')
		check(main.combat_effects_enabled and main.combat_fx.enabled,'general combat cosmetics remain independently enabled')
		if raid:
			main.boss_telegraph_pending=true;main.boss_telegraph_remaining=1.0;main.boss_telegraph_skill='테스트 위험 경고'
		main._emit_boss_telegraph('테스트 위험 경고',1.0)
		if raid:check(main.content_root.get_node('PortraitRaidView').telegraph.active,'raid danger area remains active')
		else:check(main.content_root.get_node_or_null('BossTelegraphWarning')!=null,'hunt danger warning remains visible')
		main.combat_running=false;main.raid_running=false
	await dispose(main);done('NO_HERO_SKILL_VFX')
