extends SceneTree
## Real default game, authored assets and naturally reached raid warnings.
var game: Node
var output: String
const ZONES=['gray_meadow','forgotten_mine','moonrest_forest']
func _init() -> void:run.call_deferred()
func settle() -> void:
	for i in 3:await process_frame
func capture(label: String, extra: Dictionary={}) -> void:
	# Hold existing text at the captured simulation moment while software GPU draws.
	if is_instance_valid(game._damage_pool):
		for number in game._damage_pool.pool:
			if number.visible and is_instance_valid(number._life_tween):number._life_tween.pause()
	await settle();await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(output.path_join(label+'.png'))==OK)
	var record: Dictionary={'capture':label,'scene':'scenes/PortraitMain.tscn','renderer':RenderingServer.get_current_rendering_method(),'size':[root.size.x,root.size.y],'screen':game.active_screen,'damage_font':'Barlow Condensed Black Italic','raid_elapsed':game.raid_elapsed,'raid_hp':game.raid_boss_hp,'capture_holds_existing_text_for_readback':true}
	record.merge(extra)
	var file:=FileAccess.open(output.path_join(label+'.json'),FileAccess.WRITE);file.store_string(JSON.stringify(record,'  '));file.close()
	print('COMBAT_QUALITY_CAPTURE ',label)
func fresh(count: int,level: int) -> void:
	game=load('res://scenes/PortraitMain.tscn').instantiate()
	game.save_state_path=OS.get_environment('MAP_CAPTURE_USER_DATA').path_join(str(Time.get_ticks_usec())+'.json')
	game._offline_checked=true;root.add_child(game);await settle()
	root.content_scale_size=Vector2i(1280,720);root.size=Vector2i(1280,720)
	game.set_process(false);game.set_physics_process(false);game.sound_effects_enabled=false
	game.combat_effects_enabled=true;game.tutorial_completed=true;game.selected_faction='aurelia';game.party_slot_legacy_cap=10;game.loot_rng.seed=20261005
	game.idle_stage=100;game.wallet_gold=0
	var ids: Array[String]=[]
	for hero in preload('res://scripts/heroes/HeroRosterCatalog.gd').roster('aurelia'):
		if ids.size()<count:
			ids.append(str(hero.id));game.hero_progress[str(hero.id)]={'level':level,'xp':0}
	game._restore_deployed_heroes(ids)
func dispose() -> void:
	game.presentation_runtime.audio.shutdown();game.background_hunt.discard();game.queue_free();await settle();game=null
func run() -> void:
	if DisplayServer.get_name()=='headless':push_error('Use a display renderer.');quit(1);return
	output=OS.get_environment('MAP_CAPTURE_OUTPUT');assert(not output.is_empty())
	DirAccess.make_dir_recursive_absolute(output)
	await fresh(3,35);game.idle_stage=54;game._build_combat_screen();await settle()
	game.combat_running=true
	for n in 100:
		game._advance_auto_hunt(.1)
		if n>=90 and is_instance_valid(game._damage_pool):
			var has_numbers:=false
			for number in game._damage_pool.pool:
				if number.visible:has_numbers=true;number._life_tween.pause()
			if has_numbers:break
		if n%10==0:await process_frame
	game.combat_labels.terrain._process(0)
	await capture('hunt-combat',{'zone':'gray_meadow'})
	# Controlled typography board is explicitly a style sample, not gameplay evidence.
	game.combat_running=false
	for label in game._damage_pool.pool:
		if is_instance_valid(label):label.retire()
	for i in 4:
		var kind: String=['damage','critical','incoming','heal'][i]
		preload('res://scripts/presentation/CombatTextPresenter.gd').emit(game,[1280,34560,826,2400][i],kind,Vector2(290+i*230,235),Rect2(10,175,1260,120),'typography-'+kind)
	for label in game._damage_pool.pool:
		if label.visible:label._life_tween.pause();label.scale=Vector2.ONE
	await capture('damage-style-sample',{'not_live_damage':true,'purpose':'numeral face and damage/critical/incoming/heal comparison'})
	game._show_main_menu();await settle()
	await capture('landscape-menu',{'purpose':'final-v28 charcoal bronze moss menu'})
	await dispose()
	await fresh(10,60)
	var rules=preload('res://scripts/equipment/EquipmentRules.gd')
	game.loot_inventory=[]
	for i in 80:
		var slot: String=game.EQUIPMENT_SLOTS[i%3]
		game.loot_inventory.append(rules.normalize({'id':'showcase-%03d'%i,'name':{'weapon':'월광 장검','armor':'수호자의 갑옷','accessory':'별빛 펜던트'}[slot],'slot':slot,'level':4+i%8,'rarity':['일반','희귀','전설'][i%3],'set':['월광','강철','개척자'][i%3],'affixes':[{'stat':'attack_pct','value':4+i%6},{'stat':'hp_pct','value':6+i%8}]}))
	game.wallet_gold=32650;game.set_meta('gear_bag_selected_id','showcase-078')
	game._build_inventory_screen();await settle()
	await capture('equipment-v28',{'fixture_inventory':true,'purpose':'actual equipment interface with representative inspection items, no player save'})
	var workbench=game.content_root.get_node('EquipmentWorkbench')
	workbench._switch_hero(str(game.deployed_heroes[9].id));await settle()
	var search: LineEdit=workbench.find_child('GearSearch',true,false)
	search.text='수호자';search.text_changed.emit(search.text);await create_timer(.3).timeout;await settle()
	await capture('equipment-v28-filtered',{'fixture_inventory':true,'purpose':'tenth hero selected with live armor query'})
	game._build_boss_select_screen();await settle()
	await capture('raid-catalog-v28',{'purpose':'three raid destinations with actual arena art and unchanged stats'})
	await dispose()
	for zone: String in ZONES:
		await fresh(10,60);game.selected_raid_id=zone;game._build_raid_screen();await settle();await settle()
		var view=game.content_root.get_node('PortraitRaidView')
		view.battlefield_3d._process(0)
		await capture(zone+'-raid-ready',{'zone':zone,'art':view.battlefield_3d.painted_backdrop.texture.resource_path})
		game._start_raid();game.combat_timer.stop()
		# Let the real entry animation finish; game simulation stays manually stepped.
		await create_timer(.85).timeout
		var warning_reached:=false
		for n in 600:
			if not game.raid_running:break
			game._advance_raid_encounter(.05);view.refresh();view.battlefield_3d._process(.05)
			if n%5==0:await process_frame
			if game.boss_telegraph_pending and game.boss_telegraph_remaining>.3:
				warning_reached=true;break
		assert(warning_reached,'Natural warning must be reached')
		await capture(zone+'-raid-warning',{'zone':zone,'art':view.battlefield_3d.painted_backdrop.texture.resource_path,'warning':game.boss_telegraph_skill,'natural_warning':warning_reached})
		game.raid_running=false;await dispose()
	await settle();quit.call_deferred()
