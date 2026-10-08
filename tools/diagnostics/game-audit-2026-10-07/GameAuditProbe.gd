extends SceneTree
## Read-only observations of production screens and natural combat.
const ROSTER=preload('res://scripts/heroes/HeroRosterCatalog.gd')
var game: Node
var output: String
var observations: Dictionary={'screens':[],'hunt_samples':[],'raid_samples':[]}
func _init() -> void:run.call_deferred()
func settle() -> void:
	for i in 6:await process_frame
func walk(node: Node) -> Array[Node]:
	var result: Array[Node]=[node]
	for child in node.get_children():result.append_array(walk(child))
	return result
func inspect(label: String) -> void:
	var held: Array=[]
	if label.begins_with('damage-') or label.begins_with('loot-'):
		for number in get_nodes_in_group('floating_combat_text'):
			if number._life_tween!=null and number._life_tween.is_running():held.append(number._life_tween);number._life_tween.pause()
	# Action captures need the fresh contact, not six frames of UI settling.
	if label.begins_with('damage-') or label.begins_with('loot-'):
		await process_frame;await process_frame
	else:await settle()
	await RenderingServer.frame_post_draw
	var info: Dictionary={'screen':label,'viewport':str(game.get_viewport_rect().size),'nodes':walk(game.content_root).size(),'buttons':[],'overlap_candidates':[]}
	var buttons: Array[BaseButton]=[]
	info.floating_texts=[]
	for floating_label in get_nodes_in_group('floating_combat_text')+get_nodes_in_group('loot_reward_popup'):
		info.floating_texts.append({'text':floating_label.text,'visible':floating_label.is_visible_in_tree(),'alpha':floating_label.modulate.a,'rect':str(floating_label.get_global_rect()),'path':str(floating_label.get_path())})
	var field=game.combat_labels.get('terrain')
	if is_instance_valid(field) and field.has_method('actor_world_height'):
		info.loot_beams=field.hunt_overlay.loot_beams.duplicate(true)
	for node in walk(game.content_root):
		if node is BaseButton and node.is_visible_in_tree() and not node.disabled and node.get_global_rect().has_area() and node.get_global_rect().intersects(game.get_viewport_rect()):
			buttons.append(node);info.buttons.append({'path':str(game.content_root.get_path_to(node)),'text':node.text if node is Button else '', 'rect':str(node.get_global_rect())})
	for i in buttons.size():
		for j in range(i+1,buttons.size()):
			var a: BaseButton=buttons[i];var b: BaseButton=buttons[j]
			if a.is_ancestor_of(b) or b.is_ancestor_of(a):continue
			var area: Rect2=a.get_global_rect().intersection(b.get_global_rect())
			if area.size.x>3 and area.size.y>3:info.overlap_candidates.append([str(a.name),str(b.name),str(area)])
	observations.screens.append(info)
	assert(root.get_texture().get_image().save_png(output.path_join(label+'.png'))==OK)
	for tween in held:
		if tween.is_valid():tween.play()
func sample(field,phase: String,time: float) -> void:
	var row: Dictionary={'time':time,'party_hp':game.party_hp,'enemy_hp':game.raid_boss_hp if phase=='raid' else game.enemy_hp,'kills':game.combat_kills,'alive':game._alive_hero_ids().size(),'body_overlaps':0,'visible_echoes':[],'paints':[]}
	if phase=='hunt':row.body_overlaps=preload('res://scripts/hunting/HuntBodyCollision.gd').overlapping(game)
	for actor in field.actors.values():
		var pilot=actor.get_node_or_null('HuntFramePilot')
		if pilot==null:continue
		var state: Dictionary=pilot.debug_snapshot()
		row.paints.append({'id':state.id,'action':state.action,'frame':state.frame,'height':state.height,'flip':state.flip})
		if pilot._echoes!=null:
			for instance_index in pilot._echoes.visible_count():row.visible_echoes.append({'id':state.id,'action':state.action,'phase':state.phase,'instance':instance_index,'opacity':pilot._echoes.instance_opacity(instance_index)})
	observations[phase+'_samples'].append(row)
func natural_hunt(faction: String) -> void:
	game.selected_faction=faction;game.party_slot_legacy_cap=10
	var ids: Array[String]=[]
	for hero in ROSTER.roster(faction).slice(0,10):ids.append(hero.id);game.hero_progress[hero.id]={'level':60,'xp':0}
	game._restore_deployed_heroes(ids);game.idle_stage=154;game.current_zone_id='gray_meadow';game.battle_speed=1.0
	game._build_combat_screen();await settle();game.combat_running=true
	if is_instance_valid(game.combat_timer):game.combat_timer.stop()
	var field=game.combat_labels.terrain;field.set_process(false)
	var loot_captured:=false;var damage_captured:=false
	for tick in 600:
		game._advance_auto_hunt(.05)
		for actor in game.hero_map_sprites+game.enemy_wave_sprites:actor.set_process(false)
		field._process(.05)
		if not damage_captured and not get_nodes_in_group('floating_combat_text').is_empty():
			damage_captured=true;await inspect('damage-'+faction)
		if not loot_captured and not field.hunt_overlay.loot_beams.is_empty():
			loot_captured=true;await inspect('loot-'+faction)
		if tick%2==0:sample(field,'hunt',tick*.05)
		if tick%20==0:await process_frame
		if tick in [39,159,599]:await inspect('hunt-'+faction+'-'+str(tick+1))
	game.combat_running=false
func natural_raid() -> void:
	game.selected_raid_id='gray_meadow';game._build_raid_screen();await settle();game._start_raid();await settle()
	if is_instance_valid(game.combat_timer):game.combat_timer.stop()
	var view=game.content_root.get_node('PortraitRaidView');var field=view.battlefield_3d;view.set_process(false);field.set_process(false)
	for tick in 600:
		if not game.raid_running:break
		game._advance_raid_encounter(.05);view._process(.05)
		for actor in view.hero_actors.values()+[game.raid_boss_sprite]:actor.set_process(false)
		field._process(.05)
		if tick%2==0:sample(field,'raid',tick*.05)
		if tick%20==0:await process_frame
		if tick in [39,159,399,599]:await inspect('raid-'+str(tick+1))
	game.raid_running=false
func run() -> void:
	assert(DisplayServer.get_name()!='headless')
	output=OS.get_environment('GAME_AUDIT_OUTPUT');assert(not output.is_empty());DirAccess.make_dir_recursive_absolute(output)
	game=load('res://scenes/PortraitMain.tscn').instantiate();game.save_state_path='user://game-audit.json';game._offline_checked=true;root.add_child(game);await settle()
	game.set_process(false);game.set_physics_process(false);game.sound_effects_enabled=false;game.combat_effects_enabled=true;game.combat_fx.enabled=true;game.tutorial_completed=true
	game.presentation_runtime.contact_time.enabled=false
	game.selected_faction='aurelia';game.party_slot_legacy_cap=10;game.idle_stage=154;game.wallet_gold=48260;game.wallet_gems=840;game.loot_rng.seed=20261007
	game.presentation_runtime.get_node('LootRewardFeedback').bind(game) # Fixture balances are not combat rewards.
	var ids: Array[String]=[]
	for hero in ROSTER.roster('aurelia').slice(0,10):ids.append(hero.id);game.hero_progress[hero.id]={'level':60,'xp':0}
	game._restore_deployed_heroes(ids)
	for entry in [['lobby','_build_lobby_screen'],['heroes','_build_hero_select_screen'],['growth','_build_growth_screen'],['inventory','_build_inventory_screen'],['content','_build_meta_hub_screen'],['summon','_build_summon_screen'],['world','_build_world_map_screen'],['rewards','_build_bm_screen'],['war','_build_faction_war_screen'],['codex','_build_codex_screen'],['boss-select','_build_boss_select_screen'],['stash','_build_equipment_stash']]:
		game.call(entry[1]);await inspect(entry[0])
	game._build_hero_detail_screen('leonhardt');await inspect('hero-detail')
	game._build_lobby_screen();game._show_main_menu();await inspect('menu')
	await natural_hunt('aurelia');await natural_hunt('noxfera');await natural_raid()
	var file=FileAccess.open(output.path_join('observations.json'),FileAccess.WRITE);file.store_string(JSON.stringify(observations,'  '));file.close()
	game.presentation_runtime.audio.shutdown();game.background_hunt.discard();game.queue_free();await settle();print('GAME_AUDIT_CAPTURE_OK');quit()
