extends SceneTree
## Production UI with isolated fixtures; captures never modify a player save.
const RULES=preload('res://scripts/EquipmentRules.gd')
var game: Node
var output: String
func _initialize() -> void:run.call_deferred()
func settle() -> void:
	for i in 8:await process_frame
func capture(label: String) -> void:
	await settle();await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(output.path_join(label+'.png'))==OK)
	print('EQUIPMENT_CAPTURE ',label,' viewport=',game.get_viewport_rect().size)

func run() -> void:
	if DisplayServer.get_name()=='headless':push_error('A display renderer is required.');quit(1);return
	output=ProjectSettings.globalize_path('res://checks/landscape-equipment/captures');DirAccess.make_dir_recursive_absolute(output)
	game=load('res://scenes/PortraitMain.tscn').instantiate();game.save_state_path='user://equipment-preview-'+str(Time.get_ticks_usec())+'.json'
	root.add_child(game);await settle();game.set_process(false);game.set_physics_process(false);game._offline_checked=true
	game.tutorial_completed=true;game.selected_faction='aurelia';game.idle_stage=30;game.wallet_gold=48260;game.raid_crystals=240
	game.deployed_heroes=game._hero_roster_for_faction().slice(0,3);game.loot_inventory=[]
	var hero_id: String=game.deployed_heroes[0].id
	game.set_meta('gear_equip_hero_id',hero_id)
	for slot: String in game.EQUIPMENT_SLOTS:
		var current:=RULES.normalize({'id':'preview-current-'+slot,'name':'월광 수호 '+game._equipment_slot_name(slot),'slot':slot,'level':3,'rarity':'희귀','set':'강철','bound':true,'affixes':[{'stat':'hp_pct','value':6}]})
		game.hero_equipment_items.get_or_add(hero_id,{})[slot]=current
		game._get_hero_equipment(hero_id)[slot]=current.level;game._get_hero_equipment_rarity(hero_id)[slot]=current.rarity
		game._get_hero_equipment_names(hero_id)[slot]=current.name;game._get_hero_equipment_sets(hero_id)[slot]=current.set
	var names:=['성역 수호자의 검','철벽 파수꾼 갑옷','새벽의 목걸이','달잠 숲의 장검','빙하 심연의 갑옷','별빛 수호 장신구']
	for i in 200:
		game.loot_inventory.push_front(RULES.normalize({'id':'preview-gear-%02d'%i,'name':names[i%6],'slot':game.EQUIPMENT_SLOTS[i%3],'rarity':['전설','희귀','일반'][int(i/3)%3],'level':8-i%6,'set':'철벽의 맹세' if i%2==0 else '강철','origin':'raid' if i%2==0 else 'hunt','source_id':'moonrest_forest','locked':i==4,'affixes':[{'stat':'attack_pct','value':6}] if i%2==0 else []}))
	game.presentation_options.orientation='landscape';root.content_scale_size=Vector2i(1280,720);root.size=Vector2i(1280,720)
	game.set_meta('gear_bag_filters',{'sort':'recent'});game.set_meta('gear_bag_selected_id','preview-gear-00');game._build_inventory_screen();await capture('inventory-1280')
	game.content_root.find_child('PortraitContentScroll',true,false).scroll_vertical=300
	game.content_root.find_child('GearTile_preview-gear-12',true,false).pressed.emit();await capture('inventory-selection')
	game.set_meta('gear_bag_page',4);game._build_inventory_screen();await capture('inventory-page-five')
	game.set_meta('gear_settings_open',true);game._build_inventory_screen();await capture('inventory-tools')
	game.set_meta('gear_settings_open',false);game.set_meta('gear_bag_page',0);game._build_equipment_detail('preview-gear-00');await capture('equipment-detail')
	game._build_equipment_detail('preview-gear-00','','','enhance');await capture('equipment-enhance')
	game._build_equipment_detail('preview-gear-00','','','options');await capture('equipment-options')
	game.set_meta('gear_bag_filters',{'query':'장검'});game._build_inventory_screen();await capture('inventory-search')
	game.set_meta('gear_bag_filters',{'sort':'recent'});game.set_meta('gear_bag_scroll',0);game.set_meta('gear_bag_reset_scroll',true);game._build_inventory_screen();root.size=Vector2i(1600,720);await capture('inventory-wide')
	root.size=Vector2i(960,540);await capture('inventory-small-landscape')
	game.presentation_runtime.audio.shutdown();await create_timer(.3).timeout;game.free();await settle();quit()
