extends SceneTree
## v79 UI flow regression. Verifies the focused status -> primary action -> secondary tools hierarchy.
const RULES=preload('res://scripts/EquipmentRules.gd')
var main: Node
var checks:=0
var failures: Array[String]=[]

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:
		failures.append(message)
		push_error('V79 convenience flow: '+message)

func settle() -> void:
	for frame in 7:await process_frame

func node(named: String) -> Node:
	return main.content_root.find_child(named,true,false)

func run() -> void:
	root.content_scale_size=Vector2i(720,1280);root.size=Vector2i(720,1280)
	main=preload('res://scenes/PortraitMain.tscn').instantiate()
	main.save_state_path='user://v79-convenience-flow.json'
	root.add_child(main);await settle()
	main.set_physics_process(false);main.set_process(false);main._offline_checked=true;main.combat_effects_enabled=false
	main.selected_faction='aurelia';main.idle_stage=30;main.party_slot_legacy_cap=10
	var roster: Array=main._hero_roster_for_faction()
	main.deployed_heroes=roster.slice(0,4).duplicate(true)
	main._setup_hero_progress(roster)
	var hero_id: String=str(roster[0]['id'])

	main._build_hero_detail_screen(hero_id);await settle()
	check(node('HeroStatGrid')!=null,'hero detail exposes scannable stat grid')
	for tab in ['growth','skills','equipment','ascension']:
		check(node('HeroTab_'+tab)!=null,'hero showcase keeps direct task selection '+tab)
	node('HeroTab_skills').pressed.emit();await settle()
	for slot in ['a1','a2','passive','ultimate']:
		check(node('HeroSkill_'+slot)!=null,'focused hero skill tab retains '+slot)
	node('HeroTab_equipment').pressed.emit();await settle()
	for slot in ['weapon','armor','accessory']:
		check(node('HeroGear_'+slot)!=null,'focused hero equipment tab retains '+slot)
	check(node('HeroEquipmentBag')!=null,'hero equipment exposes compare-and-replace bag shortcut')

	main.set_meta('growth_hero_id',hero_id);main._build_growth_screen();await settle()
	check(node('GrowthHeroPicker')!=null and node('GrowthHeroPrevious')!=null and node('GrowthHeroNext')!=null,'growth supports previous/direct/next hero selection')
	check(node('GrowthMetrics')!=null and node('GrowthRecommendation')!=null,'growth shows point summary and role-based recommendation')
	for branch in ['offense','survival','utility']:
		check(node('GrowthBranchCard_'+branch)!=null and node('GrowthBranch_'+branch)!=null,'growth keeps actionable '+branch+' branch')

	main.wallet_gems=500
	main.set_meta('summon_mode','hero');main.set_meta('summon_hero_id',hero_id);main._build_summon_screen();await settle()
	check(node('SummonModeTabs')!=null and node('SummonResourceSummary')!=null,'summon shows mode tabs and currency summary first')
	check(node('HeroSummonPity')!=null and node('HeroSummonButton')!=null,'hero summon shows pity and primary summon action')
	check(node('SummonHeroPicker')!=null and node('BreakthroughMetrics')!=null and node('SummonBreakthrough')!=null,'breakthrough target and cost state stay together')

	var gear: Dictionary=RULES.normalize({'id':'v79_fixture','name':'동선 검증검','slot':'weapon','level':3,'rarity':'희귀','origin':'hunt','source_id':'gray_meadow','set':'초보자'})
	main.loot_inventory=[gear]
	main._build_equipment_detail('v79_fixture');await settle()
	check(node('EquipmentDetailHeader')!=null and node('EquipmentDetailState')!=null,'equipment detail keeps selected item context fixed')
	check(node('EquipmentDetailTabs')!=null and node('EquipmentDetailTabHint')!=null,'equipment detail explains selected task')
	check(node('EquipmentQuickTasks')!=null and node('EquipmentQuickEnhance')!=null and node('EquipmentQuickOptions')!=null,'equipment info exposes common task shortcuts')
	check(node('EquipmentEquipPanel')!=null and node('EquipmentEquip')!=null,'bag equipment keeps compare-and-equip panel')

	if main.presentation_runtime!=null:main.presentation_runtime.audio.shutdown()
	await create_timer(0.3).timeout
	main.free();await settle()
	# v82: audio playback teardown is asynchronous even with the Dummy driver.
	await create_timer(0.3).timeout
	print('v79_convenience_flow checks=%d failures=%d'%[checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
