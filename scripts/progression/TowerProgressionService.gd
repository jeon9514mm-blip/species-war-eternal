extends RefCounted

const RULES = preload("res://scripts/progression/TowerBattleRules.gd")
const SESSION = preload("res://scripts/combat/ChallengeBattleSession.gd")
const FACTIONS: Array[String] = ["aurelia", "noxfera"]

static func entry_context(main: Node) -> Dictionary:
	return {"floor": int(main.tower_floor), "best_floor": int(main.tower_best_floor),
		"faction": str(main.selected_faction), "zone": str(main.current_zone_id),
		"hero_ids": main._deployed_hero_ids().duplicate()}

static func context_matches(main: Node, expected: Dictionary) -> bool:
	# Tower progress is not a daily allowance: midnight is deliberately irrelevant.
	return (int(main.tower_floor) == int(expected.get("floor", -1))
		and int(main.tower_best_floor) == int(expected.get("best_floor", -1))
		and str(main.selected_faction) == str(expected.get("faction", ""))
		and str(main.current_zone_id) == str(expected.get("zone", ""))
		and main._deployed_hero_ids() == expected.get("hero_ids", []))

static func entry_error(main: Node) -> String:
	var save_error: String = preload("res://scripts/persistence/SaveSafety.gd").entry_error(main)
	if not save_error.is_empty(): return save_error
	if main.challenge_session != null:
		return "진행 중인 도전을 먼저 마쳐 주세요."
	if main._save_blocked_for_newer_version:
		return "최신 버전의 저장 기록을 먼저 확인해 주세요."
	if str(main.selected_faction) not in FACTIONS or main.deployed_heroes.is_empty():
		return "먼저 진영과 원정대를 편성하세요."
	if int(main.tower_floor) > RULES.MAX_CLEAR_FLOOR:
		return "현재 지원하는 무한탑 층을 모두 진행했어요."
	if not RULES.valid_floor(int(main.tower_floor)) or int(main.tower_best_floor) < 0 or int(main.tower_best_floor) >= int(main.tower_floor):
		return "무한탑 층 기록을 다시 확인해 주세요."
	# Recommended power is information only, never an instant-win or entry gate.
	return ""

static func finish(main: Node, session: ChallengeBattleSession) -> void:
	if session == null or main.challenge_session != session or session.mode != "tower" or session.is_running():
		return
	main.combat_running = false
	var floor_number: int = int(session.entry_context.get("floor", -1))
	var title: String = session.title + " 종료"
	var detail: String = "시간 초과 · 층 기록과 보상은 변경하지 않았어요."
	var awarded: bool = false
	var outcome: String = "lost"
	if session.state == SESSION.State.WON:
		var reward: Dictionary = RULES.reward(floor_number)
		if main._save_blocked_for_newer_version or int(main.challenge_serial) != session.serial or not context_matches(main, session.entry_context) or reward.is_empty() or floor_number <= int(main.tower_best_floor):
			outcome = "invalid"
			detail = "입장 당시 층·진영·편성 기록이 달라져 보상을 지급하지 않았어요."
		else:
			var receipt: Dictionary = session.take_victory_receipt(int(main.challenge_serial))
			if not receipt.is_empty():
				main.tower_best_floor = maxi(int(main.tower_best_floor), floor_number)
				main.tower_floor = floor_number + 1
				if main.has_method("_goal_record"): main._goal_record("tower_clear")
				main.wallet_gold += int(reward["gold"])
				main.wallet_gems += int(reward["gems"])
				awarded = true
				outcome = "won"
				title = "무한탑 %d층 돌파" % floor_number
				detail = "%s · %.1f초\n최고 %d층 · 다음 도전 %d층\n골드 +%d · 젬 +%d" % [
					session.progress_text(), session.elapsed, main.tower_best_floor, main.tower_floor, reward["gold"], reward["gems"]]
	elif session.state == SESSION.State.LOST and session.reason == "party_defeated":
		detail = "원정대 전멸 · 층 기록과 보상은 변경하지 않았어요."
	elif session.state == SESSION.State.LOST and session.reason in ["missing_monsters", "invalid_wave"]:
		detail = "전투 데이터를 불러오지 못했어요. 층 기록과 보상은 변경하지 않았어요."
	elif session.state == SESSION.State.CANCELLED:
		outcome = "cancelled"
		detail = "도전 취소 또는 층·진영·편성 변경 · 층 기록과 보상은 변경하지 않았어요."
	# The runtime receipt is consumed and detached BEFORE any UI navigation.
	# Progress and wallet are then saved together. This is a local transaction
	# guard, not server authority or a guarantee against filesystem failure.
	main.set_meta("last_dungeon_result", {"mode": "tower", "title": title, "detail": detail,
		"floor": floor_number, "battle_serial": session.serial, "settled": awarded, "outcome": outcome})
	main.challenge_session = null
	main._save_idle_state()
	preload("res://scripts/persistence/SaveSafety.gd").observe(main)
	main.set_meta("content_meta_tab", "tower")
	main._build_meta_hub_screen()
	main._show_toast(title)
