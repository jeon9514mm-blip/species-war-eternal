extends SceneTree

var checks := 0
var failures: Array[String] = []
const MENU = preload("res://scripts/portrait/PortraitMenus.gd")

func _init() -> void:
	run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)

func run() -> void:
	root.size = Vector2i(720, 1280)
	var main = preload("res://scenes/PortraitMain.tscn").instantiate()
	main.save_state_path = "user://v46-stability.json"
	root.add_child(main)
	await process_frame
	main.set_physics_process(false)
	main._offline_checked = true
	main.selected_faction = "aurelia"
	main._restore_deployed_heroes(["leonhardt"])
	main._build_hero_select_screen()
	await process_frame
	var nav: Node = main.content_root.get_node("PortraitNavigation")
	check(nav.get_child_count() == 7, "all seven portrait navigation buttons are constructed")
	main._save_party_preset(0)
	main.deployed_heroes.clear()
	main._build_hero_select_screen()
	await process_frame
	main.content_root.get_node("RosterConfirm").pressed.emit()
	check(main.active_screen == "hero_select", "empty party cannot enter ready screen")
	check(main.party_presets[0] == ["leonhardt"], "empty confirm preserves existing preset")
	main._restore_deployed_heroes(["leonhardt"])
	main.hero_roster_filter = "컨트롤러"
	main._build_hero_select_screen()
	await process_frame
	MENU._auto_party(main)
	check(main._deployed_hero_ids() == ["leonhardt"], "empty unlocked filter cannot erase current party")
	# Actual button callbacks remain valid through repeated screen reconstruction.
	main.hero_roster_filter = "전체"
	main.idle_stage = 100
	for faction: String in ["aurelia", "noxfera"]:
		main._build_faction_screen()
		await process_frame
		main._select_faction(faction)
		main._build_hero_select_screen()
		await process_frame
		MENU._auto_party(main)
		await process_frame
		check(main.deployed_heroes.size() == 10, faction + " auto party fills ten slots")
		for id in main._deployed_hero_ids():
			check(main._hero_faction(id) == faction, "auto party keeps faction: " + id)
		main._save_party_preset(1)
		main._save_idle_state()
		var ids: Array = main._deployed_hero_ids()
		main._load_idle_state()
		check(main._deployed_hero_ids() == ids, faction + " party survives save/load")
		main._build_combat_screen()
		await process_frame
		for key in ["heroes", "bag", "growth", "battle", "war", "content", "summon"]:
			var navigation: Node = main.portrait_hud.get_node("PortraitNavigation")
			navigation.get_node("PortraitNav_" + key).pressed.emit()
			await process_frame
			check(not main.active_screen.is_empty(), faction + " navigation callback " + key)
			main._build_combat_screen()
			await process_frame
	main.free()
	await process_frame
	# Old saves receive their entitlement BEFORE the current slot cap is applied.
	for faction: String in ["aurelia", "noxfera"]:
		var path := "user://v46-legacy-" + faction + ".json"
		var file := FileAccess.open(path, FileAccess.WRITE)
		file.store_string(JSON.stringify({"save_version":4,"selected_faction":faction,"wallet_gold":321}))
		file.close()
		var legacy = preload("res://scenes/PortraitMain.tscn").instantiate()
		legacy.save_state_path = path
		root.add_child(legacy)
		await process_frame
		check(legacy.deployed_heroes.size() == 3 and legacy.party_slot_legacy_cap == 3, faction + " legacy three-person party retained")
		check(legacy.wallet_gold == 321, faction + " legacy wallet retained")
		legacy._save_idle_state()
		legacy._load_idle_state()
		check(legacy.deployed_heroes.size() == 3, faction + " migrated party survives second load")
		legacy.free()
	# Downgrades must preserve an interrupted newer save, including its exact bytes.
	var store := SaveStore.new()
	var future_path := "user://v46-future.json"
	var future_text := "{\"save_version\":99,\"wallet_gold\":9876}"
	var temporary := FileAccess.open(future_path + ".tmp", FileAccess.WRITE)
	temporary.store_string(future_text)
	temporary.close()
	check(store.read_save(future_path).get("unsupported", false), "future temporary version is detected")
	check(store.write_save(future_path, {"wallet_gold":0}).get("unsupported", false), "writer refuses future temporary overwrite")
	check(FileAccess.get_file_as_string(future_path + ".tmp") == future_text, "future temporary bytes remain intact")
	print("v46_stability checks=%d failures=%d" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
