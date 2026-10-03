extends RefCounted
## Shared real combat, read-only progression, no victory receipts/allowances.
const SESSION = preload("res://scripts/ChallengeBattleSession.gd")
const DAILY = preload("res://scripts/DailyDungeonBattleRules.gd")
const TOWER = preload("res://scripts/TowerBattleRules.gd")
const ABYSS = preload("res://scripts/WeeklyAbyssBattleRules.gd")
const SAFETY = preload("res://scripts/SaveSafety.gd")
const RUNTIME_FIELDS: Array[String] = ["party_power", "party_hp", "party_max_hp", "hero_battle_state", "hero_skill_runtime", "pet_runtime"]
const SNAPSHOT_FIELDS: Array[String] = ["formation_id", "battle_speed", "skill_auto", "ultimate_auto", "hunt_productivity", "offline_reward_basis", "offline_pending_gold", "offline_pending_xp", "offline_pending_chest_gold", "offline_pending_chest_xp", "combat_presets", "party_presets", "faction_party_presets", "pet_progress", "guardian_collection", "guardian_equipped", "guardian_legendary_pity", "guardian_mythic_pity", "guardian_free_claimed", "hero_skill_tree", "active_preset_index", "unclaimed_gold", "unclaimed_xp", "wallet_gold", "wallet_xp", "wallet_gems", "idle_stage", "idle_stage_kills", "idle_chest_gold", "idle_chest_xp", "selected_faction", "current_zone_id", "hero_progress", "hero_equipment", "hero_equipment_rarity", "hero_equipment_names", "loot_inventory", "raid_clears", "daily_reward_claimed_day", "rewarded_ad_claimed_count", "rewarded_ad_day", "hero_shards", "hero_breakthrough", "quest_claimed", "long_term_goals", "tower_floor", "tower_best_floor", "daily_dungeon_runs", "daily_dungeon_day", "daily_dungeon_clears", "codex_seen", "auto_salvage_min_rarity", "summon_pity", "hero_ascension", "hero_equipment_sets", "hero_equipment_items", "equipment_overflow", "raid_crystals", "gear_auto_equip", "gear_market_state", "weekly_content_key", "weekly_trial_runs", "weekly_trial_best", "weekly_trial_legacy_best", "weekly_trial_legacy_week", "tracked_quest_id", "tutorial_step", "tutorial_completed", "party_slot_legacy_cap", "faction_world_snapshots", "last_idle_timestamp"]

static func context(main: Node) -> Dictionary:
	return {"faction": str(main.selected_faction), "zone": str(main.current_zone_id),
		"hero_ids": main._deployed_hero_ids().duplicate(), "week": str(main._week_key()),
		"screen": main.content_root.get_instance_id(), "config": main.PRESETS.fingerprint(main, 0),
		"progress": main.hero_progress.duplicate(true), "research": main.hero_skill_tree.duplicate(true)}

static func start(main: Node, mode: String, difficulty: int, variant: String, expected: Dictionary = {}, level_mode: String = "actual", match_level: int = 1) -> bool:
	if main.challenge_session != null or main.raid_running or main._save_blocked_for_newer_version or SAFETY.pending(main):
		main._show_toast("진행 중인 전투 또는 저장 대기를 먼저 마쳐 주세요."); return false
	if str(main.selected_faction) not in ["aurelia", "noxfera"] or main.deployed_heroes.is_empty(): return false
	if not expected.is_empty() and context(main) != expected:
		main._show_toast("편성·기간·화면이 바뀌었어요. 연습실에서 다시 선택하세요."); return false
	var levels: Dictionary = preload("res://scripts/PracticeLevelRules.gd").plan(main, level_mode, match_level)
	if levels.is_empty():
		main._show_toast("합류한 같은 진영 영웅과 허용 레벨을 확인하세요."); return false
	var plan: Dictionary = {}
	var entry: Dictionary = {"faction": str(main.selected_faction), "zone": str(main.current_zone_id),
		"hero_ids": main._deployed_hero_ids().duplicate(), "run_index": difficulty - 1, "floor": difficulty,
		"week": str(main._week_key()), "battle_speed": float(main.battle_speed),
		"level_mode": levels["mode"], "match_level": levels["level"], "actual_levels": levels["actual_levels"].duplicate(true)}
	match mode:
		"daily":
			if difficulty < 1 or difficulty > 3 or variant not in DAILY.VARIANTS: return false
			plan = DAILY.plan(variant)
		"tower":
			if not TOWER.valid_floor(difficulty) or difficulty > int(main.tower_floor): return false
			plan = TOWER.plan(difficulty)
		"weekly": plan = ABYSS.plan(str(entry["week"]))
		_: return false
	if plan.is_empty(): return false
	# Persist the pre-practice baseline once. Refuse to begin on write failure.
	main._save_idle_state()
	if str(main.last_save_status) != "saved": SAFETY.observe(main); return false
	var snapshot: Dictionary = {}
	for field: String in SNAPSHOT_FIELDS:
		var value: Variant = main.get(field)
		snapshot[field] = value.duplicate(true) if typeof(value) in [TYPE_DICTIONARY, TYPE_ARRAY] else value
	main.set_meta("practice_snapshot", snapshot)
	var runtime: Dictionary = {}
	for field: String in RUNTIME_FIELDS:
		var value: Variant = main.get(field)
		runtime[field] = value.duplicate(true) if typeof(value) in [TYPE_DICTIONARY, TYPE_ARRAY] else value
	main.set_meta("practice_runtime", runtime)
	main.set_meta("practice_party", main.deployed_heroes.duplicate(true))
	main.set_meta("practice_rng", [main.loot_rng.seed, main.loot_rng.state, main.roaming_hunt.rng.seed, main.roaming_hunt.rng.state])
	main.set_meta("practice_active", true)
	main.set_meta("practice_level_override", levels.duplicate(true))
	main._build_combat_screen()
	# Repeatable scenario sampling, not a guarantee of bitwise deterministic AI.
	main.loot_rng.seed = 830300 + difficulty
	main.roaming_hunt.rng.seed = 830300 + difficulty
	main.challenge_serial += 1
	plan["practice"] = true
	plan["title"] = ("[연습 Lv.%d] " % int(levels["level"]) if level_mode == "matched" else "[연습] ") + str(plan["title"])
	var session: ChallengeBattleSession = SESSION.new()
	if not session.begin(int(main.challenge_serial), plan, entry):
		restore(main); main._open_practice_screen(); return false
	main.challenge_session = session
	session.combat_ledger.begin(main.deployed_heroes, main.hero_battle_state, main.skill_auto, main.ultimate_auto)
	main.hunt_combo = 0; main.hunt_combo_remaining = 0.0; main.hunt_variety_profile = {}
	main.hunt_event_text = session.title + " · 보상·횟수·미션 미반영"
	main.CHALLENGE_DRIVER.spawn_wave(main)
	main._update_hunt_hud()
	return session.is_running()

static func matches(main: Node, session: ChallengeBattleSession) -> bool:
	return (bool(main.get_meta("practice_active", false)) and session.serial == int(main.challenge_serial)
		and session.entry_context.get("faction", "") == str(main.selected_faction)
		and session.entry_context.get("zone", "") == str(main.current_zone_id)
		and session.entry_context.get("hero_ids", []) == main._deployed_hero_ids())

static func restore(main: Node) -> void:
	if not bool(main.get_meta("practice_active", false)): return
	var snapshot: Dictionary = main.get_meta("practice_snapshot", {})
	for field: String in SNAPSHOT_FIELDS:
		if snapshot.has(field): main.set(field, snapshot[field])
	main.deployed_heroes = main.get_meta("practice_party", []).duplicate(true)
	var rng: Array = main.get_meta("practice_rng", [])
	if rng.size() == 4:
		main.loot_rng.seed = int(rng[0]); main.loot_rng.state = int(rng[1])
		main.roaming_hunt.rng.seed = int(rng[2]); main.roaming_hunt.rng.state = int(rng[3])
	main.set_meta("practice_active", false)
	# Restore the old runtime directly. A generic growth refresh lazily creates
	# pet progression and would violate the no-progression-change contract.
	var runtime: Dictionary = main.get_meta("practice_runtime", {})
	for field: String in RUNTIME_FIELDS:
		if runtime.has(field): main.set(field, runtime[field])
	for key: String in ["practice_snapshot", "practice_party", "practice_rng", "practice_level_override", "practice_runtime"]: main.remove_meta(key)

static func finish(main: Node, session: ChallengeBattleSession) -> void:
	if session == null or not session.practice or main.challenge_session != session or session.is_running(): return
	main.combat_running = false
	main.challenge_session = null
	restore(main)
	main.set_meta("last_practice_result", {"title": session.title, "serial": session.serial,
		"reason": session.reason, "elapsed": session.elapsed, "damage": session.damage_score})
	main._open_practice_screen()
	main._show_toast("연습 종료 · 전투 기록만 생성 · 보상·횟수·미션 변경 없음")
