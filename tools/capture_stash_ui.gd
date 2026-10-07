extends SceneTree
## Run with temporary XDG directories; fixtures never use a live player save.
const GEAR=preload('res://scripts/equipment/EquipmentRules.gd')
var game: Node
var output: String
func _init() -> void:run.call_deferred()
func settle() -> void:
	for i in 8:await process_frame
func shot(label: String) -> void:
	await settle();await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(output.path_join(label+'.png'))==OK)
func run() -> void:
	root.content_scale_size=Vector2i(1280,720);root.size=Vector2i(1280,720)
	output=ProjectSettings.globalize_path('res://checks/stash-improvement');DirAccess.make_dir_recursive_absolute(output)
	game=preload('res://scenes/PortraitMain.tscn').instantiate();game.save_state_path='user://stash-preview.json'
	root.add_child(game);await settle();game.set_process(false);game.set_physics_process(false)
	game._offline_checked=true;game.selected_faction='aurelia';game.idle_stage=100
	game._restore_deployed_heroes(['leonhardt','mira','elisia']);game.combat_effects_enabled=false;game.sound_effects_enabled=false
	game.loot_inventory=[];game.equipment_overflow=[]
	for i in 1900:
		game.equipment_overflow.append(GEAR.normalize({'id':'stash-preview-%04d'%i,'name':['서리 원정검','심연 수호갑옷','빙하의 부적'][i%3],
			'slot':['weapon','armor','accessory'][i%3],'level':3,'rarity':['일반','희귀','전설'][i%3],
			'origin':'raid','source_id':'gray_meadow','set':'새벽의 맹약','locked':i%2==0,'affixes':[{'stat':'attack_pct','value':5}]}))
	for i in 195:game.loot_inventory.append(GEAR.normalize({'id':'bag-preview-%03d'%i,'name':'원정 장비','slot':'weapon','rarity':'희귀','level':2,'origin':'hunt'}))
	game.equipment_mail_headers={}
	for item: Dictionary in game.equipment_overflow:
		game.equipment_mail_headers[str(item.id)]={'title':'레이드 장비 배송','sent_at':int(Time.get_unix_time_from_system())}
	game._build_equipment_stash();await settle();game.content_root.get_node('EquipmentStashView')._select_free();await shot('stash-page')
	game._build_inventory_screen();await shot('bag-stash-shortcut')
	game.presentation_runtime.audio.shutdown();game.queue_free();await create_timer(.4).timeout;quit()
