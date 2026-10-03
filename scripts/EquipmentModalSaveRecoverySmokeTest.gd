extends 'res://scripts/V83UpgradeTestBase.gd'
## Real pointer routing and a failed-write/retry cycle through production commands.
class FailedStore extends SaveStore:
	func write_save(_path: String, _data: Dictionary) -> Dictionary:
		return {'ok':false,'status':'injected_recovery_write_failure'}
var main: Node
func _init() -> void:run.call_deferred()
func node(named: String) -> Node:return main.content_root.find_child(named,true,false)
func click(point: Vector2) -> void:
	var motion:=InputEventMouseMotion.new();motion.position=point;root.push_input(motion,true)
	for down in [true,false]:
		var event:=InputEventMouseButton.new();event.position=point;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down;root.push_input(event,true)
	await settle()
func tap(named: String, expected_enabled: bool=true) -> void:
	var target: Button=main.find_child(named,true,false)
	check(target!=null,'control exists '+named)
	if target==null:return
	var ancestor: Node=target.get_parent()
	while ancestor!=null:
		if ancestor is ScrollContainer:ancestor.ensure_control_visible(target)
		ancestor=ancestor.get_parent()
	await settle()
	check(target.is_visible_in_tree(),'control visible '+named)
	check(target.disabled!=expected_enabled,'control availability '+named)
	check(main.get_viewport_rect().encloses(target.get_global_rect()),'control fits viewport '+named)
	await click(target.get_global_rect().get_center())
func modal_controls() -> void:
	main.loot_inventory=[main.GEAR.normalize({'id':'modal-item','name':'입력 검증 장비','slot':'weapon','level':3,'rarity':'희귀','origin':'hunt','source_id':'gray_meadow'})]
	main.set_meta('gear_bag_filters',{})
	for dimensions: Vector2i in [Vector2i(1280,720),Vector2i(1560,720)]:
		root.size=dimensions;await settle()
		for opening: String in ['GearSettingsToggle','GearSource']:
			main._build_inventory_screen();await settle();await tap(opening)
			var content: int=main.content_root.get_instance_id()
			var bag: Array=main.loot_inventory.duplicate(true)
			var wallet: int=main.wallet_gold
			var filters: Dictionary=main.get_meta('gear_bag_filters',{}).duplicate(true)
			check(node('EquipmentOverlay')!=null,'equipment overlay opened '+opening)
			await tap('PortraitNav_home')
			check(main.active_screen=='inventory' and main.content_root.get_instance_id()==content and node('EquipmentOverlay')!=null,'modal blocks background home input '+opening+' '+str(dimensions))
			if main.active_screen!='inventory' or node('EquipmentOverlay')==null:continue
			await tap('GearLoadout_armor')
			check(main.get_meta('gear_bag_filters',{})==filters,'modal blocks underlying equipment category input '+opening)
			check(main.loot_inventory==bag and main.wallet_gold==wallet,'blocked background taps cannot move items or spend gold')
			await tap('EquipmentOverlayClose')
			check(node('EquipmentOverlay')==null and main.active_screen=='inventory','close keeps inventory open '+opening)
			await tap('PortraitNav_home')
			check(main.active_screen=='combat','background navigation resumes at hunting home only after modal closes')
	# Production inventory resize reconstructs its presenter and navigation.
	main._build_inventory_screen();await settle();await tap('GearSettingsToggle')
	root.size=Vector2i(1440,810);await settle()
	check(node('EquipmentOverlay')!=null,'open management survives viewport resize')
	await tap('PortraitNav_home')
	check(main.active_screen=='inventory' and node('EquipmentOverlay')!=null,'resized modal still takes input before rebuilt navigation')
	if main.active_screen=='inventory' and node('EquipmentOverlay')!=null:
		var escape:=InputEventKey.new();escape.keycode=KEY_ESCAPE;escape.pressed=true;root.push_input(escape,true);await settle()
		check(node('EquipmentOverlay')==null,'escape dismisses resized management overlay')
		await tap('PortraitNav_home')
		check(main.active_screen=='combat','navigation resumes at hunting home after escape closes modal')
func save_recovery() -> void:
	var working_store=main.save_store
	main.hero_ascension.clear();main.hero_breakthrough.clear();main.hero_shards.clear()
	main.hero_skill_tree['leonhardt']={'offense':0,'survival':0,'utility':0}
	main.wallet_gold=10000;main.hero_shards['leonhardt']=45
	main.set_meta('hero_showcase_tab','ascension');main._build_hero_detail_screen('leonhardt');await settle()
	var first_cost: int=main._ascension_requirement('leonhardt').gold
	main.save_store=FailedStore.new();await tap('HeroAscendAction')
	check(SAFETY.pending(main) and main._hero_ascension_rank('leonhardt')==1,'failed write retains exactly one awarded ascension and raises save barrier')
	check(main.wallet_gold==10000-first_cost and node('HeroAscendAction').disabled and node('HeroBreakthroughAction').disabled,'pending save disables further progression after charging once')
	var view: int=node('HeroShowcaseView').get_instance_id()
	var scroll: ScrollContainer=node('PortraitContentScroll');scroll.scroll_vertical=48;await settle()
	var position: int=scroll.scroll_vertical
	var locked_gold: int=main.wallet_gold
	var second_cost: int=main._ascension_requirement('leonhardt').gold
	main.save_store=working_store;await tap('RetryPendingSave')
	check(not SAFETY.pending(main) and main.last_save_status=='saved','real retry button clears the barrier after successful disk write')
	check(main._hero_ascension_rank('leonhardt')==1 and main.wallet_gold==locked_gold,'retry never repeats ascension or its cost')
	check(node('HeroShowcaseView').get_instance_id()==view and node('PortraitContentScroll')==scroll and scroll.scroll_vertical==position,'retry updates actions in place without replacing hero view or scrolling')
	check(str(main.get_meta('hero_showcase_id',''))=='leonhardt' and str(main.get_meta('hero_showcase_tab',''))=='ascension','retry preserves the selected hero and task')
	check(not node('HeroAscendAction').disabled and not node('HeroBreakthroughAction').disabled,'eligible progression buttons reactivate when saving recovers')
	await tap('HeroAscendAction')
	check(main._hero_ascension_rank('leonhardt')==2 and main.wallet_gold==locked_gold-second_cost,'next explicit tap applies exactly one new ascension at its current cost')
	check(not SAFETY.pending(main) and main.last_save_status=='saved','subsequent progression is saved normally')
	# A recovered barrier must not override ordinary eligibility requirements.
	main.hero_ascension['leonhardt']=0;main.wallet_gold=first_cost;main.hero_shards['leonhardt']=0
	main._build_hero_detail_screen('leonhardt');await settle()
	main.save_store=FailedStore.new();await tap('HeroAscendAction')
	check(main.wallet_gold==0 and SAFETY.pending(main),'second fixture spends its exact affordable ascension before failing to write')
	main.save_store=working_store;await tap('RetryPendingSave')
	check(not SAFETY.pending(main) and node('HeroAscendAction').disabled and node('HeroBreakthroughAction').disabled,'successful retry keeps unaffordable gold and shard actions disabled')
	# Non-spending growth controls also recover, preserving focus and scroll.
	main._build_hero_detail_screen('leonhardt');await settle();await tap('HeroTab_growth')
	main.save_store=FailedStore.new();main._save_idle_state();await settle()
	check(node('HeroResearch_offense').disabled and node('HeroResearchAllocation').disabled and node('HeroDeployAction').disabled,'a newly raised save barrier disables visible growth and deployment controls')
	main.save_store=working_store;await tap('RetryPendingSave')
	check(not node('HeroResearch_offense').disabled and not node('HeroResearchAllocation').disabled and not node('HeroDeployAction').disabled,'saved growth screen becomes usable without reopening it')
	var focus: Control=node('HeroTab_growth');focus.grab_focus()
	main.set_meta('practice_active',true);await settle()
	check(node('HeroResearch_offense').disabled,'practice barrier still blocks research')
	main.set_meta('practice_active',false);await settle()
	check(not node('HeroResearch_offense').disabled and main.get_viewport().gui_get_focus_owner()==focus,'guard-only refresh preserves keyboard focus')
func run() -> void:
	main=await make_main('aurelia',3);root.size=Vector2i(1280,720);root.gui_embed_subwindows=true;await settle()
	await modal_controls();await save_recovery()
	await dispose(main);done('equipment_modal_save_recovery')
