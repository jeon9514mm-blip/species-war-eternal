extends SceneTree

var failures: Array[String] = []
var checks := 0
var test_root := "user://v27-save-recovery-%d" % OS.get_process_id()
var store := SaveStore.new()

func _init() -> void:
	_run.call_deferred()

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		print("V27 SAVE FAIL: ", label)

func _write(path: String, value: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	_check(file != null, "test fixture opens " + path.get_file())
	if file != null:
		file.store_string(value)
		file.close()

func _read(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var value := file.get_as_text()
	file.close()
	return value

func _path(name_value: String) -> String:
	return test_root.path_join(name_value + ".json")

func _test_store() -> void:
	var path := _path("roundtrip")
	_check(store.read_save(path).get("status") == "missing", "missing save is an explicit first launch")
	_check(store.write_save(path, {"wallet_gold": 111, "battle_speed": 2.0, "float_precision": 1.23456789}).get("ok", false), "new save commits")
	var loaded := store.read_save(path)
	_check(loaded.get("ok", false) and loaded.get("source") == "primary" and int(loaded["data"]["wallet_gold"]) == 111, "checksum survives integer and float JSON round trip")
	var flat = JSON.parse_string(_read(path))
	_check(flat.has("wallet_gold") and int(flat["save_version"]) == SaveStore.VERSION, "flat diagnostic keys remain compatible")
	_check(store.write_save(path, {"wallet_gold": 222}).get("ok", false), "second save commits")
	_check(int(store._read_candidate(path + ".bak")["data"]["wallet_gold"]) == 111, "previous valid generation is backed up")
	_write(path, "{\"wallet_gold\":")
	loaded = store.read_save(path)
	_check(loaded.get("ok", false) and loaded.get("source") == "backup" and int(loaded["data"]["wallet_gold"]) == 111, "truncated primary recovers backup")
	_check(store.write_save(path, {"wallet_gold": 333}).get("ok", false), "recovered game can save again")
	_check(int(store._read_candidate(path + ".bak")["data"]["wallet_gold"]) == 111, "corrupt primary cannot replace valid backup")
	_check(_read(path + ".corrupt") == "{\"wallet_gold\":", "damaged original is retained for diagnosis")
	var payload = JSON.parse_string(_read(path))
	payload["wallet_gold"] = 999
	_write(path, JSON.stringify(payload))
	_check(store._read_candidate(path).get("status") == "checksum_mismatch", "valid JSON with changed payload is rejected")
	_check(store.read_save(path).get("source") == "backup", "checksum mismatch also recovers backup")
	payload.erase(SaveStore.INTEGRITY_KEY)
	_write(path, JSON.stringify(payload))
	_check(store._read_candidate(path).get("status") == "missing_integrity", "v27 integrity cannot be silently stripped")
	_write(path, "{\"save_version\":[]}")
	_check(store._read_candidate(path).get("status") == "invalid_version", "wrong version type is rejected without a runtime error")
	_write(path, "{\"save_version\":27.5}")
	_check(store._read_candidate(path).get("status") == "invalid_version", "fractional version is rejected")
	_write(path, "{\"save_version\":27,\"_save_integrity\":{\"format\":[],\"sha256\":\"bad\"}}")
	_check(store._read_candidate(path).get("status") == "invalid_integrity", "wrong integrity metadata type is rejected without conversion errors")

	var temporary := _path("interrupted_first_save")
	_check(store.write_save(temporary, {"wallet_gold": 456}).get("ok", false), "interruption fixture saved")
	DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(temporary + ".tmp"))
	loaded = store.read_save(temporary)
	_check(loaded.get("source") == "temporary" and int(loaded["data"]["wallet_gold"]) == 456, "verified temporary file recovers interrupted first save")
	_check(store.write_save(temporary, {"wallet_gold": 567}).get("ok", false), "temporary recovery commits to primary")
	_write(temporary + ".tmp", "{\"save_version\":20,\"wallet_gold\":999}")
	_check(int(store.read_save(temporary)["data"]["wallet_gold"]) == 567, "uncommitted temporary never overrides a valid primary")

	var failed_path := _path("failed_write")
	store.write_save(failed_path, {"wallet_gold": 800})
	DirAccess.make_dir_absolute(ProjectSettings.globalize_path(failed_path + ".tmp"))
	_check(not store.write_save(failed_path, {"wallet_gold": 900}).get("ok", true), "temporary open failure is reported")
	_check(int(store.read_save(failed_path)["data"]["wallet_gold"]) == 800, "failed write preserves committed progress")
	var failed_backup := _path("failed_backup")
	store.write_save(failed_backup, {"wallet_gold": 90})
	DirAccess.make_dir_absolute(ProjectSettings.globalize_path(failed_backup + ".bak.tmp"))
	_check(store.write_save(failed_backup, {"wallet_gold": 91}).get("status") == "backup_failed", "backup write failure blocks primary replacement")
	_check(int(store.read_save(failed_backup)["data"]["wallet_gold"]) == 90, "failed backup leaves old primary usable")
	var failed_archive := _path("failed_archive")
	_write(failed_archive, "damaged original")
	DirAccess.make_dir_absolute(ProjectSettings.globalize_path(failed_archive + ".corrupt"))
	_check(store.write_save(failed_archive, {"wallet_gold": 1}).get("status") == "corrupt_archive_failed", "failed corrupt-file preservation blocks replacement")
	_check(_read(failed_archive) == "damaged original", "failed archive preserves the original bytes")

	var future := _path("future")
	var future_text := "{\"save_version\":99,\"wallet_gold\":7654321}"
	_write(future, future_text)
	_check(store.read_save(future).get("unsupported", false), "future version is identified")
	_check(store.write_save(future, {"wallet_gold": 0}).get("unsupported", false) and _read(future) == future_text, "downgrade never overwrites a future primary")
	_write(future + ".bak", future_text)
	_write(future, "broken")
	_check(store.read_save(future).get("unsupported", false), "future backup is also protected")
	_check(store.write_save(future, {"wallet_gold": 0}).get("unsupported", false) and _read(future + ".bak") == future_text, "downgrade preserves the only recoverable future backup")

	var oversized := _path("oversized")
	_write(oversized, " ".repeat(SaveStore.MAX_FILE_BYTES + 1))
	_check(store._read_candidate(oversized).get("status") == "too_large", "oversized disk payload is rejected before JSON parsing")

func _test_validation() -> void:
	var raw := {
		"save_version": 20, "wallet_gold": -500, "wallet_xp": [], "wallet_gems": 1e100,
		"idle_stage": -1, "idle_stage_kills": 99999, "last_idle_timestamp": [], "battle_speed": {},
		"selected_faction": "unknown", "current_zone_id": "invalid", "rewarded_ad_claimed_count": -1,
		"daily_dungeon_runs": 200, "weekly_trial_runs": -1, "summon_pity": 999,
		"hero_progress": {"leonhardt": {"level": 1e100, "xp": -3}, "mira": [], "elisia": {"level": 4, "xp": 10}, "fake": {"level": 50}},
		"hero_equipment": {"leonhardt": {"weapon": -1, "armor": {}, "accessory": 999, "fake": 10}},
		"hero_equipment_rarity": {"leonhardt": {"weapon": "epic", "armor": [], "accessory": "fake"}},
		"hero_equipment_sets": {"leonhardt": {"weapon": "월광", "armor": "fake"}},
		"hero_skill_tree": {"elisia": {"offense": 999, "survival": 999, "utility": []}},
		"pet_progress": {"aurelia": {"level": 1, "evolution": 999, "xp": -1}, "noxfera": []},
		"hero_shards": {"mira": [], "fake": 999}, "raid_clears": {"gray_meadow": [], "fake": 99},
		"party_presets": [["mira", "mira", {}, "fake"], "bad", ["leonhardt"]],
		"deployed_hero_ids": ["leonhardt", "leonhardt", 12, {}, "fake"],
		"loot_inventory": [[], "bad", {"slot": "fake"}, {"id": "dup", "slot": "armor", "level": -1}, {"id": "dup", "slot": "armor"}, {"slot": "weapon", "rarity": [], "level": 999}],
		"faction_war": [], "world_authority": [], "tutorial_completed": [], "quest_claimed": {"stage5": true, "raid1": [], "fake": true}
	}
	var clean := SaveValidation.sanitize(raw, ["gray_meadow", "forgotten_mine", "moonrest"])
	_check(clean["wallet_gold"] == 0 and clean["wallet_xp"] == 0 and clean["wallet_gems"] == SaveValidation.MAX_CURRENCY, "negative, wrong-type, and overflowing currencies normalize")
	_check(clean["idle_stage"] == 1 and clean["idle_stage_kills"] == 9 and clean["battle_speed"] == 1.0, "stage and speed inputs normalize")
	_check(clean["selected_faction"] == "" and clean["current_zone_id"] == "gray_meadow", "unknown faction and zone cannot reach runtime")
	_check(clean["daily_dungeon_runs"] == 3 and clean["weekly_trial_runs"] == 0 and clean["summon_pity"] == 9, "limited content counters stay in bounds")
	_check(clean["hero_progress"]["leonhardt"] == {"level": 100, "xp": 0} and clean["hero_progress"]["mira"]["level"] == 1 and not clean["hero_progress"].has("fake"), "nested hero progress is typed, bounded, and known")
	_check(clean["hero_equipment"]["leonhardt"] == {"weapon": 1, "armor": 1, "accessory": 10}, "equipment keeps exactly three bounded slots")
	_check(clean["hero_equipment_rarity"]["leonhardt"]["weapon"] == "전설" and clean["hero_equipment_rarity"]["leonhardt"]["armor"] == "일반", "legacy rarity migrates and bad rarity defaults")
	_check(clean["hero_skill_tree"]["elisia"] == {"offense": 1, "survival": 0, "utility": 0}, "skill tree cannot spend more points than the hero level grants")
	_check(clean["pet_progress"]["aurelia"]["evolution"] == 0 and clean["pet_progress"]["noxfera"]["level"] == 1, "pet evolution derives from a valid level")
	_check(clean["deployed_hero_ids"] == ["leonhardt"] and clean["party_presets"][0] == ["mira"], "party and presets reject unknown and duplicate hero IDs")
	_check(clean["loot_inventory"].size() == 2 and clean["loot_inventory"][1]["level"] == 10 and not str(clean["loot_inventory"][1]["id"]).is_empty(), "inventory rejects invalid and duplicated entries and gives legacy IDs")
	_check(clean["faction_war"].is_empty() and clean["world_authority"].is_empty() and clean["quest_claimed"] == {"stage5": true}, "world root containers and quest IDs are sanitized")
	_check(not clean["tutorial_completed"], "wrong-type tutorial flags cannot crash boolean comparison")
	_check(raw["hero_progress"]["leonhardt"]["level"] == 1e100, "validation leaves the source payload unchanged")
	var many: Array = []
	for index in SaveValidation.INVENTORY_CAP + 20:
		many.append({"id": "item_%d" % index, "slot": "weapon"})
	_check(SaveValidation.sanitize({"loot_inventory": many}, ["gray_meadow"])["loot_inventory"].size() == SaveValidation.INVENTORY_CAP, "inventory cannot exceed the playable capacity")
	for invalid in [null, true, "NaN", [], {}, INF, NAN]:
		_check(SaveValidation.number(invalid, 7, 0, 10) == 7, "numeric validator rejects " + str(invalid))

func _test_main() -> void:
	var path := _path("main_migration")
	_write(path, JSON.stringify({"save_version": 4, "selected_faction": "aurelia", "wallet_gold": 123, "last_idle_timestamp": int(Time.get_unix_time_from_system())}))
	var main = preload("res://scenes/Main.tscn").instantiate()
	# Set before add_child/_ready, so this script never touches the real save.
	main.save_state_path = path
	root.add_child(main)
	await process_frame
	main.set_physics_process(false)
	_check(main.wallet_gold == 123 and main.deployed_heroes.size() == 3 and main.party_slot_legacy_cap == 3, "v4 migration preserves currency and three starter heroes")
	main._save_idle_state()
	_check(store.read_save(path)["data"]["save_version"] == SaveStore.VERSION and main.last_save_status == "saved", "Main migrates through the current verified writer")
	var high_water := int(Time.get_unix_time_from_system()) + 600
	main.last_idle_timestamp = high_water
	main._save_idle_state()
	_check(main.last_idle_timestamp == high_water and int(store.read_save(path)["data"]["last_idle_timestamp"]) == high_water, "autosave never lowers a future timestamp after clock rollback")
	_write(path, JSON.stringify({"save_version": 20, "selected_faction": "aurelia", "deployed_hero_ids": [], "wallet_gold": -10, "wallet_xp": [], "hero_progress": {"leonhardt": []}}))
	main._load_idle_state()
	_check(main.deployed_heroes.is_empty() and main.wallet_gold == 0 and main.wallet_xp == 0, "modern empty party stays empty and malformed currency loads safely")
	_write(path, JSON.stringify({"save_version": 20, "selected_faction": "aurelia", "idle_stage": 1, "deployed_hero_ids": ["leonhardt", "leonhardt", "mira", "caelum", "valeria"]}))
	main._load_idle_state()
	_check(main._deployed_hero_ids() == ["leonhardt"], "Main restores only one unlocked, unique, same-faction hero at stage one")
	main._build_combat_screen()
	await process_frame
	main.set_physics_process(false)
	main._notification(Node.NOTIFICATION_APPLICATION_PAUSED)

	# Two completed five-member packs survive the 88% receipt rounding.
	main.last_idle_timestamp -= ceili(preload("res://scripts/progression/GrowthEconomyRules.gd").unmeasured_pack_interval(main.deployed_heroes.size()) * 2.0) + 1
	var pause_timestamp: int = main.last_idle_timestamp
	main._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	_check(main._application_suspended and main.last_idle_timestamp == pause_timestamp, "duplicate pause cannot consume pending offline time")
	var rewards_before: int = main.unclaimed_gold
	main._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	var rewards_after: int = main.unclaimed_gold
	_check(not main._application_suspended and rewards_after > rewards_before, "resume grants pending offline progress once")
	main._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	main._calculate_offline_reward()
	_check(main.unclaimed_gold == rewards_after, "duplicate resume and repeated reward callback cannot grant twice")
	main._load_idle_state()
	main._offline_checked = false
	main._calculate_offline_reward()
	_check(main.unclaimed_gold == rewards_after, "reward timestamp persists across reload and prevents an immediate duplicate")
	main.active_screen = ""
	main.combat_running = false
	main.free()

	var future_path := _path("main_future")
	var future_text := "{\"save_version\":99,\"wallet_gold\":987654}"
	_write(future_path, future_text)
	var future_main = preload("res://scenes/Main.tscn").instantiate()
	future_main.save_state_path = future_path
	root.add_child(future_main)
	await process_frame
	future_main._save_idle_state()
	_check(future_main._save_blocked_for_newer_version and future_main.last_save_status == "unsupported_version" and _read(future_path) == future_text, "Main blocks autosave after loading an unsupported future version")
	future_main.free()

func _remove_tree(path: String) -> void:
	var directory := DirAccess.open(path)
	if directory == null:
		return
	for entry in directory.get_files():
		directory.remove(entry)
	for entry in directory.get_directories():
		_remove_tree(path.path_join(entry))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _run() -> void:
	_check(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(test_root)) == OK, "isolated save fixture directory exists")
	_test_store()
	_test_validation()
	await _test_main()
	_remove_tree(test_root)
	await create_timer(0.5).timeout
	await process_frame
	if not failures.is_empty():
		push_error("v27_save_recovery_smoke_test_failed checks=%d failures=%d: %s" % [checks, failures.size(), "; ".join(failures)])
		quit(1)
		return
	print("v27_save_recovery_smoke_test_ok checks=%d atomic=ok backup=ok checksum=ok schema=ok migration=ok future=preserved pause=once isolation=ok" % checks)
	quit(0)
