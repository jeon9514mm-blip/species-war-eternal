extends SceneTree
const C = preload("res://scripts/LongTermGoalCatalog.gd")
const S = preload("res://scripts/LongTermGoalState.gd")
var checks: int = 0
var failures: Array[String] = []
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); push_error(label)
func ctx(scope: String, faction: String = "aurelia", key: String = "") -> Dictionary:
	return {"scope": scope, "faction": faction, "key": key}
func _init() -> void:
	check(C.guide().size() == 100 and C.daily().size() == 6 and C.weekly().size() == 6 and C.achievements().size() == 18, "catalog sizes")
	var keys: Dictionary = {}
	for scope in ["guide", "daily", "weekly", "achievement"]:
		for entry in C.entries(scope):
			check(not keys.has(entry["id"]), "unique stable id " + entry["id"])
			keys[entry["id"]] = true
			check(entry["target"] > 0 and entry["gold"] >= 0 and entry["gems"] >= 0, "nonnegative definition " + entry["id"])
	var state: Dictionary = S.sanitize({})
	S.advance_periods(state, "2026-10-01", "2960")
	check(not S.claim(state, "aurelia", "guide", "guide_002", ctx("guide"), "2026-10-01", "2960")["ok"], "cannot skip guide")
	check(not S.record(state, "foreign", "hunt_packs", 5, "2026-10-01", "2960"), "reject foreign faction")
	check(not S.record(state, "aurelia", "unknown", 5, "2026-10-01", "2960"), "reject unknown event")
	check(not S.record(state, "aurelia", "hunt_packs", -5, "2026-10-01", "2960"), "reject negative amount")
	S.record(state, "aurelia", "hunt_packs", 10, "2026-10-01", "2960")
	check(state["factions"]["noxfera"]["totals"]["hunt_packs"] == 0, "permanent counters faction isolated")
	check(S.claim(state, "aurelia", "daily", "daily_hunt_10", ctx("daily", "aurelia", "2026-10-01"), "2026-10-01", "2960")["ok"], "daily first claim")
	check(not S.claim(state, "aurelia", "daily", "daily_hunt_10", ctx("daily", "aurelia", "2026-10-01"), "2026-10-01", "2960")["ok"], "daily replay rejected")
	check(not S.claim(state, "noxfera", "daily", "daily_hunt_10", ctx("daily", "noxfera", "2026-10-01"), "2026-10-01", "2960")["ok"], "switching faction cannot farm daily")
	S.advance_periods(state, "2026-10-02", "2960")
	check(state["daily"]["counts"]["hunt_packs"] == 0 and state["weekly"]["counts"]["hunt_packs"] == 10, "midnight resets daily only")
	S.record(state, "aurelia", "hunt_packs", 10, "2026-10-02", "2960")
	check(not S.claim(state, "aurelia", "daily", "daily_hunt_10", ctx("daily", "aurelia", "2026-10-01"), "2026-10-02", "2960")["ok"], "old midnight button rejected")
	check(S.claim(state, "aurelia", "daily", "daily_hunt_10", ctx("daily", "aurelia", "2026-10-02"), "2026-10-02", "2960")["ok"], "new daily can claim")
	var before: String = JSON.stringify(state["daily"])
	S.record(state, "aurelia", "hunt_packs", 100, "2026-10-01", "2959")
	check(JSON.stringify(state["daily"]) == before, "clock rollback cannot refill or add to future day")
	check(state["weekly"]["counts"]["hunt_packs"] == 20, "clock rollback does not advance saved future week")
	S.advance_periods(state, "2026-10-05", "2961")
	check(state["weekly"]["counts"]["hunt_packs"] == 0, "weekly advance reset")
	for invalid in [null, [], true, "bad", 1e300]:
		var clean: Dictionary = S.sanitize(invalid)
		check(clean["factions"].size() == 2 and clean["daily"]["claimed"].is_empty(), "malformed state bounded")
	for date in ["2026-02-30", "2026-00-01", "2026-10-xx", "9999-01-01", "2026-01-1"]:
		check(S.day_key(date).is_empty(), "invalid date " + date)
	check(S.day_key("2028-02-29") == "2028-02-29" and S.day_key("2026-02-29").is_empty(), "leap-year boundary")
	var forged: Dictionary = {"factions": {"aurelia": {"guide_claimed": 1e300, "title": "unknown", "discovered": {"leonhardt": true, "valeria": true, "made_up": true}, "totals": {"hunt_packs": -1, "daily_clear": "100"}, "best": {"hero_level": 999}, "achievements": {"collection_5": "true", "made_up": true}}}}
	var clean: Dictionary = S.sanitize(forged)
	check(clean["factions"]["aurelia"]["guide_claimed"] == 100, "guide upper bound")
	check(clean["factions"]["aurelia"]["totals"]["hunt_packs"] == 0 and clean["factions"]["aurelia"]["totals"]["daily_clear"] == 0, "invalid numeric counters zero")
	check(clean["factions"]["aurelia"]["best"]["hero_level"] == 100 and clean["factions"]["aurelia"]["title"] == "", "bad level/title sanitized")
	check(not clean["factions"]["aurelia"]["discovered"].has("valeria") and not clean["factions"]["aurelia"]["discovered"].has("made_up"), "foreign and unknown hero filtered")
	check(clean["factions"]["aurelia"]["achievements"].is_empty(), "only genuine bool flags retained")
	# A deterministic maximum-progress fixture verifies all 100 gates and reward
	# ledgers. It is a model test, NOT a playthrough of 100 campaign milestones.
	var complete: Dictionary = S.sanitize({})
	S.advance_periods(complete, "2026-10-01", "2960")
	var heroes: Array[String] = []
	for id: String in S.HEROES.HEROES:
		if str(S.HEROES.HEROES[id]["faction"]) == "aurelia": heroes.append(id)
	S.observe(complete, "aurelia", {"stage": 10000, "hero_level": 100, "tower_best": 9999}, heroes)
	for event in C.EVENTS: S.record(complete, "aurelia", event, 10000, "2026-10-01", "2960")
	var guide_gold: int = 0
	for entry in C.guide():
		var receipt: Dictionary = S.claim(complete, "aurelia", "guide", entry["id"], ctx("guide"), "2026-10-01", "2960")
		check(receipt["ok"], "guide reachable " + entry["id"])
		guide_gold += int(receipt.get("gold", 0))
		check(not S.claim(complete, "aurelia", "guide", entry["id"], ctx("guide"), "2026-10-01", "2960")["ok"], "guide replay " + entry["id"])
	check(complete["factions"]["aurelia"]["guide_claimed"] == 100 and guide_gold == 31000, "100 guides correct total reward")
	for entry in C.achievements():
		check(S.claim(complete, "aurelia", "achievement", entry["id"], ctx("achievement"), "2026-10-01", "2960")["ok"], "achievement reachable " + entry["id"])
	check(S.collection_tier(complete, "aurelia") == 3 and S.collection_tier(complete, "noxfera") == 0, "collection HP tier capped and faction isolated")
	check(S.sanitize(JSON.parse_string(JSON.stringify(complete))) == complete, "JSON float/int roundtrip semantic equality")
	print("v81_goal_rules checks=%d failures=%s" % [checks, JSON.stringify(failures)])
	quit(0 if failures.is_empty() else 1)
