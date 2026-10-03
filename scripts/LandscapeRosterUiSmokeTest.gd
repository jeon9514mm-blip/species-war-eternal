extends "res://scripts/V56DungeonRosterUiSmokeTest.gd"
## Reuse real input and shaped-text audits while exercising the landscape release.
func run() -> void:
	root.content_scale_size = Vector2i(1280,720); root.size = Vector2i(1280,720)
	root.gui_embed_subwindows = true
	main = preload("res://scenes/PortraitMain.tscn").instantiate()
	main.save_state_path = "user://landscape-roster-" + str(Time.get_ticks_usec()) + ".json"
	root.add_child(main); await settle()
	main.set_physics_process(false); main.set_process(false); main._offline_checked = true
	main.tutorial_completed = true; main.combat_effects_enabled = false
	await verify_roster()
	await verify_content_return()
	await verify_faction_flow()
	for dimensions: Vector2i in [Vector2i(640,360), Vector2i(1280,720), Vector2i(1560,720), Vector2i(1920,1080), Vector2i(720,1280)]:
		root.size = dimensions; await settle(); fixture()
		for index in main.deployed_heroes.size():
			main.deployed_heroes[index]["name"] = "별빛과 달빛을 지키는 긴 이름의 원정대 영웅 %d" % index
		main._build_hero_select_screen(); await settle()
		check(main.get_viewport_rect().size.x >= 1280 and main.get_viewport_rect().size.x > main.get_viewport_rect().size.y, "physical resize keeps the supported landscape canvas " + str(dimensions))
		audit("landscape roster " + str(dimensions))
		await press("RosterFilter_탱커")
		check(main.hero_roster_filter == "탱커", "filter remains usable after resize " + str(dimensions))
		await press("RosterFilter")
		check(main.hero_roster_filter == "전체", "full roster remains reachable after resize " + str(dimensions))
	main._build_lobby_screen()
	if main.presentation_runtime != null: main.presentation_runtime.audio.shutdown()
	await create_timer(.35).timeout; main.free(); await create_timer(.35).timeout
	print("landscape_roster_ui checks=%d failures=%s screens=%d" % [checks, JSON.stringify(failures), screens])
	quit(0 if failures.is_empty() else 1)

func verify_faction_flow() -> void:
	for dimensions: Vector2i in [Vector2i(1280,720), Vector2i(1560,720), Vector2i(640,360)]:
		root.size = dimensions; await settle()
		main.selected_faction = ""; main.deployed_heroes.clear()
		main._build_faction_screen(); await settle()
		check(main.confirm_button.disabled, "first-run faction confirmation requires an explicit choice " + str(dimensions))
		audit("landscape faction " + str(dimensions))
		separate("FactionCard_aurelia", "FactionCard_noxfera", "two landscape faction choices " + str(dimensions))
		for faction: String in ["aurelia", "noxfera"]:
			main._build_faction_screen(); await settle()
			await press("SelectFaction_" + faction)
			check(main.selected_faction == faction and not main.confirm_button.disabled, "actual faction choice enables confirmation " + faction + " " + str(dimensions))
			await press_control(main.confirm_button, "confirm faction " + faction)
			check(main.active_screen == "intro" and main.selected_faction == faction, "faction confirmation reaches the correct intro " + faction)
			main._open_hero_menu(); await settle()
			check(main.active_screen == "hero_detail" and main._hero_belongs_to_selected_faction(str(main.get_meta("hero_showcase_id", ""))), "new faction opens a valid hero showcase " + faction)

func verify_content_return() -> void:
	for kind: String in ["meta", "raid", "world"]:
		fixture(); main.set_meta("content_meta_tab", "weekly")
		var gold: int = main.wallet_gold
		var crystals: int = main.raid_crystals
		var gems: int = main.wallet_gems
		main._open_content_party(kind, "moonrest_forest" if kind == "raid" else ""); await settle()
		check(main.active_screen == "hero_select" and main.content_party_context.get("kind") == kind, "content entry retains its party destination " + kind)
		var hero_id: String = str(main.deployed_heroes[0].id)
		await press("RosterDetail_" + hero_id)
		check(main.active_screen == "hero_detail" and str(main.get_meta("hero_showcase_id", "")) == hero_id and main.content_party_context.get("kind") == kind, "party portrait opens the same hero without abandoning content route " + kind)
		await press("HeroTab_growth")
		var tree: Dictionary = main._get_skill_tree(hero_id).duplicate(true)
		await press("HeroResearchAllocation")
		check(main.active_screen == "research_allocation" and main.content_party_context.get("kind") == kind, "research allocation retains the original content route " + kind)
		await press("ResearchCancel")
		check(main.active_screen == "hero_detail" and main.content_party_context.get("kind") == kind and main._get_skill_tree(hero_id) == tree, "research cancel returns to the same content hero without changes " + kind)
		await press("HeroResearchAllocation")
		var next_rank: int = int(tree.offense) + 1
		node("ResearchDraft_offense").value = next_rank; await settle()
		await press("ResearchPreview"); await press("ResearchConfirm")
		check(main.active_screen == "hero_detail" and main.content_party_context.get("kind") == kind and int(main._get_skill_tree(hero_id).offense) == next_rank, "research confirmation retains content route and chosen hero " + kind)
		await press("HeroTab_equipment")
		var item: Dictionary = main._gear_item("", hero_id, "weapon")
		await press("HeroGear_weapon")
		check(main.active_screen == "equipment_detail" and str(main.gear_workshop_context.item_id) == str(item.id) and main.content_party_context.get("kind") == kind, "content party equipment inspection retains exact item and route " + kind)
		await press("EquipmentDetailBack"); await press("HeroShowcaseBack")
		check(main.active_screen == "hero_select" and main.content_party_context.get("kind") == kind, "equipment and hero back actions return to content party editor " + kind)
		await press("RosterConfirm")
		var expected_screen: String = {"meta":"meta_hub", "raid":"raid", "world":"world_map"}[kind]
		check(main.active_screen == expected_screen and main.content_party_context.is_empty(), "confirm returns to requested content without restarting selection " + kind)
		if kind == "raid": check(main.selected_raid_id == "moonrest_forest" and not main.raid_running, "raid party return retains boss without starting the fight")
		elif kind == "meta": check(str(main.get_meta("content_meta_tab", "")) == "weekly", "dungeon party return retains selected content tab")
		check(main.wallet_gold == gold and main.wallet_gems == gems and main.raid_crystals == crystals, "content formation round trip has no economic side effects " + kind)
