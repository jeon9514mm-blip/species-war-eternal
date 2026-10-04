extends SceneTree
## Player-visible raid controls and retry state, plus every incoming dodge path.
const BALANCE=preload('res://scripts/RaidBalance.gd')
const FIELD=preload('res://scripts/RaidBattlefield.gd')
var checks:=0
var failures: Array[String]=[]

func _init() -> void:run.call_deferred()

func check(ok: bool,note: String) -> void:
	checks+=1
	if not ok:failures.append(note);push_error(note)

func settle() -> void:
	for i in 8:await process_frame

func tap(control: Control) -> void:
	for pressed in [true,false]:
		var event:=InputEventScreenTouch.new()
		event.position=root.get_final_transform()*control.get_global_rect().get_center()
		event.pressed=pressed;Input.parse_input_event(event)
	await settle()

func restart(game) -> void:
	if game.raid_running:game._finish_raid('defeat')
	game._start_raid();game.combat_timer.stop()

func run() -> void:
	root.content_scale_size=Vector2i(1280,720);root.size=Vector2i(1280,720)
	Input.set_use_accumulated_input(false);Input.emulate_mouse_from_touch=true
	var game=load('res://scenes/PortraitMain.tscn').instantiate()
	game.save_state_path='user://raid-combat-quality-'+str(Time.get_ticks_usec())+'.json'
	root.add_child(game);await settle()
	game.set_process(false);game.set_physics_process(false)
	game._offline_checked=true;game.sound_effects_enabled=false;game.combat_effects_enabled=false
	game.selected_faction='aurelia';game.party_slot_legacy_cap=10;game.idle_stage=100
	game._restore_deployed_heroes(['leonhardt','mira','elisia','kairen','orwin','seria','astel','darius','lunea','caelum'])
	game.selected_raid_id='gray_meadow';game._build_raid_screen();await settle()
	var view=game.content_root.get_node('PortraitRaidView')
	check(view.stage.size.x>view.stage.size.y and view.stage.size.y>=280,'landscape battlefield retains its playable height')
	check(view.information.text.contains(game._compact_hud_amount(BALANCE.stats(game._raid_zone()).max_hp)),'preparation previews actual scaled boss HP')
	check(view.party_summary.text.contains(game._compact_hud_amount(BALANCE.stats(game._raid_zone()).recommended_power)),'preparation previews actual scaled recommendation')
	restart(game)
	var first: String=str(game.deployed_heroes[0].id)
	var selected: String='mira'
	view.selected_hero_id=selected
	game.raid_positions[selected]=game.raid_boss_position-Vector2(160,0)
	game.hero_skill_runtime[selected].remaining=4.0;game.hero_skill_runtime[selected].secondary_remaining=2.0
	game.hero_battle_state[selected].ultimate=37.0;view.refresh()
	check(view.skill_cast_button.disabled and view.skill_cast_button.text.contains('2.0'),'manual skill shows the first available cooldown')
	check(view.ultimate_cast_button.disabled and view.ultimate_cast_button.text.contains('37%'),'manual ultimate shows actual charge')
	game.hero_skill_runtime[selected].remaining=0.0;game.hero_skill_runtime[selected].secondary_remaining=0.0
	game.hero_battle_state[selected].ultimate=100.0;view.refresh()
	check(not view.skill_cast_button.disabled and not view.ultimate_cast_button.disabled,'ready selected hero enables manual actions')
	await tap(view.skill_cast_button);view.refresh()
	check(float(game.hero_skill_runtime[selected].remaining)>0.0 or float(game.hero_skill_runtime[selected].secondary_remaining)>0.0,'enabled manual skill actually casts for selected hero')
	await tap(view.ultimate_cast_button);view.refresh()
	check(float(game.hero_battle_state[selected].ultimate)<100.0 and view.ultimate_cast_button.disabled,'manual ultimate consumes charge and immediately updates availability')
	game.raid_positions[selected]=Vector2(226,290);game.raid_boss_position=Vector2(812,476);view.refresh()
	check(view.skill_cast_button.disabled and view.ultimate_cast_button.disabled and view.skill_cast_button.text=='사거리 밖','out of range explains why both actions are unavailable')
	game.hero_battle_state[selected].hp=0;view.refresh()
	check(view.skill_cast_button.disabled and view.ultimate_cast_button.disabled and view.skill_cast_button.text=='전투불능','dead selected hero cannot offer unusable casts')
	view.hero_actors[selected]._process(1.0)
	check(view.hero_actors[selected].state=='death' and view.hero_actors[selected].modulate.a<.2,'retry fixture starts from a visibly dead actor')
	view.rally_marker.visible=true
	restart(game)
	check(view.hero_actors[selected].state=='idle' and is_equal_approx(view.hero_actors[selected].modulate.a,1.0),'retry revives actor before another attack')
	check(view.hero_actors[selected].position==game.raid_positions[selected] and not view.rally_marker.visible,'retry resets visual entry position and stale move marker')
	check(float(view.last_hp[selected])==float(game.hero_battle_state[selected].hp),'retry resets damage-flash baseline to restored HP')
	view.show_victory();game.raid_boss_sprite._process(1.0)
	check(game.raid_boss_sprite.state=='death','victory fixture starts from defeated boss')
	restart(game)
	check(game.raid_boss_sprite.state=='idle' and is_equal_approx(game.raid_boss_sprite.modulate.a,1.0),'retry restores defeated boss visibility')
	game.raid_elapsed=210;view.refresh()
	check(view.information.text.contains('남은 30초'),'live timer explicitly shows remaining fight time')
	game.raid_elapsed=0
	game.raid_cast_profile={'kind':'cone','counter':'부채꼴 바깥 측면으로 이동','telegraph':1.0}
	game.raid_pattern_shape=FIELD.footprint('cone',game.raid_boss_position,[game.raid_positions[first]],game.raid_cast_profile)
	game.boss_telegraph_pending=true;game.boss_telegraph_remaining=.7;game.boss_telegraph_skill='테스트 파쇄'
	view.refresh();await settle()
	check(view.telegraph.active and view.telegraph.shape==game.raid_pattern_shape,'warning uses the actual incoming damage footprint')
	check(view.state_label.text.contains('부채꼴 바깥 측면으로 이동'),'warning explains this cast counter instead of generic advice')
	check(view.battle_hint.text.contains('부채꼴 바깥 측면으로 이동'),'live warning counter is readable with the details sheet closed')
	view._open_options();await settle()
	var details_scroll: ScrollContainer=view.options_sheet.get_node('RaidOptionsPanel/Margin/Scroll')
	details_scroll.ensure_control_visible(view.state_scroll);await settle()
	check(details_scroll.get_global_rect().encloses(view.state_scroll.get_global_rect()),'full warning instructions are reachable in the guide sheet')
	var details_position: int=details_scroll.scroll_vertical
	view.refresh();await settle()
	check(details_scroll.scroll_vertical==details_position,'routine warning refresh preserves the player guide scroll position')
	view.options_sheet.hide()

	# Keep one non-dodging tank in melee; verify an actual basic attack resolves.
	restart(game)
	game.skill_auto=false;game.ultimate_auto=false
	for id in game._alive_hero_ids():
		game.hero_skill_runtime[id].attack_remaining=1000.0
		if id!=first:game.hero_battle_state[id].hp=0
	game.hero_battle_state[first].hp=10000;game.hero_battle_state[first].max_hp=10000
	game.hero_battle_state[first].shield=0;game.hero_battle_state[first].guard=0.0
	game.hero_battle_state[first].defense=0;game.hero_battle_state[first].role_group='탱커'
	game.raid_positions[first]=game.raid_boss_position-Vector2(60,0)
	game.raid_boss_attack_remaining=0.0
	game._raid_dodge()
	var before: int=int(game.hero_battle_state[first].hp)
	game._advance_raid_encounter(.05)
	check(game.raid_boss_turns==1 and int(game.hero_battle_state[first].hp)==before,'emergency dodge blocks a real boss basic attack')
	check(game.raid_dodge_remaining>0.0,'basic attack is tested during live immunity')
	game.raid_dodge_remaining=0.0;game.raid_boss_attack_remaining=0.0
	game._advance_raid_encounter(.05)
	check(int(game.hero_battle_state[first].hp)<before,'the same basic attack hurts after immunity expires')

	game.raid_encounter_zone='forgotten_mine';game.raid_add_hp=10000;game.raid_add_count=2
	game.raid_add_attack_remaining=0.0;game.raid_dodge_cooldown=0.0;game._raid_dodge()
	before=int(game.hero_battle_state[first].hp)
	game._raid_advance_mechanics(.05)
	check(game.raid_add_attack_remaining>0.0 and int(game.hero_battle_state[first].hp)==before,'emergency dodge blocks a real crystal pulse')
	game.raid_dodge_remaining=0.0;game.raid_add_attack_remaining=0.0;game._raid_advance_mechanics(.05)
	check(int(game.hero_battle_state[first].hp)<before,'crystal pulse still damages after immunity expires')

	game.raid_pattern_shape=FIELD.footprint('aoe',game.raid_positions[first],[],{'radius':90.0})
	game.raid_dodge_remaining=.5;before=int(game.hero_battle_state[first].hp)
	game._apply_boss_pattern({'kind':'aoe','multiplier':1.0})
	check(int(game.hero_battle_state[first].hp)==before,'emergency dodge still blocks telegraphed attacks')
	game.raid_second_wave_shape=game.raid_pattern_shape.duplicate(true)
	game.raid_second_wave_profile={'multiplier':1.0};game._apply_raid_second_wave()
	check(int(game.hero_battle_state[first].hp)==before,'emergency dodge still blocks second-wave attacks')
	game.active_screen='combat'
	var field_damage: int=game._incoming_damage_to_hero(first,100)
	check(field_damage>0,'raid dodge does not leak into ordinary combat')
	game.active_screen='raid';game._finish_raid('defeat')
	view.refresh();await settle()
	check(view.start.text=='다시 도전' and not view.start.disabled,'defeat immediately presents a usable retry outside the guide')
	view._open_options();await settle()
	details_scroll.ensure_control_visible(view.state_scroll);await settle()
	check(view.state_title.text=='전투 결과' and details_scroll.get_global_rect().encloses(view.state_scroll.get_global_rect()),'defeat report remains reachable in the guide sheet')
	details_scroll.ensure_control_visible(view.recovery_action);await settle()
	check(view.recovery_action.visible and details_scroll.get_global_rect().encloses(view.recovery_action.get_global_rect()),'post-defeat recovery action remains reachable')

	# Switching bosses must never present the previous battle's depleted gauge.
	game.raid_boss_hp=123;game.raid_boss_max_hp=3600
	game.selected_raid_id='moonrest_forest';game._build_raid_screen();await settle()
	view=game.content_root.get_node('PortraitRaidView');view.refresh()
	check(is_equal_approx(view.hp.value,100.0),'new boss preparation gauge is full after prior defeat')
	check(view.information.text.contains(game._compact_hud_amount(BALANCE.stats(game._raid_zone()).max_hp)),'new boss preparation health is from current encounter balance')
	game.presentation_runtime.audio.shutdown();await create_timer(.5).timeout
	game.free();await create_timer(.35).timeout
	print('raid_combat_quality checks=%d failures=%s'%[checks,JSON.stringify(failures)])
	quit(0 if failures.is_empty() else 1)
