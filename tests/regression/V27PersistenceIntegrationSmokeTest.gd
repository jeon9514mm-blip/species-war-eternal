extends SceneTree

# Cross-system persistence through real Main instances and real files.
# Isolate deserialization from the separate newly-elapsed offline grant.
class RestoreOnlyHost extends "res://scripts/app/Main.gd":
	var allow_offline: bool = false
	func _calculate_offline_reward() -> void:
		if allow_offline: super._calculate_offline_reward()
var checks := 0
var failures: Array[String] = []
var fixture_root := "user://v27-persistence-integration-%d" % OS.get_process_id()
var supply := WorldSupplyNetwork.new()

func _init() -> void:
	_run.call_deferred()

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		print("V27 PERSISTENCE FAIL: ", message)

func _new_main(path: String, restore_only: bool = false):
	var main = RestoreOnlyHost.new() if restore_only else preload("res://scenes/Main.tscn").instantiate()
	main.save_state_path = path
	root.add_child(main)
	await process_frame
	main.set_physics_process(false)
	main.set_process(false)
	return main

func _dispose(main) -> void:
	main.active_screen = ""
	main.combat_running = false
	if main.presentation_runtime != null: main.presentation_runtime.audio.shutdown()
	await create_timer(0.35).timeout
	await process_frame
	main.free()
	await create_timer(0.35).timeout
	await process_frame

func _party(main) -> void:
	main.selected_faction = "aurelia"
	main.idle_stage = 25
	main._restore_deployed_heroes(["leonhardt", "mira", "elisia"])
	main._setup_hero_skills()

func _bind_world(main) -> void:
	main.faction_war_state.ensure_initialized(main.selected_faction)
	main.world_season_state.ensure_started(main.world_authority.server_now())
	main.world_authority.bind_season(main.world_season_state)
	main.world_authority.register_trusted_party("local_player", main.selected_faction, main._world_party_snapshot(), main._calculate_party_power())

func _command(main, kind: String, target := Vector2i(-1, -1)) -> Dictionary:
	return {"id": main.world_authority.next_command_id(kind), "type": kind, "player_id": "local_player", "faction": main.selected_faction, "target": [target.x, target.y], "issued_at": main.world_authority.server_now(), "expected_revision": main.world_authority.last_revision}

func _submit(main, command: Dictionary) -> Dictionary:
	return main.world_authority.submit_command(main.faction_war_state, main.faction_march_state, main.faction_conflict_state, supply, command)

func _growth_roundtrip() -> void:
	var path := fixture_root.path_join("growth.json")
	var main = await _new_main(path)
	_party(main)
	main.active_screen = "combat"
	main._grant_hero_xp(10800)
	main._grant_hero_xp(153)
	main._upgrade_skill_tree("leonhardt", "offense")
	main._upgrade_skill_tree("leonhardt", "survival")
	main.loot_inventory = [{"id": "persistent_blade", "slot": "weapon", "level": 6, "rarity": "전설", "name": "영속 검증검", "set": "월광"}]
	main._equip_inventory_item(0, "leonhardt", "persistent_blade")
	_check(main.hero_progress["leonhardt"] == {"level": 10, "xp": 51} and main.hero_skill_tree["leonhardt"]["offense"] == 1 and main.hero_equipment["leonhardt"]["weapon"] == 6, "XP, tree and equipment actions actually apply before persistence")
	var progress: Dictionary = main.hero_progress.duplicate(true)
	var tree: Dictionary = main.hero_skill_tree.duplicate(true)
	var inventory: Array = main.loot_inventory.duplicate(true)
	main._save_idle_state()
	_check(main.last_save_status == "saved", "growth state commits through Main")
	await _dispose(main)
	var restored = await _new_main(path)
	_check(restored.hero_progress == progress and restored.hero_skill_tree == tree, "new Main preserves hero levels, residual XP and spent tree points")
	_check(restored.hero_equipment["leonhardt"]["weapon"] == 6 and restored.hero_equipment_rarity["leonhardt"]["weapon"] == "전설" and restored.hero_equipment_sets["leonhardt"]["weapon"] == "월광" and restored.hero_equipment_names["leonhardt"]["weapon"] == "영속 검증검", "equipped item level, rarity, set and name survive reload")
	var displaced_preserved: bool = restored.loot_inventory.size() == inventory.size() and inventory.size() == 1
	if displaced_preserved:
		# The loader may add a missing optional zone string; every existing field
		# including ID, computed power and enhancement must retain its value.
		for key in inventory[0]:
			displaced_preserved = displaced_preserved and restored.loot_inventory[0].get(key) == inventory[0][key]
	_check(displaced_preserved and int(restored.loot_inventory[0]["level"]) == 1, "displaced item survives once with every existing field, ID and enhancement")
	await _dispose(restored)

func _world_roundtrip() -> void:
	var path := fixture_root.path_join("world.json")
	var main = await _new_main(path)
	_party(main)
	_bind_world(main)
	var origin: Vector2i = main.faction_war_state.army_position
	var ally := {"force_id": "integration_ally", "faction": main.selected_faction, "power": 500, "squad": [{"id": "integration_guard", "name": "수비대", "max_hp": 500, "hp": 321, "attack": 50, "defense": 10}]}
	var garrison_ok: bool = main.faction_conflict_state.add_garrison(main.faction_war_state, supply, origin, ally)
	var march := _submit(main, _command(main, "march", Vector2i(4, 10)))
	_check(garrison_ok and bool(march.get("accepted", false)), "allied garrison and player march start through the integrated world")
	var paid_rations: int = main.faction_war_state.rations
	var contribution: int = main.faction_conflict_state.contribution_points
	var saved_route: Array[Vector2i] = main.faction_march_state.path.duplicate()
	main._save_idle_state()
	await _dispose(main)
	var restored = await _new_main(path)
	_bind_world(restored)
	_check(restored.faction_march_state.active and restored.faction_march_state.target == Vector2i(4, 10) and restored.faction_march_state.path == saved_route and restored.faction_war_state.rations == paid_rations, "new Main preserves active march route and already-paid rations")
	var guards: Array = restored.faction_conflict_state.garrisons_at(origin)
	_check(guards.size() == 1 and guards[0]["force_id"] == "integration_ally" and int(guards[0]["squad"][0]["hp"]) == 321 and restored.faction_conflict_state.contribution_points == contribution, "garrison identity, wounds and awarded contribution survive reload")
	restored.faction_conflict_state.add_garrison(restored.faction_war_state, supply, origin, ally)
	_check(restored.faction_conflict_state.contribution_points == contribution, "re-registering restored garrison cannot award contribution twice")
	restored.world_authority.server_time_offset_seconds += restored.faction_march_state.remaining_seconds() + 1.0
	var arrival: Dictionary = restored.world_authority.catch_up_march(restored.faction_war_state, restored.faction_march_state, restored.faction_conflict_state, supply, WorldBattleResolver.new(), "local_player")
	_check(bool(arrival.get("accepted", false)) and not restored.faction_march_state.active and restored.faction_war_state.tile_owner(Vector2i(4, 10)) == restored.selected_faction, "restored march completes and captures its neutral target")
	var now: int = restored.world_authority.server_now()
	restored.world_season_state.record_capture(restored.selected_faction, "fort", "local_player", true, now)
	restored.world_season_state.active_end_unix = now - 1
	restored.world_season_state.settlement_end_unix = now + 100
	var claim := _command(restored, "claim_season_reward")
	_check(bool(_submit(restored, claim).get("accepted", false)), "season contribution produces an actual settlement reward")
	var honor: int = restored.faction_war_state.campaign_honor
	var reward_rations: int = restored.faction_war_state.rations
	var captures: int = restored.faction_war_state.captured_count
	restored._save_idle_state()
	await _dispose(restored)
	var claimed = await _new_main(path)
	_bind_world(claimed)
	_check(claimed.world_season_state.reward_claims.has("local_player") and claimed.faction_war_state.campaign_honor == honor and claimed.faction_war_state.rations == reward_rations, "season receipt and its exact credited resources persist together")
	var repeated := _submit(claimed, claim)
	var second_claim := _submit(claimed, _command(claimed, "claim_season_reward"))
	_check(bool(repeated.get("duplicate", false)) and not bool(second_claim.get("accepted", false)) and claimed.faction_war_state.campaign_honor == honor and claimed.faction_war_state.rations == reward_rations and claimed.faction_war_state.captured_count == captures, "same-ID replay and fresh-ID re-claim cannot duplicate a persisted season award")
	await _dispose(claimed)

func _offline_roundtrip() -> void:
	var path := fixture_root.path_join("offline.json")
	var main = await _new_main(path)
	_party(main)
	main.last_idle_timestamp = int(Time.get_unix_time_from_system()) - 60
	main._offline_checked = false
	main._calculate_offline_reward()
	var reward_gold: int = main.unclaimed_gold
	var reward_xp: int = main.unclaimed_xp
	var receipt_time: int = main.last_idle_timestamp
	_check(reward_gold > 0 and reward_xp > 0 and main.offline_reward_seconds >= 60 and main.last_save_status == "saved", "offline estimate grants resources and commits the consumed time interval")
	var stored: Dictionary = main.save_store.read_save(path)["data"]
	_check(int(stored["last_idle_timestamp"]) == receipt_time and int(stored["unclaimed_gold"]) == reward_gold and int(stored["unclaimed_xp"]) == reward_xp, "offline receipt time and pending rewards are in the same committed file")
	main._calculate_offline_reward()
	_check(main.unclaimed_gold == reward_gold and main.unclaimed_xp == reward_xp, "repeated same-session offline callback is idempotent")
	await _dispose(main)
	var restored = await _new_main(path, true)
	_check(restored.unclaimed_gold == reward_gold and restored.unclaimed_xp == reward_xp and restored.last_idle_timestamp == receipt_time, "fresh process state restores the committed rewards and consumed timestamp")
	restored.allow_offline = true
	restored._offline_checked = false
	restored._calculate_offline_reward()
	# A very slow CI run can legitimately earn a fresh five-second interval.
	# It must never replay the prior sixty seconds; repeated callbacks then hold.
	var resumed_gold: int = restored.unclaimed_gold
	var resumed_xp: int = restored.unclaimed_xp
	var elapsed_since_receipt := maxi(0, int(Time.get_unix_time_from_system()) - receipt_time)
	var only_new_time: bool = restored.offline_reward_seconds <= elapsed_since_receipt and restored.offline_reward_seconds < 60
	restored._calculate_offline_reward()
	_check(only_new_time and restored.unclaimed_gold == resumed_gold and restored.unclaimed_xp == resumed_xp, "restart processes only newly elapsed time and cannot replay the consumed sixty-second reward")
	await _dispose(restored)

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(fixture_root))
	await _growth_roundtrip()
	await _world_roundtrip()
	await _offline_roundtrip()
	var directory := DirAccess.open(fixture_root)
	if directory != null:
		for file in directory.get_files():
			directory.remove(file)
		DirAccess.remove_absolute(ProjectSettings.globalize_path(fixture_root))
	if not failures.is_empty():
		push_error("v27_persistence_integration_smoke_test_failed checks=%d failures=%d: %s" % [checks, failures.size(), "; ".join(failures)])
		quit(1)
		return
	print("v27_persistence_integration_smoke_test_ok checks=%d growth=preserved equipment=preserved march=restored garrison=restored season=once offline=once" % checks)
	quit(0)
