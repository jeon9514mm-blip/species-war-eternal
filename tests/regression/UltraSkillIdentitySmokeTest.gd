extends 'res://tests/support/V83UpgradeTestBase.gd'
const VISUAL=preload('res://scripts/presentation/HeroSkillVfxCatalog.gd')
const FEEDBACK=preload('res://scripts/presentation/HeroSkillFeedbackCatalog.gd')
const KITS=preload('res://scripts/heroes/HeroKitRuntime.gd')
func _init() -> void:run.call_deferred()
func run() -> void:
	var signatures: Dictionary={};var glyphs: Dictionary={};var seeds: Dictionary={}
	for id in ROSTER.HEROES:
		for slot in VISUAL.SLOT_ORDER:
			var visual: Dictionary=VISUAL.profile(str(id),str(slot))
			check(visual.skill==ROSTER.skill(str(id),str(slot)).skill,'visual identity uses actual skill name')
			check(not signatures.has(visual.signature) and not seeds.has(visual.seed),'hero/slot effect identity is unique')
			signatures[visual.signature]=true;seeds[visual.seed]=true;glyphs[visual.glyph]=visual.motif
			check(visual.charge>0 and visual.flight>0 and visual.impact>0 and visual.tail==.40,'all four timed stages have a bounded lifetime')
	check(signatures.size()==120 and glyphs.size()==30,'thirty hero glyphs cover120 exact skills')
	var main=await make_main('aurelia',3)
	main._build_combat_screen();await settle();main.combat_running=true
	if is_instance_valid(main.combat_timer):main.combat_timer.stop()
	main.skill_auto=false;main.ultimate_auto=false;main.combat_effects_enabled=true
	main.presentation_runtime.contact_time.enabled=false
	var field=main.combat_labels.terrain;var skill=field.skill_overlay
	skill.set_process(false)
	var node_count: int=field.world.get_child_count()+skill.get_child_count()
	var state:=JSON.stringify([main.hero_battle_state,main.hero_skill_runtime,main.enemy_wave,main.wallet_gold,main.wallet_gems]);var rng: int=main.loot_rng.state
	for slot in VISUAL.SLOT_ORDER:
		check(skill.cast('leonhardt',0,false,{'fx_slot':slot,'fx_cast_serial':901+VISUAL.SLOT_ORDER.find(slot)},slot=='ultimate'),'real field can present each approved hero slot')
	check(skill.casts.size()==4,'passive and three active slots are independently admitted')
	check(skill._cards.size()==50 and skill.gpu_pool.bursts.size()==6,'card and GPU pools are warmed with fixed budgets')
	skill.advance(.12)
	check(skill._cards[int(skill.casts[0].card)].visible,'charge/flight glyph is visible')
	skill.advance(.40)
	check(skill.gpu_pool.accepted>0,'impact uses the native GPU particle pool')
	check(skill.show_ultimate('leonhardt','최후의 성채'),'ultimate shows original painting within field')
	check(not skill.show_ultimate('mira','일선 궤적'),'cut-in admission is throttled for simultaneous ultimates')
	check(skill._portrait.texture!=null and skill._cutin.mouse_filter==Control.MOUSE_FILTER_IGNORE,'cut-in preserves painting and cannot block controls')
	check(field.world.get_child_count()+skill.get_child_count()==node_count,'cast bursts allocate no nodes')
	check(JSON.stringify([main.hero_battle_state,main.hero_skill_runtime,main.enemy_wave,main.wallet_gold,main.wallet_gems])==state and main.loot_rng.state==rng,'visual timing leaves gameplay and RNG unchanged')
	skill.advance(2.0);check(skill.casts.is_empty(),'all stages retire and return cards')
	main.combat_effects_enabled=false;skill.advance(.01)
	check(not skill._cutin.visible and not skill.cast('mira',0,false,{'fx_slot':'a1'}),'opt-out removes glyphs and cut-ins')
	main.combat_running=false;await dispose(main);done('ULTRA_SKILL_IDENTITIES')
