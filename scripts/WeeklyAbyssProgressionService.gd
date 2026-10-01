extends RefCounted

const RULES = preload("res://scripts/WeeklyAbyssBattleRules.gd")
const SESSION = preload("res://scripts/ChallengeBattleSession.gd")
const FACTIONS: Array[String] = ["aurelia", "noxfera"]

static func entry_context(main: Node) -> Dictionary:
	return {"week": str(main.weekly_content_key), "run_index": int(main.weekly_trial_runs),
		"best": int(main.weekly_trial_best), "faction": str(main.selected_faction),
		"zone": str(main.current_zone_id), "hero_ids": main._deployed_hero_ids().duplicate()}

static func context_matches(main: Node, expected: Dictionary) -> bool:
	return (str(main._week_key()) == str(expected.get("week", ""))
		and str(main.weekly_content_key) == str(expected.get("week", ""))
		and int(main.weekly_trial_runs) == int(expected.get("run_index", -1))
		and int(main.weekly_trial_best) == int(expected.get("best", -1))
		and str(main.selected_faction) == str(expected.get("faction", ""))
		and str(main.current_zone_id) == str(expected.get("zone", ""))
		and main._deployed_hero_ids() == expected.get("hero_ids", []))

static func entry_error(main: Node) -> String:
	var save_error: String = preload("res://scripts/SaveSafety.gd").entry_error(main)
	if not save_error.is_empty(): return save_error
	if main.challenge_session != null:
		return "진행 중인 도전을 먼저 마쳐 주세요."
	if main._save_blocked_for_newer_version:
		return "최신 버전의 저장 기록을 먼저 확인해 주세요."
	if not RULES.valid_week(str(main.weekly_content_key)) or str(main._week_key()) != str(main.weekly_content_key):
		return "주간 기간이 변경되었거나 기기 시계가 이전 주로 설정되어 있어요."
	if int(main.weekly_trial_runs) < 0 or int(main.weekly_trial_runs) >= RULES.WEEKLY_LIMIT:
		return "이번 주 심연 원정 5회를 모두 완료했어요."
	if str(main.selected_faction) not in FACTIONS or main.deployed_heroes.is_empty():
		return "먼저 진영과 원정대를 편성하세요."
	return ""

static func finish(main: Node, session: ChallengeBattleSession) -> void:
	if session == null or main.challenge_session != session or session.mode != "weekly" or session.is_running():
		return
	main.combat_running = false
	var title: String = "주간 심연 종료"
	var detail: String = "기록과 보상은 변경하지 않았어요."
	var awarded: bool = false
	var outcome: String = "lost"
	if session.state == SESSION.State.WON:
		var reward: Dictionary = RULES.reward(int(session.entry_context.get("run_index", -1)))
		if main._save_blocked_for_newer_version or int(main.challenge_serial) != session.serial or not context_matches(main, session.entry_context) or reward.is_empty() or session.damage_score <= 0 or session.elapsed < RULES.LIMIT_SECONDS:
			outcome = "invalid"
			detail = "입장 주간·진영·편성·기록이 달라져 점수와 보상을 정산하지 않았어요."
		else:
			var receipt: Dictionary = session.take_victory_receipt(int(main.challenge_serial))
			if not receipt.is_empty():
				var score: int = clampi(int(receipt.get("damage_score", 0)), 0, RULES.MAX_SCORE)
				main.weekly_trial_runs += 1
				if main.has_method("_goal_record"): main._goal_record("abyss_clear")
				main.weekly_trial_best = maxi(int(main.weekly_trial_best), score)
				main.wallet_gold += int(reward["gold"])
				main.wallet_gems += int(reward["gems"])
				main._grant_hero_xp(int(reward["hero_xp"]))
				awarded = true
				outcome = "won"
				title = "주간 심연 기록 완료"
				detail = "90초 생존 · 실제 피해 %d · 최고 %d\n%d / 5회 완료 · 골드 +%d · 젬 +%d · 영웅 경험치 +%d" % [
					score, main.weekly_trial_best, main.weekly_trial_runs, reward["gold"], reward["gems"], reward["hero_xp"]]
	elif session.state == SESSION.State.LOST:
		if session.reason == "party_defeated":
			detail = "원정대 전멸 · 이번 피해 %d · 최고 기록·보상·횟수는 변경하지 않았어요." % session.damage_score
		elif session.reason == "no_damage":
			detail = "기록할 실제 피해가 없어요. 보상과 완료 횟수는 변경하지 않았어요."
		elif session.reason in ["missing_monsters", "invalid_wave"]:
			detail = "전투 데이터를 불러오지 못했어요. 기록과 보상은 변경하지 않았어요."
	elif session.state == SESSION.State.CANCELLED:
		outcome = "cancelled"
		detail = "도전 취소 또는 주간·진영·편성 변경 · 기록·보상·완료 횟수는 변경하지 않았어요."
	# Consume receipt and detach before navigating. Local replay protection only;
	# no claim of server authority or crash-proof persistence across save failure.
	main.set_meta("last_dungeon_result", {"mode": "weekly", "title": title, "detail": detail,
		"battle_serial": session.serial, "score": session.damage_score, "elapsed": session.elapsed,
		"settled": awarded, "outcome": outcome})
	main.challenge_session = null
	main._save_idle_state()
	preload("res://scripts/SaveSafety.gd").observe(main)
	main.set_meta("content_meta_tab", "weekly")
	main._build_meta_hub_screen()
	main._show_toast(title)
