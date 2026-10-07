extends SceneTree
## The player enters each raid from Content; casts and visible actors track the
## same simulated encounter rather than playing a canned battle animation.
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error('V59 raid: '+message)

func settle() -> void:
	for i in 6:await process_frame

func run() -> void:
	root.content_scale_size=Vector2i(720,1280);root.size=Vector2i(720,1280)
	var game:=preload('res://scenes/PortraitMain.tscn').instantiate()
	game.save_state_path='user://v59-raid-visual.json'
	root.add_child(game);await settle()
	game.combat_effects_enabled=false
	game.selected_faction='aurelia';game.idle_stage=40
	game.deployed_heroes=game._hero_roster_for_faction().slice(0,10)
	game.current_zone_id='gray_meadow';game.selected_raid_id=''
	game._build_meta_hub_screen();await settle()
	var content_button: Button=game.content_root.find_child('ContentTab_raids',true,false)
	check(content_button!=null,'Content shows a dedicated Raids tab')
	content_button.pressed.emit();await settle()
	var zones: Array[String]=['gray_meadow','forgotten_mine','moonrest_forest']
	var stage_art: Array[String]=[]
	for zone_id in zones:
		var enter: Button=game.content_root.find_child('RaidCatalogEnter_'+zone_id,true,false)
		check(enter!=null and not enter.disabled,zone_id+' has its own unlocked entrance')
		var scene: Control=game.content_root.find_child('RaidCatalogScene_'+zone_id,true,false)
		check(scene!=null and scene.get_child(0) is TextureRect and scene.get_child(0).texture!=null,zone_id+' has illustrated arena preview')
		enter.pressed.emit();await settle()
		check(game.active_screen=='raid' and game.selected_raid_id==zone_id and game.current_zone_id=='gray_meadow',zone_id+' starts independently of hunting region')
		var view: Control=game.content_root.get_node('PortraitRaidView')
		check(view.hero_actors.size()==10 and is_instance_valid(game.raid_boss_sprite),zone_id+' has live hero and boss actors')
		check(view.stage.get_node('PortraitRaidStageArt').texture!=null,zone_id+' paints a stage background')
		stage_art.append(view.stage.get_node('PortraitRaidStageArt').texture.resource_path)
		var design:=preload('res://scripts/raid/RaidBossDesign.gd')
		check(design.pattern(zone_id,1)['kind']!=design.pattern(zone_id,2)['kind'],zone_id+' changes attack shape at phase two')
		game._build_boss_select_screen();await settle()
	check(stage_art[0]!=stage_art[1] and stage_art[1]!=stage_art[2],'all three raids have separate arena art')
	game._select_zone_for_raid('moonrest_forest');await settle()
	game._start_raid()
	if is_instance_valid(game.combat_timer):game.combat_timer.stop()
	var view: Control=game.content_root.get_node('PortraitRaidView')
	for id in game.hero_skill_runtime:
		game.hero_skill_runtime[id]['attack_remaining']=99.0
	game.raid_boss_turns=3;game.raid_boss_attack_remaining=.01
	game._advance_raid_encounter(.05);view.refresh()
	check(game.boss_telegraph_pending and view.telegraph.active and view.cue.visible,'real cast activates a visible attack footprint and warning')
	var original_kind: String=view.telegraph.kind
	game.raid_boss_hp=int(game.raid_boss_max_hp*.58)
	game._advance_raid_encounter(.05);view.refresh()
	check(game.raid_phase==2 and view.telegraph.kind==original_kind,'cast retains its attack shape across a phase transition')
	game.boss_telegraph_remaining=.4;view.refresh()
	check(view.cast_bar.value>0 and view.cast_bar.visible,'cast gauge follows remaining real simulation time')
	var attack_id: String=str(game.deployed_heroes[0]['id'])
	view.play_hero_attack(attack_id)
	check(view.hero_actors[attack_id].state=='attack','hero actor plays a live attack motion')
	game.boss_telegraph_pending=false
	game.raid_boss_hp=1
	game._apply_raid_damage(1)
	game._advance_raid_encounter(.05);await settle()
	check(game.raid_outcome=='victory' and game.raid_clears.get('moonrest_forest',0)==1 and game.raid_clears.get('gray_meadow',0)==0,'reward settles for the chosen raid exactly once')
	check(game.content_root.find_child('PortraitRaidVictory',true,false)!=null,'boss kill plays a stage victory animation')
	game._finish_raid('victory')
	check(game.raid_clears['moonrest_forest']==1,'duplicate finish cannot grant another clear')
	game._select_zone_for_raid('gray_meadow');await settle()
	game._start_raid()
	if is_instance_valid(game.combat_timer):game.combat_timer.stop()
	for id in game.hero_skill_runtime:game.hero_skill_runtime[id]['attack_remaining']=99.0
	game.raid_boss_hp=int(game.raid_boss_max_hp*.55)
	game.raid_cast_profile=preload('res://scripts/raid/RaidBossDesign.gd').pattern('gray_meadow',2)
	game.boss_telegraph_pending=true;game.boss_telegraph_remaining=.01
	game.boss_telegraph_skill='갈라지는 대지';game.raid_boss_attack_remaining=.8
	game._advance_raid_encounter(.05)
	var first_hit_hp: int=game.party_hp
	check(game.raid_second_wave_remaining>0.0 and game.raid_pattern_count==1,'earthquake schedules a separate second shock')
	view=game.content_root.get_node('PortraitRaidView');view.refresh()
	check(view.cue.visible and view.cue.text=='2차 지진','second shock has its own arena warning')
	game._advance_raid_encounter(.20)
	check(game.party_hp==first_hit_hp,'second shock does not damage before its warning ends')
	game._advance_raid_encounter(.25)
	check(game.party_hp<first_hit_hp and game.raid_pattern_count==1,'second shock lands after its delay without counting a new cast')
	game.free()
	print('v59_three_raid_visual ',checks-failures.size(),'/',checks,' pass')
	quit(0 if failures.is_empty() else 1)
