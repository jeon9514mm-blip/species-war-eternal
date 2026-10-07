extends 'res://tests/support/V83UpgradeTestBase.gd'
const STYLE=preload('res://scripts/combat/CombatNumberStyle.gd')
const NUMBERS=preload('res://scripts/combat/DamageNumberManager.gd')
const PRESENTER=preload('res://scripts/presentation/CombatTextPresenter.gd')
const SCENERY=preload('res://scripts/art/RaidSceneryCatalog.gd')
func _init() -> void:run.call_deferred()
func run() -> void:
	check(STYLE.FONT is FontFile,'numeral face is bundled, not device dependent')
	check(STYLE.caption(1234567,'damage')=='1,234,567','large amounts stay exact')
	check(STYLE.caption(825,'incoming')=='-825' and STYLE.caption(420,'heal')=='+420','incoming and healing signs remain distinct')
	for pair in [['-100','damage'],['치명! -150','critical'],['-90 HP','incoming'],['+50','heal']]:
		check(STYLE.parse(pair[0]).kind==pair[1],'parse actual combat event '+pair[0])
	check(STYLE.parse('보물 포획!').is_empty() and STYLE.parse('-35x').is_empty(),'status text is not invented damage')
	var pool:=NUMBERS.new();root.add_child(pool)
	var bounds:=Rect2(0,0,1280,340)
	var number: Label=pool.spawn_damage('',Color.WHITE,Vector2(640,200),false,0,bounds,'damage','enemy-1',100)
	var combined: Label=pool.spawn_damage('',Color.WHITE,Vector2(640,200),false,1,bounds,'damage','enemy-1',80)
	check(number==combined and combined.text=='180' and combined.burst_hits==2,'rapid hits combine exact totals only for the same target')
	number.burst_started_at=Time.get_ticks_msec()-121
	var later: Label=pool.spawn_damage('',Color.WHITE,Vector2(640,200),false,2,bounds,'damage','enemy-1',70)
	check(later!=number and later.text=='70','new burst cannot chain forever')
	var critical: Label=pool.spawn_damage('',Color.WHITE,Vector2(640,200),true,3,bounds,'damage','enemy-1',210)
	check(critical!=number and critical.kind=='critical','critical cannot merge into ordinary damage')
	var opposite: Label=pool.spawn_damage('',Color.WHITE,Vector2(640,200),false,4,bounds,'heal','enemy-1',40)
	check(opposite!=number and opposite.text=='+40','healing cannot merge with damage')
	for i in 10:pool.spawn_damage('',Color.WHITE,Vector2(640,200),i%3==0,i+5,bounds,'damage','enemy-'+str(i+2),100+i)
	var occupied: Array[Rect2]=[]
	for label in pool.pool:
		if not label.visible:continue
		check(bounds.encloses(label.reserved_rect),'complete motion stays inside the field')
		for used in occupied:check(not used.intersects(label.reserved_rect),'dense damage lanes never overlap')
		occupied.append(label.reserved_rect)
	check(occupied.size()>=10,'dense hits still show several independent targets')
	number.retire();check(not number.visible and number.anchor_key.is_empty() and not number.is_in_group('floating_combat_text'),'retire clears reused target and group')
	var reused: Label=pool.spawn_damage('',Color.WHITE,Vector2(100,200),false,2,bounds,'incoming','hero-1',32)
	check(reused.modulate==Color.WHITE and reused.text=='-32','reuse clears faded opacity and text')
	pool.free()
	var main=await make_main('aurelia',3)
	main.combat_effects_enabled=true;main._build_combat_screen();await settle();main.combat_running=false
	var before:=economic(main);var rng: int=main.loot_rng.state
	var hp: Dictionary=main.hero_battle_state.duplicate(true);var wave: Array=main.enemy_wave.duplicate(true)
	for i in 20:main._spawn_floating_combat_text('치명! -1234',Color.WHITE,main.enemy_wave_sprites[0].position-Vector2(90,60))
	check(economic(main)==before and main.loot_rng.state==rng and main.hero_battle_state==hp and main.enemy_wave==wave,'number presentation never applies HP rewards or RNG')
	check(main._damage_pool.pool[0].get_theme_font('font')==STYLE.FONT,'actual hunt uses the combat face')
	main.combat_effects_enabled=false
	var count: int=main._damage_pool.pool.size()
	main._spawn_floating_combat_text('-40',Color.WHITE,Vector2.ZERO)
	check(main._damage_pool.pool.size()==count,'effects-off keeps the number pool idle')
	main.combat_effects_enabled=true
	var paths: Dictionary={}
	for zone: String in ['gray_meadow','forgotten_mine','moonrest_forest']:
		main.selected_raid_id=zone;main._build_raid_screen();await settle();await settle()
		var view=main.content_root.get_node('PortraitRaidView');var field=view.battlefield_3d
		var path: String=str(SCENERY.profile(zone).texture);paths[path]=true
		check(field.painted_backdrop.texture.resource_path==path,'correct painted raid asset '+zone)
		check(not bool(field.map_root.get_meta('map_design_removed',true)),'raid no longer has an empty backdrop '+zone)
		check(field.viewport_3d.transparent_bg and field.painted_backdrop.mouse_filter==Control.MOUSE_FILTER_IGNORE,'backdrop cannot cover actors or steal floor touches')
		before=economic(main);rng=main.loot_rng.state;hp=main.hero_battle_state.duplicate(true)
		var positions: Dictionary=main.raid_positions.duplicate()
		PRESENTER.raid(main,450,'critical');field._process(.1)
		check(economic(main)==before and main.loot_rng.state==rng and main.hero_battle_state==hp and main.raid_positions==positions,'raid art and projected numbers preserve state '+zone)
		var clock: float=field.atmosphere_clock
		field._process(.2);check(field.atmosphere_clock==clock,'ready raid atmosphere is still '+zone)
		main._start_raid();main.combat_timer.stop()
		var damage_before: int=main.raid_damage_dealt
		var stored_before: int=main.raid_boss_hp+main.raid_guard_hp+main.raid_add_hp
		var actual: int=main._apply_raid_damage(1000,main._deployed_hero_ids()[0])
		check(actual==main.raid_damage_dealt-damage_before and actual==stored_before-main.raid_boss_hp-main.raid_guard_hp-main.raid_add_hp,'display observer conserves boss guard/add damage '+zone)
		check(main._damage_pool!=null and main._damage_pool.pool.size()>0,'actual raid hits create projected damage numbers '+zone)
		main.presentation_options.performance='battery';clock=field.atmosphere_clock;field._process(.2)
		check(field.atmosphere_clock==clock,'battery profile stops atmospheric animation '+zone)
		main.presentation_options.performance='balanced';main.raid_running=false
	check(paths.size()==3,'all three raids have independently authored art')
	await dispose(main);done('COMBAT_READABILITY')
