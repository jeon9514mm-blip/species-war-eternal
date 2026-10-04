extends RefCounted

const SESSION = preload("res://scripts/ChallengeBattleSession.gd")
const DAILY = preload("res://scripts/DailyDungeonBattleRules.gd")
const PROGRESS = preload("res://scripts/DailyDungeonProgress.gd")
const TOWER = preload("res://scripts/TowerBattleRules.gd")
const TOWER_PROGRESS = preload("res://scripts/TowerProgressionService.gd")
const ABYSS = preload("res://scripts/WeeklyAbyssBattleRules.gd")
const ABYSS_PROGRESS = preload("res://scripts/WeeklyAbyssProgressionService.gd")
const PATTERN_RULES = preload("res://scripts/ChallengePatternRules.gd")
const PATTERN_RUNTIME = preload("res://scripts/ChallengePatternRuntime.gd")
const ECOLOGY = preload("res://scripts/FieldEcology.gd")

static func entry_context(main: Node) -> Dictionary:
	return {"day": str(main.daily_dungeon_day), "run_index": int(main.daily_dungeon_runs),
		"faction": str(main.selected_faction), "zone": str(main.current_zone_id),
		"hero_ids": main._deployed_hero_ids().duplicate()}

static func _entry_error(main: Node, variant: String) -> String:
	var save_error: String = preload("res://scripts/SaveSafety.gd").entry_error(main)
	if not save_error.is_empty(): return save_error
	if variant not in DAILY.VARIANTS:
		return "알 수 없는 일일 던전입니다."
	if main.challenge_session != null:
		return "진행 중인 원정을 먼저 마쳐 주세요."
	if main._save_blocked_for_newer_version:
		return "최신 버전의 저장 기록을 먼저 확인해 주세요."
	if str(main._today_key()) != str(main.daily_dungeon_day):
		return "날짜가 변경되었거나 기기 시계가 이전 날짜로 설정되어 있어요."
	if main.daily_dungeon_runs < 0 or main.daily_dungeon_runs >= DAILY.DAILY_LIMIT:
		return "오늘의 일일 원정 3회를 모두 완료했어요."
	if str(main.selected_faction) not in PROGRESS.FACTIONS or main.deployed_heroes.is_empty():
		return "먼저 진영과 원정대를 편성하세요."
	return ""

static func _context_matches(main: Node, expected: Dictionary) -> bool:
	# Check real current day too: a midnight rollover need not have opened a menu.
	return (str(main._today_key()) == str(expected.get("day", ""))
		and str(main.daily_dungeon_day) == str(expected.get("day", ""))
		and int(main.daily_dungeon_runs) == int(expected.get("run_index", -1))
		and str(main.selected_faction) == str(expected.get("faction", ""))
		and str(main.current_zone_id) == str(expected.get("zone", ""))
		and main._deployed_hero_ids() == expected.get("hero_ids", []))

static func start_daily(main: Node, variant: String = "gold_rush") -> bool:
	if preload("res://scripts/SaveSafety.gd").pending(main):
		main._show_toast(preload("res://scripts/SaveSafety.gd").entry_error(main)); return false
	if main.challenge_session != null:
		return false
	# Reject protected saves and unknown requests before changing quota/party.
	if main._save_blocked_for_newer_version:
		main._show_toast("최신 버전의 저장 기록을 먼저 확인해 주세요.")
		return false
	if variant not in DAILY.VARIANTS:
		main._show_toast("알 수 없는 일일 던전입니다.")
		return false
	main._reset_daily_dungeon_if_needed()
	main._sanitize_deployed_party_for_faction()
	var error: String = _entry_error(main, variant)
	if not error.is_empty():
		main._show_toast(error)
		return false
	var entry: Dictionary = entry_context(main)
	main.set_meta("daily_dungeon_variant", variant)
	# Reuse actual movement, hero kits, skills, guardian combat and existing art.
	# No frame elapses here, so the field view's initial wave earns nothing.
	main._build_combat_screen()
	main.challenge_serial += 1
	var session: ChallengeBattleSession = SESSION.new()
	if not _context_matches(main, entry) or not session.begin(main.challenge_serial, DAILY.plan(variant), entry):
		main._build_meta_hub_screen()
		return false
	main.challenge_session = session
	session.combat_ledger.begin(main.deployed_heroes, main.hero_battle_state, main.skill_auto, main.ultimate_auto)
	main.hunt_combo = 0
	main.hunt_combo_remaining = 0.0
	main.hunt_variety_profile = {}
	main.hunt_event_text = session.title + " · " + session.objective_description
	spawn_wave(main)
	if not session.is_running():
		finish(main)
		return false
	main._update_hunt_hud()
	return true

static func tower_entry_context(main: Node) -> Dictionary:
	return TOWER_PROGRESS.entry_context(main)

static func tower_entry_error(main: Node) -> String:
	return TOWER_PROGRESS.entry_error(main)

static func start_tower(main: Node, expected: Dictionary = {}) -> bool:
	# Stale UI callbacks carry their original floor/party snapshot. An old
	# callback cannot start the following floor after the first run settles.
	var error: String = TOWER_PROGRESS.entry_error(main)
	if not error.is_empty():
		main._show_toast(error)
		return false
	main._sanitize_deployed_party_for_faction()
	error = TOWER_PROGRESS.entry_error(main)
	if not error.is_empty():
		main._show_toast(error)
		return false
	if not expected.is_empty() and not TOWER_PROGRESS.context_matches(main, expected):
		main._show_toast("층 또는 편성이 변경됐어요. 무한탑 화면을 다시 열어 주세요.")
		return false
	var entry: Dictionary = TOWER_PROGRESS.entry_context(main)
	var plan: Dictionary = TOWER.plan(int(entry["floor"]))
	main._build_combat_screen()
	main.challenge_serial += 1
	var session: ChallengeBattleSession = SESSION.new()
	if not TOWER_PROGRESS.context_matches(main, entry) or not session.begin(main.challenge_serial, plan, entry):
		main.set_meta("content_meta_tab", "tower")
		main._build_meta_hub_screen()
		return false
	main.challenge_session = session
	session.combat_ledger.begin(main.deployed_heroes, main.hero_battle_state, main.skill_auto, main.ultimate_auto)
	main.hunt_combo = 0
	main.hunt_combo_remaining = 0.0
	main.hunt_variety_profile = {}
	main.hunt_event_text = session.title + " · " + session.objective_description
	spawn_wave(main)
	if not session.is_running():
		finish(main)
		return false
	main._update_hunt_hud()
	return true

static func weekly_entry_context(main: Node) -> Dictionary:
	return ABYSS_PROGRESS.entry_context(main)

static func weekly_entry_error(main: Node) -> String:
	return ABYSS_PROGRESS.entry_error(main)

static func start_weekly(main: Node, expected: Dictionary = {}) -> bool:
	if preload("res://scripts/SaveSafety.gd").pending(main):
		main._show_toast(preload("res://scripts/SaveSafety.gd").entry_error(main)); return false
	if main.challenge_session != null or main._save_blocked_for_newer_version:
		return false
	main._reset_weekly_if_needed()
	main._sanitize_deployed_party_for_faction()
	var error: String = ABYSS_PROGRESS.entry_error(main)
	if not error.is_empty():
		main._show_toast(error)
		return false
	if not expected.is_empty() and not ABYSS_PROGRESS.context_matches(main, expected):
		main._show_toast("주간 또는 원정 기록이 변경됐어요. 주간 화면을 다시 열어 주세요.")
		return false
	var entry: Dictionary = ABYSS_PROGRESS.entry_context(main)
	var plan: Dictionary = ABYSS.plan(str(entry["week"]))
	main._build_combat_screen()
	main.challenge_serial += 1
	var session: ChallengeBattleSession = SESSION.new()
	if not ABYSS_PROGRESS.context_matches(main, entry) or not session.begin(main.challenge_serial, plan, entry):
		main.set_meta("content_meta_tab", "weekly")
		main._build_meta_hub_screen()
		return false
	main.challenge_session = session
	session.combat_ledger.begin(main.deployed_heroes, main.hero_battle_state, main.skill_auto, main.ultimate_auto)
	main.hunt_combo = 0
	main.hunt_combo_remaining = 0.0
	main.hunt_variety_profile = {}
	main.hunt_event_text = session.title + " · " + session.objective_description
	spawn_wave(main)
	if not session.is_running():
		finish(main)
		return false
	main._update_hunt_hud()
	return true

static func _report_active(main: Node) -> bool:
	var session: ChallengeBattleSession = main.challenge_session
	return (session != null and session.is_running() and session.elapsed < session.limit_seconds
		and int(main.challenge_serial) == session.serial and str(main.active_screen) == "combat"
		and main.combat_running and not main._application_suspended
		and int(main.hunt_ai.encounter_id) == session.active_wave_token)

static func record_damage(main: Node, enemy_id: String, before_hp: int, after_hp: int, source_slot: int = 0, critical: bool = false) -> void:
	if not _report_active(main): return
	var session: ChallengeBattleSession = main.challenge_session
	session.combat_ledger.damage(int(main.hunt_ai.encounter_id), enemy_id, before_hp, after_hp, source_slot, critical)
	if session.mode == "weekly":
		session.record_hp_loss(int(main.hunt_ai.encounter_id), enemy_id, before_hp, after_hp)

static func record_incoming(main: Node, id: String, before: int, after: int, absorbed: int) -> void:
	if _report_active(main):
		main.challenge_session.combat_ledger.incoming(id, before, after, absorbed, main.challenge_session.elapsed)

static func record_healing(main: Node, id: String, amount: int, hp: int) -> void:
	if _report_active(main): main.challenge_session.combat_ledger.healed(id, amount, hp)

static func publish_report(main: Node, session: ChallengeBattleSession) -> void:
	# A settlement-only caller has no real battle observations. Reporting must
	# remain optional and must not require UI/HP state to settle its reward.
	if session == null or session.is_running() or session.combat_ledger.actors.is_empty(): return
	var last: Dictionary = main.get_meta("last_challenge_report", {})
	if int(last.get("serial", -1)) == session.serial: return
	var report: Dictionary = session.combat_ledger.snapshot({"serial": session.serial, "mode": session.mode,
		"variant": session.variant, "title": session.title, "elapsed": session.elapsed, "limit": session.limit_seconds,
		"reason": session.reason, "waves": session.cleared_waves, "objective": session.objective,
		"entry": session.entry_context.duplicate(true), "score": session.damage_score, "practice": session.practice,
		"pattern": session.pattern.duplicate(true), "pattern_metrics": session.pattern_metrics.duplicate(true)}, main.hero_battle_state)
	if report.is_empty(): return
	var history_key: String = "practice_report_history" if session.practice else "challenge_report_history"
	var history: Array = main.get_meta(history_key, [])
	var key: String = preload("res://scripts/ChallengeCombatLedger.gd").comparison_key(report)
	if session.state != SESSION.State.CANCELLED:
		for old in history:
			if str(old.get("key", "")) == key:
				report["previous"] = old.duplicate(true)
				break
		history.push_front({"key": key, "serial": session.serial, "elapsed": report["elapsed"],
			"dps": report["dps"], "total_damage": report["total_damage"], "alive": report["alive"], "reason": session.reason})
		if history.size() > 6: history.resize(6)
	main.set_meta(history_key, history)
	main.set_meta("last_challenge_report", report)

static func _session_context_matches(main: Node, session: ChallengeBattleSession) -> bool:
	if session.practice: return main.PRACTICE.matches(main, session)
	if session.mode == "weekly":
		return int(main.challenge_serial) == session.serial and ABYSS_PROGRESS.context_matches(main, session.entry_context)
	if session.mode == "tower":
		return int(main.challenge_serial) == session.serial and TOWER_PROGRESS.context_matches(main, session.entry_context)
	return session.mode == "daily" and _context_matches(main, session.entry_context)

static func spawn_wave(main: Node) -> void:
	var session: ChallengeBattleSession = main.challenge_session
	if session == null or not session.is_running() or session.active_wave_token >= 0:
		return
	for sprite in main.enemy_wave_sprites:
		if is_instance_valid(sprite):
			sprite.queue_free()
	for bar in main.enemy_hp_bars:
		if is_instance_valid(bar):
			bar.queue_free()
	main.enemy_wave_sprites.clear()
	main.enemy_hp_bars.clear()
	main.enemy_wave.clear()
	main.roaming_hunt.clear_enemies()
	main.hunt_ai.encounter_id += 1
	main.hunt_ai.target_index = -1
	var token: int = int(main.hunt_ai.encounter_id)
	if not session.start_wave(token):
		return
	var zone: Dictionary = main._current_zone()
	var monsters: Array = zone.get("monsters", [])
	var count: int = TOWER.enemy_count(int(session.entry_context.get("floor", -1)), session.cleared_waves) if session.mode == "tower" else DAILY.enemy_count(session.variant)
	if session.mode == "weekly":
		count = 1
	if monsters.is_empty() or count <= 0:
		session.defeat("missing_monsters")
		return
	for index in count:
		var stats: Dictionary = TOWER.enemy_stats(int(session.entry_context.get("floor", -1)), session.cleared_waves, index) if session.mode == "tower" else DAILY.enemy_stats(int(session.entry_context["run_index"]), session.cleared_waves, index, session.variant)
		if session.mode == "weekly":
			stats = ABYSS.enemy_stats(str(session.entry_context.get("week", "")), session.cleared_waves)
		if stats.is_empty():
			session.defeat("invalid_wave")
			return
		var monster_name: String = str(stats.get("name", monsters[index % monsters.size()]))
		var species: Dictionary = ECOLOGY.species_profile(monster_name)
		var is_boss: bool = bool(stats.get("boss", false))
		var role: String = "brute" if is_boss else str(species.get("role", "brute"))
		var hp: int = int(stats["hp"]) * (2 if bool(stats["elite"]) else 1)
		var enemy: Dictionary = ECOLOGY.prepare_enemy({
			"id": "challenge_%d_%d_%d" % [session.serial, token, index], "name": monster_name,
			"hp": hp, "max_hp": hp, "attack": int(stats["attack"]), "archetype": role,
			"row": 0 if role in ["brute", "skirmisher"] else 2,
			"elite": bool(stats["elite"]), "challenge_boss": is_boss, "rage_triggered": false,
			"attack_speed_mult": 1.0, "challenge_attack_rate": float(stats.get("attack_rate", 1.0)),
			"attack_remaining": 0.7 + index * 0.12}, 1, 1, 1)
		main.enemy_wave.append(enemy)
	PATTERN_RULES.prepare_enemies(session, main.enemy_wave)
	if session.mode == "weekly":
		for enemy: Dictionary in main.enemy_wave:
			if not session.register_score_target(token, str(enemy["id"]), int(enemy["hp"])):
				session.defeat("invalid_wave")
				return
	session.combat_ledger.begin_wave(token, main.enemy_wave)
	main.roaming_hunt.invasion_enabled = false
	main.party_movement.independent_hunt = false
	main.party_movement.holding_formation = false
	main.roaming_hunt.spawn_group(main.enemy_wave)
	PATTERN_RULES.spread_positions(session, main.roaming_hunt)
	main._rewarded_encounter = -1
	main.roaming_wave_spawn_cooldown = 0.0
	main._reset_attack_windups(true)
	main.hunt_ai.set_state(AutoHuntController.State.MOVING)
	main._spawn_enemy_wave_sprites()
	PATTERN_RUNTIME.initialize_cues(main)
	main._sync_enemy_wave_summary()

static func ensure_wave(main: Node) -> void:
	var session: ChallengeBattleSession = main.challenge_session
	if session == null or not session.is_running():
		return
	if session.active_wave_token < 0 and main.hunt_ai.state != AutoHuntController.State.LOOTING:
		spawn_wave(main)

static func wave_cleared(main: Node) -> void:
	var session: ChallengeBattleSession = main.challenge_session
	if session == null or not session.is_running():
		return
	if not session.complete_wave(int(main.hunt_ai.encounter_id), main._enemy_wave_alive_count(), main._alive_hero_ids().size()):
		return
	main._rewarded_encounter = main.hunt_ai.encounter_id
	main.combat_kills += 1
	main._reset_attack_windups()
	main.hunt_ai.set_state(AutoHuntController.State.LOOTING)
	# No ordinary-field gold, XP, equipment, rations or stage advancement here.

static func advance(main: Node, delta: float) -> void:
	var session: ChallengeBattleSession = main.challenge_session
	if session == null or not session.is_running() or not is_finite(delta) or delta <= 0.0:
		return
	if main._save_blocked_for_newer_version or not _session_context_matches(main, session):
		session.cancel("context_changed")
		finish(main)
		return
	var step: float = minf(delta, session.remaining_seconds())
	main.hunt_ai.advance_time(step)
	main._advance_skill_cooldowns(step)
	main.combat_tick_count += 1
	if main._alive_hero_ids().is_empty():
		session.defeat()
	elif main.hunt_ai.state == AutoHuntController.State.LOOTING:
		if main.hunt_ai.state_time >= AutoHuntController.LOOT_SECONDS:
			main.hunt_ai.set_state(AutoHuntController.State.MOVING)
			spawn_wave(main)
	else:
		var support: Array[String] = []
		if main.hunt_ai.state == AutoHuntController.State.MOVING:
			support = main._advance_hunt_support(step)
		main._advance_roaming_hunt(step, support)
	# Resolve damage first at the same deadline boundary. No free survival clear
	# if the last hero died during this step. Victory is settled below, once.
	if session.is_running():
		if main._alive_hero_ids().is_empty():
			session.defeat()
		else:
			session.advance_clock(step, main._alive_hero_ids().size())
	else:
		session.elapsed = minf(session.limit_seconds, session.elapsed + step)
	if not session.is_running():
		finish(main)
		return
	main._update_combat_camera(step)
	main._update_map_hero_motion(step)
	main._update_roaming_enemy_motion(step)
	main._hud_elapsed += step
	main._save_elapsed += step
	if main._hud_elapsed >= 0.1:
		main._hud_elapsed = 0.0
		main._update_hunt_hud()
		main._update_map_tiles()
	if main._save_elapsed >= 10.0:
		main._save_elapsed = 0.0
		main._save_idle_state()

static func _apply_reward(main: Node, reward: Dictionary) -> void:
	# Wallet, allowance and unlock are subsequently written in ONE save snapshot.
	main.daily_dungeon_runs += 1
	if main.has_method("_goal_record"): main._goal_record("daily_clear")
	main.wallet_gold += int(reward["gold"])
	main.wallet_xp += int(reward["xp"])
	main._grant_hero_xp(int(reward["xp"]))
	main._grant_pet_xp(int(reward["pet_xp"]))

static func finish(main: Node) -> void:
	var session: ChallengeBattleSession = main.challenge_session
	if session == null or session.is_running():
		return
	publish_report(main, session)
	if session.practice:
		main.PRACTICE.finish(main, session)
		return
	if session.mode == "weekly":
		ABYSS_PROGRESS.finish(main, session)
		return
	if session.mode == "tower":
		TOWER_PROGRESS.finish(main, session)
		return
	main.combat_running = false
	var title: String = session.title + " 종료"
	var detail: String = "시간 초과 · 보상과 완료 횟수는 변경하지 않았어요."
	if session.state == SESSION.State.WON:
		var entry: Dictionary = session.entry_context
		var reward: Dictionary = DAILY.reward(int(entry.get("run_index", -1)))
		if main._save_blocked_for_newer_version or not _context_matches(main, entry) or reward.is_empty():
			detail = "입장 날짜·편성·기록이 변경되어 보상을 정산하지 않았어요."
		else:
			var receipt: Dictionary = session.take_victory_receipt(session.serial)
			if not receipt.is_empty():
				PROGRESS.record_direct_clear(main.daily_dungeon_clears, str(entry["faction"]), session.variant, int(entry["run_index"]))
				_apply_reward(main, reward)
				if main.has_method("_presentation_event"): main._presentation_event("victory")
				title = session.title + " 승리"
				detail = "%s · %.1f초\n골드 +%d · 경험치 +%d · 수호신 경험치 +%d\n현재 진영의 %s %d단계 소탕 해금" % [
					session.progress_text(), session.elapsed, reward["gold"], reward["xp"], reward["pet_xp"], session.title, int(entry["run_index"]) + 1]
	elif session.state == SESSION.State.LOST and session.reason == "party_defeated":
		detail = "원정대 전멸 · 보상과 완료 횟수는 변경하지 않았어요."
	elif session.state == SESSION.State.LOST and session.reason in ["missing_monsters", "invalid_wave"]:
		detail = "전투 데이터를 불러오지 못했어요. 보상과 완료 횟수는 변경하지 않았어요."
	elif session.state == SESSION.State.CANCELLED:
		detail = "날짜·진영·편성 변경 또는 원정 취소 · 보상과 완료 횟수는 변경하지 않았어요."
	main.set_meta("last_dungeon_result", {"mode": "daily", "variant": session.variant, "title": title, "detail": detail, "battle_serial": session.serial})
	# Detach before changing the view; _clear_screen cannot settle this again.
	main.challenge_session = null
	main._save_idle_state()
	main.set_meta("content_meta_tab", "daily")
	main._build_meta_hub_screen()
	main._show_toast(title)

static func sweep_error(main: Node, variant: String) -> String:
	var error: String = _entry_error(main, variant)
	if not error.is_empty():
		return error
	if not PROGRESS.can_sweep(main.daily_dungeon_clears, str(main.selected_faction), variant, int(main.daily_dungeon_runs)):
		return "현재 진영에서 이 유형·단계를 직접 클리어하면 소탕할 수 있어요."
	return ""

static func sweep_daily(main: Node, variant: String, expected: Dictionary) -> bool:
	# UI passes its original day/index/faction/party snapshot. The second click on
	# a stale button must not consume the NEXT run, even if that tier is unlocked.
	if not _context_matches(main, expected):
		main._show_toast("원정 기록이 변경됐어요. 던전 화면을 다시 열어 주세요.")
		return false
	var error: String = sweep_error(main, variant)
	if not error.is_empty():
		main._show_toast(error)
		return false
	var reward: Dictionary = DAILY.reward(int(expected["run_index"]))
	if reward.is_empty():
		return false
	_apply_reward(main, reward)
	# A sweep NEVER creates another direct-clear record.
	var mode_plan: Dictionary = DAILY.plan(variant)
	main.set_meta("last_dungeon_result", {"mode": "daily", "variant": variant,
		"title": str(mode_plan["title"]) + " 소탕 완료",
		"detail": "%d / 3회 완료 · 골드 +%d · 경험치 +%d\n수호신 경험치 +%d · 전투와 동일한 보상" % [
			main.daily_dungeon_runs, reward["gold"], reward["xp"], reward["pet_xp"]]})
	main._save_idle_state()
	main.set_meta("content_meta_tab", "daily")
	main._build_meta_hub_screen()
	main._show_toast("소탕 완료 · 일일 원정 1회 사용")
	return true
