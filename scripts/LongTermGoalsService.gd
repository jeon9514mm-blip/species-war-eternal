extends RefCounted
class_name LongTermGoalsService

const C = preload("res://scripts/LongTermGoalCatalog.gd")
const S = preload("res://scripts/LongTermGoalState.gd")
const MAX_CURRENCY: int = 1000000000000

static func refresh(main: Node) -> void:
	if not main.long_term_goals.has("factions"):
		main.long_term_goals = S.sanitize(main.long_term_goals)
	S.advance_periods(main.long_term_goals, str(main._today_key()), str(main._week_key()))
	var faction: String = str(main.selected_faction)
	if faction not in C.FACTIONS: return
	var discovered: Array[String] = []
	var level: int = 1
	for hero: Dictionary in main._hero_roster_for_faction():
		var id: String = str(hero["id"])
		if bool(main.codex_seen.get(id, false)) or int(main.idle_stage) >= int(hero.get("unlock_stage", 1)):
			discovered.append(id)
			var data: Dictionary = S.dict(main.hero_progress.get(id))
			level = maxi(level, S.number(data.get("level", 1), 100))
	S.observe(main.long_term_goals, faction, {"stage": main.idle_stage, "hero_level": level, "tower_best": main.tower_best_floor}, discovered)

static func record(main: Node, event: String, amount: int = 1) -> void:
	refresh(main)
	# Callers own one-shot combat receipts. No polling/delta guessing from saves.
	S.record(main.long_term_goals, str(main.selected_faction), event, amount, str(main._today_key()), str(main._week_key()))

static func context(main: Node, scope: String) -> Dictionary:
	refresh(main)
	return {"faction": str(main.selected_faction), "scope": scope,
		"key": str(main._today_key()) if scope == "daily" else (str(main._week_key()) if scope == "weekly" else "")}

static func rows(main: Node, scope: String) -> Array[Dictionary]:
	refresh(main)
	var output: Array[Dictionary] = []
	for entry: Dictionary in C.entries(scope):
		var status: Dictionary = S.status(main.long_term_goals, str(main.selected_faction), scope, str(entry["id"]))
		if not status.is_empty(): output.append(status)
	return output

static func ready_count(main: Node, scope: String = "") -> int:
	var count: int = 0
	var scopes: Array = [scope] if not scope.is_empty() else ["guide", "daily", "weekly", "achievement"]
	for item: String in scopes:
		for entry: Dictionary in rows(main, item):
			if bool(entry["ready"]): count += 1
	return count

static func tracked_text(main: Node) -> String:
	refresh(main)
	var faction: String = str(main.selected_faction)
	if faction not in C.FACTIONS: return "진영을 선택하고 여정을 시작하세요"
	var done: int = int(main.long_term_goals["factions"][faction]["guide_claimed"])
	if done >= C.GUIDE_COUNT: return "가이드 100개 완료 · 일일·주간 목표 확인"
	var goal: Dictionary = S.status(main.long_term_goals, faction, "guide", str(C.guide()[done]["id"]))
	return "[%d/100] %s · %d/%d%s" % [done + 1, goal["title"], goal["current"], goal["target"], " · 수령 가능" if bool(goal["ready"]) else ""]

static func _error(main: Node) -> String:
	var save_error: String = preload("res://scripts/SaveSafety.gd").entry_error(main)
	if not save_error.is_empty(): return save_error
	if main._save_blocked_for_newer_version: return "최신 버전의 저장 기록을 확인해 주세요."
	if main.goals_save_pending: return "목표 보상 저장이 대기 중이에요. 먼저 다시 저장해 주세요."
	if main.goal_claim_busy: return "이미 보상을 처리하고 있어요."
	if main.challenge_session != null or main.raid_running: return "진행 중인 전투를 마친 뒤 목표를 수령해 주세요."
	if str(main.selected_faction) not in C.FACTIONS: return "먼저 진영을 선택하세요."
	return ""

static func claim(main: Node, scope: String, id: String, expected: Dictionary) -> Dictionary:
	var error: String = _error(main)
	if not error.is_empty():
		main._show_toast(error)
		return {"ok": false, "reason": error}
	refresh(main)
	# Mutate a candidate ledger. The live state changes only after validation.
	var next: Dictionary = main.long_term_goals.duplicate(true)
	var receipt: Dictionary = S.claim(next, str(main.selected_faction), scope, id, expected, str(main._today_key()), str(main._week_key()))
	if not bool(receipt.get("ok", false)):
		main._show_toast("이미 수령했거나 조건·기간·진영이 변경됐어요. 목표 화면을 다시 확인해 주세요.")
		return receipt
	return _commit(main, next, int(receipt["gold"]), int(receipt["gems"]), 1)

static func claim_all(main: Node, scope: String, expected: Dictionary) -> Dictionary:
	var error: String = _error(main)
	if not error.is_empty() or scope not in ["daily", "weekly", "achievement"]:
		if not error.is_empty(): main._show_toast(error)
		return {"ok": false, "reason": "blocked"}
	refresh(main)
	var next: Dictionary = main.long_term_goals.duplicate(true)
	var gold: int = 0
	var gems: int = 0
	var count: int = 0
	for entry: Dictionary in C.entries(scope):
		var receipt: Dictionary = S.claim(next, str(main.selected_faction), scope, str(entry["id"]), expected, str(main._today_key()), str(main._week_key()))
		if bool(receipt.get("ok", false)):
			count += 1
			gold += int(receipt["gold"])
			gems += int(receipt["gems"])
	if count == 0: return {"ok": false, "reason": "nothing_ready"}
	return _commit(main, next, gold, gems, count)

static func _commit(main: Node, next: Dictionary, gold: int, gems: int, count: int) -> Dictionary:
	main.goal_claim_busy = true
	var old_gold: int = int(main.wallet_gold)
	var old_gems: int = int(main.wallet_gems)
	var old_tier: int = S.collection_tier(main.long_term_goals, str(main.selected_faction))
	main.long_term_goals = next
	main.wallet_gold = mini(MAX_CURRENCY, old_gold + gold)
	main.wallet_gems = mini(MAX_CURRENCY, old_gems + gems)
	var actual_gold: int = int(main.wallet_gold) - old_gold
	var actual_gems: int = int(main.wallet_gems) - old_gems
	# Keep the consumed receipt in memory if IO fails. Never rollback a payload
	# that may already exist as SaveStore's recoverable .tmp snapshot.
	main.goals_save_pending = true
	main._save_idle_state()
	var saved: bool = str(main.last_save_status) == "saved"
	main.goals_save_pending = not saved
	main.goal_claim_busy = false
	if S.collection_tier(next, str(main.selected_faction)) != old_tier:
		main._refresh_growth_runtime()
	if saved and main.has_method("_presentation_event"): main._presentation_event("reward")
	main._show_toast("목표 %d개 · 골드 +%d · 젬 +%d%s" % [count, actual_gold, actual_gems, "" if saved else " · 저장 대기, 다시 저장해 주세요"])
	return {"ok": saved, "pending": not saved, "count": count, "gold": actual_gold, "gems": actual_gems}

static func retry_save(main: Node) -> bool:
	if not main.goals_save_pending or main.goal_claim_busy or main._save_blocked_for_newer_version: return false
	main._save_idle_state()
	var saved: bool = str(main.last_save_status) == "saved"
	main.goals_save_pending = not saved
	main._show_toast("목표 보상을 저장했어요." if saved else "저장이 아직 실패하고 있어요. 저장 공간을 확인해 주세요.")
	return saved

static func equip_title(main: Node, id: String, expected_faction: String) -> bool:
	if not _error(main).is_empty() or str(main.selected_faction) != expected_faction: return false
	refresh(main)
	var bank: Dictionary = main.long_term_goals["factions"][expected_faction]
	if not id.is_empty() and (not C.TITLES.has(id) or not bool(bank["achievements"].get(id, false))): return false
	bank["title"] = id
	main.goals_save_pending = true
	main._save_idle_state()
	main.goals_save_pending = str(main.last_save_status) != "saved"
	return not main.goals_save_pending

static func title_text(main: Node) -> String:
	var bank: Dictionary = S.dict(S.dict(main.long_term_goals.get("factions")).get(str(main.selected_faction)))
	return str(C.TITLES.get(str(bank.get("title", "")), "칭호 미선택"))
