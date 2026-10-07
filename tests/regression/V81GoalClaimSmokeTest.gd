extends SceneTree
const SERVICE = preload("res://scripts/progression/LongTermGoalsService.gd")
const STATE = preload("res://scripts/progression/LongTermGoalState.gd")
## Controlled IO-failure injection tests the claim transaction; separate save
## tests exercise the real filesystem. No fake fault is reported as real IO.
class Host extends Node:
	var long_term_goals: Dictionary = {}
	var selected_faction: String = "aurelia"
	var codex_seen: Dictionary = {}
	var hero_progress: Dictionary = {}
	var idle_stage: int = 1
	var tower_best_floor: int = 0
	var wallet_gold: int = 0
	var wallet_gems: int = 0
	var goals_save_pending: bool = false
	var goal_claim_busy: bool = false
	var _save_blocked_for_newer_version: bool = false
	var challenge_session: Variant = null
	var raid_running: bool = false
	var last_save_status: String = ""
	var fail_io: bool = false
	var saves: int = 0
	var reenter: bool = false
	var reentry_blocked: bool = false
	var day: String = "2026-10-01"
	var week: String = "2960"
	func _today_key() -> String: return day
	func _week_key() -> String: return week
	func _hero_roster_for_faction() -> Array: return []
	func _show_toast(_text: String) -> void: pass
	func _refresh_growth_runtime() -> void: pass
	func _save_idle_state() -> void:
		saves += 1
		if reenter:
			reenter = false
			var ctx: Dictionary = SERVICE.context(self, "daily")
			reentry_blocked = not SERVICE.claim(self, "daily", "daily_hunt_30", ctx).get("ok", false)
		last_save_status = "write_failed" if fail_io else "saved"
var checks: int = 0
var failures: Array[String] = []
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); push_error(label)
func _init() -> void:
	var host: Host = Host.new()
	SERVICE.record(host, "hunt_packs", 60)
	var ctx: Dictionary = SERVICE.context(host, "daily")
	host.fail_io = true
	var first: Dictionary = SERVICE.claim(host, "daily", "daily_hunt_10", ctx)
	check(first.get("pending", false) and not first["ok"] and host.goals_save_pending, "IO failure explicitly pending, not success")
	check(host.wallet_gold == 100 and host.long_term_goals["daily"]["claimed"].get("daily_hunt_10", false), "receipt and currency retained in memory")
	check(not SERVICE.claim(host, "daily", "daily_hunt_10", ctx).get("ok", false) and host.wallet_gold == 100, "pending cannot pay same reward again")
	check(not SERVICE.claim(host, "daily", "daily_hunt_30", ctx).get("ok", false), "pending blocks other claims")
	check(not SERVICE.retry_save(host) and host.wallet_gold == 100, "failed retry has no extra reward")
	host.fail_io = false
	check(SERVICE.retry_save(host) and not host.goals_save_pending and host.wallet_gold == 100, "successful retry writes existing reward only")
	host.reenter = true
	var before_saves: int = host.saves
	var batch: Dictionary = SERVICE.claim_all(host, "daily", ctx)
	check(batch.get("ok", false) and batch["count"] == 2, "claim all takes remaining ready missions")
	check(host.saves == before_saves + 1, "batch is one save snapshot")
	check(host.reentry_blocked and host.wallet_gold == 450 and host.wallet_gems == 4, "reentrancy blocked and exact daily reward")
	var before: Array = [host.wallet_gold, host.wallet_gems, host.saves]
	check(not SERVICE.claim_all(host, "daily", ctx).get("ok", false), "empty repeat batch rejected")
	check(before == [host.wallet_gold, host.wallet_gems, host.saves], "duplicate batch never saves or pays")
	host.selected_faction = "noxfera"
	check(not SERVICE.claim(host, "daily", "daily_hunt_10", ctx).get("ok", false), "stale faction callback rejected")
	check(not SERVICE.claim_all(host, "daily", SERVICE.context(host, "daily")).get("ok", false), "repeat rewards shared across factions")
	host.selected_faction = "aurelia"
	host.day = "2026-10-02"
	SERVICE.record(host, "hunt_packs", 10)
	check(not SERVICE.claim(host, "daily", "daily_hunt_10", ctx).get("ok", false), "yesterday callback rejected")
	ctx = SERVICE.context(host, "daily")
	host.wallet_gold = SERVICE.MAX_CURRENCY - 1
	host.wallet_gems = SERVICE.MAX_CURRENCY
	var cap: Dictionary = SERVICE.claim(host, "daily", "daily_hunt_10", ctx)
	check(cap["ok"] and cap["gold"] == 1 and cap["gems"] == 0 and host.wallet_gold == SERVICE.MAX_CURRENCY, "only actual currency increase reported at cap")
	host._save_blocked_for_newer_version = true
	check(not SERVICE.claim(host, "guide", "guide_001", SERVICE.context(host, "guide")).get("ok", false), "newer save blocks rewards")
	host._save_blocked_for_newer_version = false
	host.raid_running = true
	check(not SERVICE.claim(host, "guide", "guide_001", SERVICE.context(host, "guide")).get("ok", false), "in-progress raid blocks reward/stat changes")
	host.raid_running = false
	check(not SERVICE.equip_title(host, "hunt_100", "aurelia"), "unearned title cannot equip")
	SERVICE.record(host, "hunt_packs", 100)
	check(SERVICE.claim(host, "achievement", "hunt_100", SERVICE.context(host, "achievement")).get("ok", false), "title achievement earned")
	check(SERVICE.equip_title(host, "hunt_100", "aurelia") and SERVICE.title_text(host) == "길을 여는 자", "earned title selectable")
	check(not SERVICE.equip_title(host, "hunt_100", "noxfera"), "cross-faction title callback rejected")
	check(SERVICE.equip_title(host, "", "aurelia") and SERVICE.title_text(host) == "칭호 미선택", "title removable")
	host.free()
	print("v81_goal_claim checks=%d failures=%s" % [checks, JSON.stringify(failures)])
	quit(0 if failures.is_empty() else 1)
