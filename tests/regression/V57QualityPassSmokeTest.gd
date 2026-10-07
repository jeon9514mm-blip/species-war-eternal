extends SceneTree
## Verify displayed combat values, real slot taps, settings and save notices.
var main: Node
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	run.call_deferred()

func verify(condition: bool, caption: String) -> void:
	checks += 1
	if not condition:
		failures.append(caption)
		push_error('V57 quality pass: '+caption)

func settle() -> void:
	for frame in 8: await process_frame

func tap(button: Button) -> void:
	verify(button!=null,'target button exists')
	if button==null:return
	var event:=InputEventMouseButton.new()
	event.button_index=MOUSE_BUTTON_LEFT
	event.position=button.get_global_rect().get_center()
	event.pressed=true;root.push_input(event,true)
	event.pressed=false;root.push_input(event,true)
	await settle()

func element(named: String) -> Node:
	return main.content_root.find_child(named,true,false)

func run() -> void:
	root.content_scale_size=Vector2i(720,1280);root.size=Vector2i(720,1280)
	main=preload('res://scenes/PortraitMain.tscn').instantiate()
	main.save_state_path='user://v57-quality-pass.json'
	root.add_child(main);await settle()
	main.set_physics_process(false);main.set_process(false)
	main._offline_checked=true;main.combat_effects_enabled=false
	await formation_and_stats()
	await settings_and_guide()
	await focused_growth_and_dungeon()
	await start_notice()
	main._clear_screen();main.free();await settle()
	# v82: audio playback teardown is asynchronous even with the Dummy driver.
	await create_timer(0.3).timeout
	print('V57 QUALITY PASS ',checks-failures.size(),'/',checks,' PASS')
	quit(0 if failures.is_empty() else 1)

func formation_and_stats() -> void:
	for faction: String in ['aurelia','noxfera']:
		main.selected_faction=faction;main.idle_stage=35;main.party_slot_legacy_cap=10
		var roster: Array=main._hero_roster_for_faction()
		main.deployed_heroes=roster.slice(0,10).duplicate(true)
		main._setup_hero_progress(roster)
		for hero: Dictionary in roster:main.hero_progress[str(hero['id'])]={'level':24,'xp':0}
		main._build_hero_select_screen();await settle()
		var before_first: String=str(main.deployed_heroes[0]['id'])
		var before_last: String=str(main.deployed_heroes[7]['id'])
		await tap(element('RosterSlotSwap_0'))
		verify(int(main.get_meta('roster_swap_slot',-1))==0,'first slot selected for exchange')
		await tap(element('RosterSlotSwap_7'))
		verify(str(main.deployed_heroes[0]['id'])==before_last and str(main.deployed_heroes[7]['id'])==before_first,'real taps exchange front and rear heroes')
		verify('전열' in element('RosterSlotRow_0').text and '후열' in element('RosterSlotRow_7').text,'visible slots identify actual combat rows')
		var stored: Dictionary=main.save_store.read_save(main.save_state_path)
		verify(bool(stored.get('ok',false)) and stored['data']['deployed_hero_ids'][0]==before_last,'swapped order persists to save')
		main._setup_hero_battle_state()
		verify(str(main.hero_battle_state[before_last]['row'])=='front' and str(main.hero_battle_state[before_first]['row'])=='rear','battle uses exchanged rows')
		var id: String=before_first
		var state: Dictionary=main.hero_battle_state[id].duplicate(true)
		main._build_hero_detail_screen(id);await settle()
		var summary: Label=element('HeroCombatStats')
		var expected_hp: String='HP '+main._compact_hud_amount(int(state['max_hp']))
		var expected_attack: String='공격 '+main._compact_hud_amount(int(state['attack']))
		var expected_defense: String='방어 '+main._compact_hud_amount(int(state['defense']))
		verify(summary!=null and summary.text.contains(expected_hp) and summary.text.contains(expected_attack) and summary.text.contains(expected_defense),'hero detail agrees with battle stats '+faction)
		main.hero_progress[id]['level']=40
		main._setup_hero_battle_state()
		var expected_hp_after: String='HP '+main._compact_hud_amount(int(main.hero_battle_state[id]['max_hp']))
		main._build_hero_detail_screen(id);await settle()
		verify(element('HeroCombatStats').text.contains(expected_hp_after),'updated level refreshes real hero stat '+faction)
		main._build_hero_select_screen();await settle()
		verify(int(main.get_meta('roster_swap_slot',-1))==-1,'swap selection clears after exchange')

func settings_and_guide() -> void:
	main.selected_faction='aurelia';main.tutorial_completed=false
	main._build_lobby_screen();await settle()
	verify(element('LobbyGuideCard')!=null and element('LobbyGuideAction')!=null,'first-run lobby shows actionable guide')
	main._show_main_menu();await settle()
	var effects: CheckButton=element('PortraitEffectSetting')
	var sounds: CheckButton=element('PortraitSoundSetting')
	verify(effects!=null and sounds!=null and element('PortraitOpenGuide')!=null,'portrait menu exposes settings and guide')
	verify(effects.button_pressed==false and sounds.button_pressed==main.sound_effects_enabled,'settings show independent states')
	await tap(sounds)
	verify(not main.sound_effects_enabled and not main.combat_effects_enabled,'sound can be muted independently of visuals')
	await tap(effects)
	verify(main.combat_effects_enabled and not main.sound_effects_enabled,'visuals remain independently enabled')
	main.sound_effects_enabled=true;main.combat_effects_enabled=false
	main._load_ui_preferences()
	verify(main.combat_effects_enabled and not main.sound_effects_enabled,'separate sound and visual preferences survive reload')
	await tap(element('PortraitOpenGuide'))
	verify(element('MenuOverlay')!=null and element('PortraitActionSheet')==null,'guide opens without leaving stacked menus')
	main._build_lobby_screen();await settle()
	main.combat_effects_enabled=false
	main._build_combat_screen();await settle()
	main._emit_boss_telegraph('위험 공격',1.0);await settle()
	verify(element('BossTelegraphWarning')!=null,'important boss warning survives cosmetic effects off')

func focused_growth_and_dungeon() -> void:
	main._build_growth_screen();await settle()
	var selector: OptionButton=element('GrowthHeroChoice')
	verify(selector!=null and element('GrowthSelectedHero')!=null and element('GrowthBranch_offense')!=null,'training shows one selected hero and actionable branches')
	var next_id: String=str(selector.get_item_metadata(1))
	selector.select(1);selector.item_selected.emit(1);await settle()
	verify(str(main.get_meta('growth_hero_id'))==next_id and element('GrowthSelectedHero')!=null,'training selection changes focused hero')
	main._build_summon_screen();await settle()
	var summon: OptionButton=element('SummonHeroChoice')
	verify(summon!=null and element('SummonSelectedHero')!=null and element('SummonBreakthrough')!=null,'summoning shows one breakthrough target')
	var summon_next_id: String=str(summon.get_item_metadata(2))
	summon.select(2);summon.item_selected.emit(2);await settle()
	verify(str(main.get_meta('summon_hero_id'))==summon_next_id,'summon choice persists across rebuild')
	main.set_meta('content_meta_tab','daily')
	main.daily_dungeon_runs=0
	main._build_meta_hub_screen();await settle()
	var power: int=main._calculate_party_power()
	if power>=650:
		var old_gold: int=main.wallet_gold
		await tap(element('DungeonEnterButton'))
		verify(main.active_screen=='combat' and main.wallet_gold==old_gold,'daily entry opens combat without an instant payout')
		var daily_ticks: int=0
		while main.challenge_session!=null and daily_ticks<2000:
			main._advance_auto_hunt(1.0/30.0)
			daily_ticks+=1
		await settle()
		verify(main.wallet_gold>old_gold and element('DungeonLastResult')!=null,'dungeon combat victory produces visible result receipt')

func start_notice() -> void:
	main._save_blocked_for_newer_version=true
	main.save_load_status='unsupported_version'
	main._build_title_screen();await settle()
	verify(element('PortraitStartButton').disabled and '업데이트' in element('PortraitSaveNotice').text,'blocked newer save explains how to continue')
	main._save_blocked_for_newer_version=false
