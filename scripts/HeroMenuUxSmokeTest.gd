extends "res://scripts/V83UpgradeTestBase.gd"
## Exercise the public controls with pointer input, retaining economy and battle ownership.
var main: Node

func _init() -> void: _run.call_deferred()

func node(named: String) -> Node:
	return main.content_root.find_child(named, true, false)

func click(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new(); motion.position = point
	root.push_input(motion, true)
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT; event.position = point; event.pressed = down
		root.push_input(event, true)

func press(named: String) -> void:
	var target: Button = node(named)
	check(target != null, "control exists " + named)
	if target == null: return
	if target.has_meta("menu_group"):
		var menu: Node = node("PortraitActionSheet")
		if menu != null: menu._select_group(str(target.get_meta("menu_group")))
	var parent: Node = target.get_parent()
	while parent != null:
		if parent is ScrollContainer: parent.ensure_control_visible(target)
		parent = parent.get_parent()
	await settle()
	check(target.is_visible_in_tree() and not target.disabled, "control usable " + named)
	check(main.get_viewport_rect().grow(1).encloses(target.get_global_rect()), "control fits viewport " + named)
	click(target.get_global_rect().get_center()); await settle()

func escape() -> void:
	var event := InputEventKey.new(); event.keycode = KEY_ESCAPE; event.pressed = true
	root.push_input(event, true); await settle()

func selected(id: String, tab: String) -> bool:
	return main.active_screen == "hero_detail" and str(main.get_meta("hero_showcase_id", "")) == id and str(main.get_meta("hero_showcase_tab", "")) == tab

func audit_fixed_text() -> void:
	var view: Control = node("HeroShowcaseView")
	if view == null: return
	var fixed_labels: Array[Node] = view.find_children("*", "Label", true, false)
	var right_panel: Node = node("PortraitContentScroll")
	if right_panel != null: fixed_labels.append_array(right_panel.find_children("*", "Label", true, false))
	for label: Node in fixed_labels:
		if not label.is_visible_in_tree(): continue
		var parent: Node = label.get_parent()
		if not parent is Control or parent is Container: continue
		var rect: Rect2 = label.get_global_rect()
		check(parent.get_global_rect().grow(2).encloses(rect), "fixed hero text stays inside its allocated parent " + str(label.text).left(28))
		for sibling: Node in parent.get_children():
			if sibling.get_index() <= label.get_index() or not (sibling is Label or sibling is Button) or not sibling.is_visible_in_tree(): continue
			if str(sibling.text).is_empty(): continue
			var overlap: Rect2 = rect.intersection(sibling.get_global_rect())
			check(overlap.size.x <= 2 or overlap.size.y <= 2, "fixed hero text does not overlap adjacent content " + str(label.text).left(20) + " / " + str(sibling.text).left(20))

func battle_snapshot() -> Dictionary:
	return {"screen":main.active_screen, "content":main.content_root.get_instance_id(),
		"hp":main.hero_battle_state.duplicate(true), "enemies":main.enemy_wave.duplicate(true),
		"clock":main.invasion.clock, "gold":main.wallet_gold, "gems":main.wallet_gems,
		"running":main.combat_running, "wave":main.hunt_ai.encounter_id,
		"skill_auto":main.skill_auto, "ultimate_auto":main.ultimate_auto, "speed":main.battle_speed}

func _run() -> void:
	main = await make_main("aurelia", 3)
	root.size = Vector2i(1280, 720); await settle()
	main.hero_ascension.clear(); main.hero_breakthrough.clear(); main.hero_shards.clear()
	main.hero_skill_tree["leonhardt"] = {"offense":0,"survival":0,"utility":0}
	main.set_meta("hero_showcase_id", "leonhardt"); main.set_meta("hero_showcase_tab", "growth")
	main._build_lobby_screen(); await settle()
	await press("PortraitNav_heroes")
	check(selected("leonhardt", "growth"), "bottom hero dock enters the remembered hero showcase")
	check(node("HeroRosterScroll") != null and node("HeroLevelValue") != null, "hero roster and actual progression are available together")
	var deployed_before: Array = main._deployed_hero_ids().duplicate()
	var before: Dictionary = economic(main)
	await press("HeroRoster_mira")
	check(selected("mira", "growth"), "portrait selection changes the focused hero without leaving the showcase")
	check(main._deployed_hero_ids() == deployed_before and economic(main) == before, "browsing a portrait cannot deploy or spend")
	await press("HeroTab_skills")
	check(selected("mira", "skills"), "skill tab retains the selected hero")
	await press("HeroRoster_leonhardt")
	check(selected("leonhardt", "skills"), "switching portraits retains the selected task")
	await press("HeroTab_growth")
	var points: int = main._skill_tree_available_points("leonhardt")
	var gold: int = main.wallet_gold
	await press("HeroResearch_offense")
	check(main._get_skill_tree("leonhardt").offense == 1 and main._skill_tree_available_points("leonhardt") == points - 1, "one research tap spends exactly one point on the selected hero")
	check(main.wallet_gold == gold and selected("leonhardt", "growth"), "research retains the hero task and does not spend gold")
	before = economic(main)
	await press("HeroResearchAllocation")
	check(main.active_screen == "research_allocation", "hero research shortcut opens the allocation editor")
	node("ResearchDraft_survival").value = 2; await settle()
	check(economic(main) == before, "editing an allocation draft cannot alter progression or currency")
	await press("ResearchCancel")
	check(selected("leonhardt", "growth") and economic(main) == before, "allocation cancel restores the same hero growth tab without applying the draft")
	await press("HeroResearchAllocation")
	node("ResearchDraft_offense").value = 0; node("ResearchDraft_survival").value = 1; await settle()
	await press("ResearchPreview")
	check(not node("ResearchConfirm").disabled and economic(main) == before, "allocation preview enables explicit confirmation without committing")
	await press("ResearchConfirm")
	check(selected("leonhardt", "growth") and main._get_skill_tree("leonhardt") == {"offense":0,"survival":1,"utility":0}, "confirmed allocation returns to the same hero with exactly the previewed point transfer")
	before["hero_skill_tree"]["leonhardt"] = {"offense":0,"survival":1,"utility":0}
	check(economic(main) == before and main._skill_tree_available_points("leonhardt") == points - 1, "allocation preserves currency, earned points, gear and every other progression field")
	await press("HeroDeployAction")
	check(not main._is_hero_deployed("leonhardt") and selected("leonhardt", "growth"), "remove action affects only the displayed hero")
	await press("HeroDeployAction")
	check(main._is_hero_deployed("leonhardt"), "same control restores the displayed hero to the party")
	main._setup_hero_battle_state()
	var summary: Label = node("HeroCombatStats")
	var state: Dictionary = main.hero_battle_state["leonhardt"]
	check(summary != null and summary.text.contains("HP " + main._compact_hud_amount(int(state.max_hp))) and summary.text.contains("공격 " + main._compact_hud_amount(int(state.attack))) and summary.text.contains("방어 " + main._compact_hud_amount(int(state.defense))), "displayed hero stats agree with live battle calculations after research and deployment")
	await press("HeroTab_ascension")
	gold = main.wallet_gold
	var cost: int = int(main._ascension_requirement("leonhardt").gold)
	await press("HeroAscendAction")
	check(main._hero_ascension_rank("leonhardt") == 1 and main.wallet_gold == gold - cost, "one ascension tap applies one rank and the exact existing gold cost")
	check(selected("leonhardt", "ascension"), "ascension retains the selected hero and task")
	main.hero_shards["leonhardt"] = 65
	main._build_hero_detail_screen("leonhardt"); await settle()
	await press("HeroBreakthroughAction")
	check(main._hero_breakthrough_rank("leonhardt") == 1 and main._hero_shard_count("leonhardt") == 45, "breakthrough spends exactly the existing twenty-shard cost")
	for barrier: String in ["game_save_pending", "practice_active", "newer_save_version"]:
		if barrier == "newer_save_version": main._save_blocked_for_newer_version = true
		else: main.set_meta(barrier, true)
		main._build_hero_detail_screen("leonhardt"); await settle()
		before = economic(main)
		check(node("HeroAscendAction").disabled and node("HeroBreakthroughAction").disabled, "progression respects active write barrier " + barrier)
		node("HeroAscendAction").pressed.emit(); node("HeroBreakthroughAction").pressed.emit(); await settle()
		check(economic(main) == before, "forced progression signals respect the write barrier " + barrier)
		await press("HeroTab_growth")
		check(node("HeroResearch_offense").disabled and node("HeroDeployAction").disabled, "research and deployment respect active write barrier " + barrier)
		node("HeroResearch_offense").pressed.emit(); node("HeroDeployAction").pressed.emit(); await settle()
		check(economic(main) == before, "forced research and deployment signals respect the write barrier " + barrier)
		if barrier == "newer_save_version": main._save_blocked_for_newer_version = false
		else: main.set_meta(barrier, false)
		main._build_hero_detail_screen("leonhardt"); await settle()
		await press("HeroTab_ascension")
	main.wallet_gold = 0
	main.hero_shards["leonhardt"] = 0
	main._build_hero_detail_screen("leonhardt"); await settle()
	check(node("HeroAscendAction").disabled and node("HeroBreakthroughAction").disabled, "insufficient resources disable both irreversible progression actions")
	main.wallet_gold = 10000
	await press("HeroTab_equipment")
	var worn: Dictionary = main._gear_item("", "leonhardt", "weapon")
	await press("HeroGear_weapon")
	check(main.active_screen == "equipment_detail" and str(main.gear_workshop_context.item_id) == str(worn.id) and str(main.gear_workshop_context.return_hero_id) == "leonhardt", "equipment opens the exact worn item and records its owning hero")
	await press("EquipmentDetailBack")
	check(selected("leonhardt", "equipment"), "equipment back returns to the same hero and equipment tab")
	await press("HeroEquipmentBag")
	check(main.active_screen == "inventory" and str(main.get_meta("gear_equip_hero_id", "")) == "leonhardt", "replace equipment opens the bag with its hero target preserved")
	await press("PortraitNav_heroes")
	check(selected("leonhardt", "equipment"), "bottom navigation restores hero selection and task after a bag visit")
	for dimensions: Vector2i in [Vector2i(1560,720), Vector2i(1920,1080), Vector2i(640,360), Vector2i(720,1280), Vector2i(1280,720)]:
		root.size = dimensions; await settle()
		check(selected("leonhardt", "equipment") and main.get_viewport_rect().size.x > main.get_viewport_rect().size.y, "resizing retains the hero task and landscape canvas " + str(dimensions))
		for named: String in ["HeroTab_growth", "HeroTab_skills", "HeroTab_equipment", "HeroTab_ascension", "HeroRosterScroll", "PortraitContentScroll"]:
			var control: Control = node(named)
			check(control != null and main.get_viewport_rect().grow(1).encloses(control.get_global_rect()), "hero control remains on-screen " + named + " " + str(dimensions))
		await press("HeroTab_skills"); audit_fixed_text()
		await press("HeroTab_equipment"); audit_fixed_text()
	main.idle_stage = 1
	var locked_id := ""
	for hero: Dictionary in ROSTER.roster("aurelia"):
		if int(hero.unlock_stage) > main.idle_stage: locked_id = str(hero.id); break
	main._build_hero_detail_screen(locked_id); await settle()
	await press("HeroTab_growth")
	check(node("HeroDeployAction").disabled, "locked hero can be inspected but cannot be deployed")
	await press("HeroTab_ascension")
	check(node("HeroAscendAction").disabled and node("HeroBreakthroughAction").disabled, "locked hero progression actions remain disabled")
	before = economic(main)
	click(node("HeroAscendAction").get_global_rect().get_center()); await settle()
	check(economic(main) == before, "disabled locked hero tap cannot consume currency")
	main.selected_faction = "noxfera"; main.idle_stage = 100
	main._restore_deployed_heroes([str(ROSTER.roster("noxfera")[0].id)])
	main._build_lobby_screen(); await settle(); await press("PortraitNav_heroes")
	var selected_id: String = str(main.get_meta("hero_showcase_id", ""))
	check(main._hero_belongs_to_selected_faction(selected_id) and node("HeroRoster_leonhardt") == null, "faction change resolves a valid hero and excludes the previous faction roster")
	main._build_hero_detail_screen("leonhardt"); await settle()
	check(node("HeroRoster_leonhardt") == null, "direct foreign hero request cannot expose an invalid hero showcase")
	await menu_flow()
	await dispose(main); done("hero_menu_ux")

func menu_flow() -> void:
	main.selected_faction = "aurelia"; main.idle_stage = 100
	main._restore_deployed_heroes(["leonhardt", "mira", "seraphina"])
	main._build_combat_screen(); await settle(); main.combat_running = true
	var snapshot: Dictionary = battle_snapshot()
	await press("LandscapeMenuButton")
	var sheet: Control = node("PortraitMenuSheet")
	check(sheet != null and sheet.get_global_rect().position.x > main.get_viewport_rect().size.x * .20, "main menu opens on the right and leaves the field visible on the left")
	check(battle_snapshot() == snapshot, "opening the menu preserves the live encounter and wallet")
	for entry: Dictionary in preload("res://scripts/NavigationCatalog.gd").menu_entries():
		check(node("PortraitMenu_" + str(entry.id)) != null, "canonical menu destination remains reachable " + str(entry.id))
	await press("PortraitMenuClose")
	check(node("PortraitActionSheet") == null and battle_snapshot() == snapshot, "close returns to the same live battle")
	await press("LandscapeMenuButton")
	click(node("PortraitNav_home").get_global_rect().get_center()); await settle()
	check(node("PortraitActionSheet") == null and battle_snapshot() == snapshot, "outside tap dismisses the menu without clicking through or resetting battle")
	await press("LandscapeMenuButton"); await escape()
	check(node("PortraitActionSheet") == null and battle_snapshot() == snapshot, "escape dismisses the menu without resetting battle")
	main._show_main_menu(); main._show_main_menu(); await settle()
	check(main.content_root.find_children("PortraitActionSheet", "", false, false).size() == 1, "repeated menu requests retain one input-blocking sheet")
	root.size = Vector2i(1560,720); await settle()
	check(node("PortraitActionSheet") != null and battle_snapshot() == snapshot, "resizing an open menu preserves the overlay and encounter")
	var effects: bool = main.combat_effects_enabled
	var sounds: bool = main.sound_effects_enabled
	await press("PortraitEffectSetting")
	check(main.combat_effects_enabled != effects and main.sound_effects_enabled == sounds, "resized menu footer toggles only visual effects")
	await press("PortraitEffectSetting")
	await press("PortraitSoundSetting")
	check(main.sound_effects_enabled != sounds and main.combat_effects_enabled == effects, "resized menu footer toggles only sound")
	await press("PortraitSoundSetting")
	check(battle_snapshot() == snapshot, "menu preference taps cannot reach the combat controls behind them")
	await press("PresentationSettingsEntry")
	check(node("PortraitActionSheet") == null and node("PresentationSettingsOverlay") != null, "settings route removes the menu before opening its own overlay")
	await escape()
	check(node("PresentationSettingsOverlay") == null and battle_snapshot() == snapshot, "settings dismissal returns to unchanged combat")
	await press("LandscapeMenuButton"); await press("PortraitMenu_formation")
	check(node("PortraitActionSheet") == null and node("FormationOverlay") != null, "formation route does not stack behind the menu")
	await press("FormationClose")
	check(battle_snapshot() == snapshot, "formation view does not restart combat")
	await press("LandscapeMenuButton"); await press("PortraitOpenGuide")
	check(node("PortraitActionSheet") == null and node("MenuOverlay") != null, "guide route closes the illustrated menu")
	await escape()
	check(battle_snapshot() == snapshot, "guide dismissal retains encounter state")
	await press("LandscapeMenuButton"); await press("PortraitMenu_inventory")
	check(main.active_screen == "inventory" and node("EquipmentWorkbench") != null and node("PortraitActionSheet") == null, "menu bag route reaches the existing two-hundred-slot workbench")
	main._show_main_menu(); await settle(); await press("PortraitMenu_heroes")
	check(main.active_screen == "hero_detail" and node("HeroRosterScroll") != null and node("PortraitActionSheet") == null, "menu hero route uses the same showcase as the bottom dock")
	main._show_main_menu(); await settle(); await press("PortraitMenu_party")
	check(main.active_screen == "hero_select" and node("RosterConfirm") != null, "party editor remains distinct and reachable from the menu")
	main._show_main_menu(); await settle(); await press("PortraitMenu_title")
	check(main.active_screen == "title" and node("PortraitActionSheet") == null, "resized menu footer start-screen action remains reachable")
