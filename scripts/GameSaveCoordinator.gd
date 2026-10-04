extends RefCounted

## v83: GameSaveCoordinator. Main remains the single owner of mutable game state.
## The injected host supplies state, virtual UI hooks and runtime refreshes.
## No cached host reference, duplicate wallet, RNG or save schema is introduced.

static func snapshot(main: Node) -> Dictionary:
	if bool(main.get_meta("practice_active", false)): return {}
	if main._save_blocked_for_newer_version:
		main.last_save_status = "unsupported_version"
		return {}
	main.GOALS.refresh(main)
	main._sanitize_deployed_party_for_faction()
	main._stash_active_faction_presets()
	main._stash_active_faction_world()
	var save_timestamp = maxi(main.last_idle_timestamp, int(Time.get_unix_time_from_system()))
	var data = {
		"save_version": SaveStore.VERSION,
		"battle_speed": main.battle_speed,
		"formation_id": main.formation_id,
		"hunt_productivity": main.hunt_productivity,
		"offline_reward_basis": main.offline_reward_basis,
		"skill_auto": main.skill_auto,
		"ultimate_auto": main.ultimate_auto,
		"offline_pending_gold": main.offline_pending_gold,
		"offline_pending_xp": main.offline_pending_xp,
		"offline_pending_chest_gold": main.offline_pending_chest_gold,
		"offline_pending_chest_xp": main.offline_pending_chest_xp,
		"combat_presets": main.combat_presets,
		"party_presets": main.party_presets,
		"faction_party_presets": main.faction_party_presets,
		"pet_progress": main.pet_progress,
		"guardian_collection": main.guardian_collection,
		"guardian_equipped": main.guardian_equipped,
		"guardian_legendary_pity": main.guardian_legendary_pity,
		"guardian_mythic_pity": main.guardian_mythic_pity,
		"guardian_free_claimed": main.guardian_free_claimed,
		"hero_skill_tree": main.hero_skill_tree,
		"active_preset_index": main.active_preset_index,
		"unclaimed_gold": main.unclaimed_gold,
		"unclaimed_xp": main.unclaimed_xp,
		"wallet_gold": main.wallet_gold,
		"wallet_xp": main.wallet_xp,
		"wallet_gems": main.wallet_gems,
		"idle_stage": main.idle_stage,
		"idle_stage_kills": main.idle_stage_kills,
		"idle_chest_gold": main.idle_chest_gold,
		"idle_chest_xp": main.idle_chest_xp,
		"last_idle_timestamp": save_timestamp,
		"selected_faction": main.selected_faction,
		"deployed_hero_ids": main._deployed_hero_ids(),
		"current_zone_id": main.current_zone_id,
		"hero_progress": main.hero_progress,
		"hero_equipment": main.hero_equipment,
		"hero_equipment_rarity": main.hero_equipment_rarity,
		"hero_equipment_names": main.hero_equipment_names,
		"loot_inventory": main.loot_inventory,
		"raid_clears": main.raid_clears,
		"daily_reward_claimed_day": main.daily_reward_claimed_day,
		"rewarded_ad_claimed_count": main.rewarded_ad_claimed_count,
		"rewarded_ad_day": main.rewarded_ad_day,
		"hero_shards": main.hero_shards,
		"hero_breakthrough": main.hero_breakthrough,
		"quest_claimed": main.quest_claimed,
		"long_term_goals": main.long_term_goals,
		"tower_floor": main.tower_floor,
		"tower_best_floor": main.tower_best_floor,
		"daily_dungeon_runs": main.daily_dungeon_runs,
		"daily_dungeon_day": main.daily_dungeon_day,
		"daily_dungeon_clears": main.daily_dungeon_clears,
		"codex_seen": main.codex_seen,
		"auto_salvage_min_rarity": main.auto_salvage_min_rarity,
		"summon_pity": main.summon_pity,
		"hero_ascension": main.hero_ascension,
		"hero_equipment_sets": main.hero_equipment_sets,
		"hero_equipment_items": main.hero_equipment_items,
		"equipment_overflow": main.equipment_overflow,
		"raid_crystals": main.raid_crystals,
		"gear_auto_equip": main.gear_auto_equip,
		"gear_market_state": main.gear_market_state,
		"weekly_content_key": main.weekly_content_key,
		"weekly_trial_runs": main.weekly_trial_runs,
		"weekly_trial_best": main.weekly_trial_best,
		"weekly_trial_score_version": 1,
		"weekly_trial_legacy_best": main.weekly_trial_legacy_best,
		"weekly_trial_legacy_week": main.weekly_trial_legacy_week,
		"tracked_quest_id": main.tracked_quest_id,
		"tutorial_step": main.tutorial_step,
		"tutorial_completed": main.tutorial_completed,
		"tutorial_actions": main.tutorial_actions.duplicate(true),
		"party_slot_legacy_cap": main.party_slot_legacy_cap,
		"faction_war": main.faction_war_state.export_state(),
		"faction_march": main.faction_march_state.export_state(),
		"faction_conflict": main.faction_conflict_state.export_state(),
		"faction_world_snapshots": main.faction_world_snapshots,
		"world_season": main.world_season_state.export_state(),
		"world_authority": main.world_authority.export_state(),
		"world_server_gateway": main.world_server_gateway.export_state()
	}
	return data

static func save_idle_state(main: Node) -> void:
	var data := snapshot(main)
	if data.is_empty(): return
	main.set_meta("game_save_pending", true)
	var result = main.save_store.write_save(main.save_state_path, data)
	accept_result(main, result, int(data["last_idle_timestamp"]))

static func accept_result(main: Node, result: Dictionary, save_timestamp: int) -> void:
	main.last_save_status = str(result.get("status", "save_failed"))
	preload("res://scripts/SaveSafety.gd").observe(main)
	if bool(result.get("ok", false)):
		main.last_idle_timestamp = maxi(main.last_idle_timestamp, save_timestamp)
		main.goals_save_pending = false
		if main._save_issue_notified and not main.active_screen.is_empty():
			main._show_toast("원정대 기록이 다시 정상적으로 저장됐어요.")
		main._save_issue_notified = false
	elif bool(result.get("unsupported", false)):
		main._save_blocked_for_newer_version = true
		main.save_load_status = "unsupported_version"
		if not main._save_issue_notified and not main.active_screen.is_empty():
			main._show_toast("더 최신 버전의 저장 기록이에요. 게임을 업데이트해 주세요.")
		main._save_issue_notified = true
	else:
		push_warning("사냥 상태를 저장하지 못했습니다: %s" % main.last_save_status)
		if not main._save_issue_notified and not main.active_screen.is_empty():
			main._show_toast("원정대 기록 저장에 실패했어요. 기기 저장 공간을 확인하고 다시 시도해 주세요.")
		main._save_issue_notified = true


static func load_idle_state(main: Node) -> void:
	if main.goals_save_pending or preload("res://scripts/SaveSafety.gd").pending(main) or bool(main.get_meta("practice_active", false)):
		main.save_load_status = "goals_save_pending"
		return
	main._offline_checked = false
	var result = main.save_store.read_save(main.save_state_path)
	main._save_blocked_for_newer_version = bool(result.get("unsupported", false))
	main.save_load_status = str(result.get("source", result.get("status", "load_failed")))
	if not bool(result.get("ok", false)):
		main.last_idle_timestamp = int(Time.get_unix_time_from_system())
		return
	var parsed = SaveValidation.sanitize(result["data"], main._zone_data().keys(), main.idle_stage_target)
	var loaded_save_version = int(parsed.get("save_version", 1))
	main.long_term_goals = parsed.get("long_term_goals", {}).duplicate(true)
	main.hunt_productivity = parsed.get("hunt_productivity", {}).duplicate(true)
	main.offline_reward_basis = str(parsed.get("offline_reward_basis", ""))
	main.party_slot_legacy_cap = clampi(int(parsed.get("party_slot_legacy_cap", 0)), 0, main.PARTY_CAP)
	main.unclaimed_gold = maxi(0, int(parsed.get("unclaimed_gold", 0)))
	main.unclaimed_xp = maxi(0, int(parsed.get("unclaimed_xp", 0)))
	main.wallet_gold = int(parsed.get("wallet_gold", 0))
	main.wallet_xp = int(parsed.get("wallet_xp", 0))
	main.wallet_gems = int(parsed.get("wallet_gems", 0))
	main.idle_stage = int(parsed.get("idle_stage", 1))
	main.idle_stage_kills = int(parsed.get("idle_stage_kills", 0))
	main.idle_chest_gold = int(parsed.get("idle_chest_gold", 0))
	main.idle_chest_xp = int(parsed.get("idle_chest_xp", 0))
	main.offline_pending_gold = mini(main.unclaimed_gold,int(parsed.get("offline_pending_gold",0)))
	main.offline_pending_xp = mini(main.unclaimed_xp,int(parsed.get("offline_pending_xp",0)))
	main.offline_pending_chest_gold = mini(main.idle_chest_gold,int(parsed.get("offline_pending_chest_gold",0)))
	main.offline_pending_chest_xp = mini(main.idle_chest_xp,int(parsed.get("offline_pending_chest_xp",0)))
	main.last_idle_timestamp = int(parsed.get("last_idle_timestamp", Time.get_unix_time_from_system()))
	main.selected_faction = str(parsed.get("selected_faction", ""))
	var loaded_speed = clampf(float(parsed.get("battle_speed", 1.0)), 1.0, 2.0)
	main.battle_speed = 2.0 if loaded_speed >= 1.5 else 1.0
	main.formation_id = str(parsed.get("formation_id", "balanced"))
	main.skill_auto = bool(parsed.get("skill_auto",true))
	main.ultimate_auto = bool(parsed.get("ultimate_auto",true))
	main.active_preset_index = clampi(int(parsed.get("active_preset_index", -1)), -1, 2)
	main.combat_presets = parsed.get("combat_presets", {}).duplicate(true)
	main.party_presets = [[], [], []]
	var saved_presets = parsed.get("party_presets", [])
	if typeof(saved_presets) == TYPE_ARRAY:
		for preset_index in range(mini(3, saved_presets.size())):
			if typeof(saved_presets[preset_index]) == TYPE_ARRAY:
				main.party_presets[preset_index] = saved_presets[preset_index]
	var saved_faction_presets = parsed.get("faction_party_presets", {})
	if typeof(saved_faction_presets) == TYPE_DICTIONARY:
		main.faction_party_presets = saved_faction_presets.duplicate(true)
	var has_scoped_preset = false
	for faction_id in ["aurelia", "noxfera"]:
		var bank = main.faction_party_presets.get(faction_id, [])
		if typeof(bank) == TYPE_ARRAY:
			for preset in bank:
				if typeof(preset) == TYPE_ARRAY and not preset.is_empty():
					has_scoped_preset = true
	if not has_scoped_preset and main.selected_faction in ["aurelia", "noxfera"]:
		# Legacy saves had one preset bank. Migrate it only to the faction that owned that save.
		main.faction_party_presets[main.selected_faction] = main.party_presets.duplicate(true)
	main._load_active_faction_presets()
	var saved_pet_progress = parsed.get("pet_progress", {})
	if typeof(saved_pet_progress) == TYPE_DICTIONARY:
		main.pet_progress = saved_pet_progress
	main.guardian_collection = parsed.get("guardian_collection", {}).duplicate(true)
	main.guardian_equipped = str(parsed.get("guardian_equipped", ""))
	main.guardian_legendary_pity = int(parsed.get("guardian_legendary_pity", 0))
	main.guardian_mythic_pity = int(parsed.get("guardian_mythic_pity", 0))
	main.guardian_free_claimed = bool(parsed.get("guardian_free_claimed", false))
	main._guardian_ensure_starter()
	var saved_skill_tree = parsed.get("hero_skill_tree", {})
	if typeof(saved_skill_tree) == TYPE_DICTIONARY:
		main.hero_skill_tree = saved_skill_tree
	main.current_zone_id = str(parsed.get("current_zone_id", "gray_meadow"))
	var saved_hero_progress = parsed.get("hero_progress", {})
	if typeof(saved_hero_progress) == TYPE_DICTIONARY:
		main.hero_progress = saved_hero_progress
	var saved_hero_equipment = parsed.get("hero_equipment", {})
	if typeof(saved_hero_equipment) == TYPE_DICTIONARY:
		main.hero_equipment = saved_hero_equipment
	var saved_hero_equipment_rarity = parsed.get("hero_equipment_rarity", {})
	if typeof(saved_hero_equipment_rarity) == TYPE_DICTIONARY:
		main.hero_equipment_rarity = saved_hero_equipment_rarity
	var saved_hero_equipment_names = parsed.get("hero_equipment_names", {})
	if typeof(saved_hero_equipment_names) == TYPE_DICTIONARY:
		main.hero_equipment_names = saved_hero_equipment_names
	var saved_loot_inventory = parsed.get("loot_inventory", [])
	if typeof(saved_loot_inventory) == TYPE_ARRAY:
		main.loot_inventory = saved_loot_inventory
	main.hero_equipment_items = parsed.get("hero_equipment_items", {}).duplicate(true)
	main.equipment_overflow = parsed.get("equipment_overflow", []).duplicate(true)
	main.raid_crystals = int(parsed.get("raid_crystals", 0))
	main.gear_auto_equip = bool(parsed.get("gear_auto_equip", true))
	main.gear_market_state = parsed.get("gear_market_state", {}).duplicate(true)
	main._gear_market_loaded = false
	var saved_raid_clears = parsed.get("raid_clears", {})
	if typeof(saved_raid_clears) == TYPE_DICTIONARY:
		main.raid_clears = saved_raid_clears
	main.daily_reward_claimed_day = str(parsed.get("daily_reward_claimed_day", ""))
	main.rewarded_ad_claimed_count = int(parsed.get("rewarded_ad_claimed_count", 0))
	main.rewarded_ad_day = str(parsed.get("rewarded_ad_day", ""))
	var saved_shards = parsed.get("hero_shards", {})
	if typeof(saved_shards) == TYPE_DICTIONARY:
		main.hero_shards = saved_shards
	var saved_breakthrough = parsed.get("hero_breakthrough", {})
	if typeof(saved_breakthrough) == TYPE_DICTIONARY:
		main.hero_breakthrough = saved_breakthrough
	var saved_quests = parsed.get("quest_claimed", {})
	if typeof(saved_quests) == TYPE_DICTIONARY:
		main.quest_claimed = saved_quests
	main.tower_floor = maxi(1, int(parsed.get("tower_floor", 1)))
	main.tower_best_floor = maxi(0, int(parsed.get("tower_best_floor", 0)))
	main.daily_dungeon_runs = maxi(0, int(parsed.get("daily_dungeon_runs", 0)))
	main.daily_dungeon_day = str(parsed.get("daily_dungeon_day", ""))
	main.daily_dungeon_clears = parsed.get("daily_dungeon_clears", {}).duplicate(true)
	var saved_codex = parsed.get("codex_seen", {})
	if typeof(saved_codex) == TYPE_DICTIONARY:
		main.codex_seen = saved_codex
	main.auto_salvage_min_rarity = str(parsed.get("auto_salvage_min_rarity", "일반"))
	var salvage_migration = {"common":"일반", "uncommon":"희귀", "rare":"희귀", "epic":"전설"}
	main.auto_salvage_min_rarity = str(salvage_migration.get(main.auto_salvage_min_rarity, main.auto_salvage_min_rarity))
	main.summon_pity = maxi(0, int(parsed.get("summon_pity", 0)))
	var saved_ascension = parsed.get("hero_ascension", {})
	if typeof(saved_ascension) == TYPE_DICTIONARY:
		main.hero_ascension = saved_ascension
	var saved_equipment_sets = parsed.get("hero_equipment_sets", {})
	if typeof(saved_equipment_sets) == TYPE_DICTIONARY:
		main.hero_equipment_sets = saved_equipment_sets
	main.weekly_content_key = str(parsed.get("weekly_content_key", ""))
	main.weekly_trial_runs = maxi(0, int(parsed.get("weekly_trial_runs", 0)))
	main.weekly_trial_best = maxi(0, int(parsed.get("weekly_trial_best", 0)))
	main.weekly_trial_legacy_best = maxi(0, int(parsed.get("weekly_trial_legacy_best", 0)))
	main.weekly_trial_legacy_week = str(parsed.get("weekly_trial_legacy_week", ""))
	main.tracked_quest_id = str(parsed.get("tracked_quest_id", ""))
	main.tutorial_step = clampi(int(parsed.get("tutorial_step", 0)), 0, 6)
	main.tutorial_completed = bool(parsed.get("tutorial_completed", false))
	main.tutorial_actions = preload("res://scripts/FirstSessionGuide.gd").restore(main,result["data"])
	var saved_faction_world = parsed.get("faction_world_snapshots", {})
	if typeof(saved_faction_world) == TYPE_DICTIONARY and not saved_faction_world.is_empty():
		main.faction_world_snapshots = saved_faction_world.duplicate(true)
	elif main.selected_faction in ["aurelia", "noxfera"]:
		# Legacy saves stored one war context. Attach it only to the selected faction.
		main.faction_world_snapshots[main.selected_faction] = {
			"war": parsed.get("faction_war", {}),
			"march": parsed.get("faction_march", {}),
			"conflict": parsed.get("faction_conflict", {})
		}
	var saved_world_season = parsed.get("world_season", {})
	if typeof(saved_world_season) == TYPE_DICTIONARY:
		main.world_season_state.import_state(saved_world_season)
	# Older saves have no per-faction season tag. Assign the saved global season
	# now, before a future transition, without discarding existing progress.
	for faction_id in ["aurelia", "noxfera"]:
		var bank = main.faction_world_snapshots.get(faction_id, {})
		if typeof(bank) == TYPE_DICTIONARY and not bank.has("season_number"):
			bank["season_number"] = main.world_season_state.season_number
			main.faction_world_snapshots[faction_id] = bank
	main._load_active_faction_world()
	var saved_world_authority = parsed.get("world_authority", {})
	if typeof(saved_world_authority) == TYPE_DICTIONARY:
		main.world_authority.import_state(saved_world_authority)
	var saved_world_server_gateway = parsed.get("world_server_gateway", {})
	if typeof(saved_world_server_gateway) == TYPE_DICTIONARY:
		main.world_server_gateway.import_state(saved_world_server_gateway)
	main._reset_weekly_if_needed()
	main._auto_track_quest()
	main.deployed_heroes.clear()
	var saved_deployed_ids = parsed.get("deployed_hero_ids", [])
	if typeof(saved_deployed_ids) == TYPE_ARRAY and not saved_deployed_ids.is_empty():
		if loaded_save_version < 17:
			main.party_slot_legacy_cap = maxi(main.party_slot_legacy_cap, main._clean_party_ids_for_faction(saved_deployed_ids, main.selected_faction).size())
		main._restore_deployed_heroes(saved_deployed_ids)
	elif loaded_save_version < 17 and main.selected_faction in ["aurelia", "noxfera"]:
		# v4 saves did not persist party composition. Migrate them to the three
		# stage-1 starters so offline hero XP is not silently lost after upgrade.
		var starter_ids: Array[String] = []
		for hero in main._hero_roster_for_faction().slice(0, 3):
			starter_ids.append(str(hero["id"]))
		# Preserve legacy capacity before restoration applies the current slot cap.
		main.party_slot_legacy_cap = maxi(main.party_slot_legacy_cap, starter_ids.size())
		main._restore_deployed_heroes(starter_ids)
	if loaded_save_version < 17:
		main.party_slot_legacy_cap = maxi(main.party_slot_legacy_cap, main.deployed_heroes.size())
	else:
		var allowed_party: Array = []
		for hero in main.deployed_heroes:
			if main.party_slot_legacy_cap > 0 or main.idle_stage >= int(hero.get("unlock_stage", 1)):
				allowed_party.append(hero)
		main.deployed_heroes = allowed_party.slice(0, main._party_slot_cap())
	main._sanitize_deployed_party_for_faction()
	if not main._is_zone_unlocked(main.current_zone_id):
		main.current_zone_id = "gray_meadow"
