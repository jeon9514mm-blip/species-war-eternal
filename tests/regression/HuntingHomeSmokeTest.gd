extends "res://tests/support/V83UpgradeTestBase.gd"
## Saved startup, real phone Home taps and preservation of a running encounter.
const NAV = preload("res://scripts/ui/NavigationCatalog.gd")

func _init() -> void: _run.call_deferred()

func tap(main: Node, named: String) -> void:
	var target: Control = main.content_root.find_child(named, true, false)
	check(target != null, "home route control exists " + named)
	if target == null: return
	var point := root.get_final_transform() * target.get_global_rect().get_center()
	for down in [true, false]:
		var event := InputEventScreenTouch.new(); event.position = point; event.pressed = down
		Input.parse_input_event(event)
	await settle()

func battle(main: Node) -> Dictionary:
	return {"content":main.content_root.get_instance_id(),"hp":main.hero_battle_state.duplicate(true),
		"enemies":main.enemy_wave.duplicate(true),"clock":main.invasion.clock,
		"wave":main.hunt_ai.encounter_id,"stage":main.idle_stage,"kills":main.idle_stage_kills,
		"running":main.combat_running,"gold":main.wallet_gold,"xp":main.wallet_xp,
		"offline_gold":main.offline_pending_gold,"offline_xp":main.offline_pending_xp}

func loaded(path: String) -> Node:
	var main = HOST.new(); main.save_state_path = path
	root.add_child(main); main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main.set_process(false); main.set_physics_process(false)
	main.combat_effects_enabled = false; main.sound_effects_enabled = false
	await settle()
	return main

func returning(faction: String) -> void:
	var source = await make_main(faction, 3)
	root.size = Vector2i(1280, 720); await settle()
	source.idle_stage = 100; source.idle_stage_kills = 4
	for zone: String in source._zone_data():
		if zone != "gray_meadow" and source._is_zone_unlocked(zone): source.current_zone_id = zone; break
	source.offline_pending_gold = 123; source.unclaimed_gold = 123
	source.offline_pending_xp = 17; source.unclaimed_xp = 17
	source._save_idle_state()
	var path: String = source.save_state_path
	var zone_id: String = source.current_zone_id
	var ids: Array = source._deployed_hero_ids().duplicate()
	await dispose(source)
	var main = await loaded(path)
	check(main.active_screen == "combat" and main.combat_running, faction + " saved startup opens an active hunt immediately")
	check(main.current_zone_id == zone_id and main.idle_stage == 100 and main.idle_stage_kills == 4, faction + " startup retains region, stage and pack progress")
	check(main._deployed_hero_ids() == ids and main.hero_map_sprites.size() == ids.size(), faction + " startup renders the saved expedition")
	check(main.enemy_wave.size() > 0 and is_instance_valid(main.portrait_hud), faction + " startup uses the actual field and combat HUD")
	check(main.offline_pending_gold == 123 and main.offline_pending_xp == 17, faction + " startup retains unclaimed offline receipts")
	var home: Button = main.content_root.find_child("PortraitNav_home", true, false)
	check(home != null and home.get_theme_stylebox("normal").border_width_left == 2 and NAV.active_tab("combat") == "home", faction + " hunting marks the Home dock as selected")
	# Prove that this is running gameplay, not a still preview.
	var clock: float = main.invasion.clock
	for i in 20: main._advance_auto_hunt(0.1)
	check(main.invasion.clock > clock and main.combat_tick_count > 0, faction + " startup hunt advances live simulation")
	var snapshot := battle(main)
	await tap(main, "PortraitNav_home")
	await tap(main, "PortraitNav_home")
	check(battle(main) == snapshot, faction + " repeated Home taps preserve HP, waves, progress and reward balances")
	main._toggle_combat(main.combat_labels["toggle"])
	snapshot = battle(main)
	await tap(main, "PortraitNav_home")
	check(not main.combat_running and battle(main) == snapshot, faction + " Home preserves an intentional pause")
	main._open_hero_menu(); await settle(); await tap(main, "HeroShowcaseBack")
	check(main.active_screen == "combat" and not main.combat_running, faction + " hero back returns home preserving the manual pause")
	main._build_inventory_screen(); await settle(); await tap(main, "PortraitNav_home")
	check(main.active_screen == "combat" and main.current_zone_id == zone_id, faction + " inventory Home returns to the saved hunting region")
	main._build_login_screen(); await settle()
	var continue_button: Button
	for candidate in main.content_root.find_children("*", "Button", true, false):
		if candidate.text == "이 기기에서 계속하기": continue_button = candidate
	check(continue_button != null, faction + " device continue remains available")
	if continue_button != null:
		continue_button.name = "HomeDeviceContinue"; await tap(main, "HomeDeviceContinue")
	check(main.active_screen == "combat", faction + " device continue opens hunting instead of camp")
	# The previous overview stays explicitly accessible from the menu.
	main._show_main_menu(); await settle(); await tap(main, "PortraitMenu_camp")
	check(main.active_screen == "lobby", faction + " camp overview remains a separate menu destination")
	await tap(main, "PortraitNav_home")
	check(main.active_screen == "combat", faction + " camp Home returns to live hunting")
	await dispose(main)

func _run() -> void:
	Input.set_use_accumulated_input(false); Input.emulate_mouse_from_touch = true
	root.size = Vector2i(1280, 720); root.content_scale_size = root.size
	check(NAV.dock_entries()[0].method == "_open_home", "all dock presenters share the hunting Home route")
	check(NAV.active_tab("lobby") == "more", "separate camp overview is no longer marked as Home")
	for faction in ["aurelia", "noxfera"]: await returning(faction)
	var fresh = await loaded("user://new-home-" + str(Time.get_ticks_usec()) + ".json")
	check(fresh.active_screen == "title", "new player retains first launch onboarding")
	await tap(fresh, "PortraitStartButton")
	check(fresh.active_screen == "faction", "new player starts with faction selection")
	fresh.selected_faction = "aurelia"; fresh.deployed_heroes.clear(); fresh._open_home(); await settle()
	check(fresh.active_screen == "hero_select" and not fresh.combat_running, "empty party routes to formation instead of an empty hunt")
	fresh._save_blocked_for_newer_version = true; fresh._open_home(); await settle()
	check(fresh.active_screen == "login" and not fresh.combat_running, "newer-version save cannot start a mutating hunt")
	await dispose(fresh)
	done("HUNTING_HOME_SMOKE")
