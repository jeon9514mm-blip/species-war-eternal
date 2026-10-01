extends RefCounted
## Level matching is a transient combat-stat override, never a hero_progress edit.
const HEROES = preload("res://scripts/HeroRosterCatalog.gd")
const MODES: Array[String] = ["actual", "matched"]

static func actual_level(main: Node, hero_id: String) -> int:
	return clampi(int(main.hero_progress.get(hero_id, {}).get("level", 1)), 1, main.MAX_HERO_LEVEL)

static func ceiling(main: Node) -> int:
	var highest: int = 1
	for hero: Dictionary in HEROES.roster(str(main.selected_faction)):
		if int(main.idle_stage) >= int(hero.get("unlock_stage", 1)):
			highest = maxi(highest, actual_level(main, str(hero["id"])))
	return highest

static func plan(main: Node, mode: String, level: int) -> Dictionary:
	if mode not in MODES or str(main.selected_faction) not in ["aurelia", "noxfera"]: return {}
	if mode == "matched" and (level < 1 or level > ceiling(main)): return {}
	var ids: Array[String] = main._deployed_hero_ids()
	if ids.is_empty() or ids.size() > main._party_slot_cap(): return {}
	var seen: Dictionary = {}; var actual: Dictionary = {}
	for id: String in ids:
		var hero: Dictionary = HEROES.HEROES.get(id, {})
		if seen.has(id) or hero.is_empty() or str(hero.get("faction", "")) != str(main.selected_faction) or int(main.idle_stage) < int(hero.get("unlock_stage", 1)): return {}
		seen[id] = true; actual[id] = actual_level(main, id)
	return {"mode": mode, "level": level if mode == "matched" else 0, "faction": str(main.selected_faction),
		"heroes": ids.duplicate(), "actual_levels": actual}

static func effective_level(main: Node, hero_id: String) -> int:
	var actual: int = actual_level(main, hero_id)
	var setting: Dictionary = main.get_meta("practice_level_override", {})
	if not bool(main.get_meta("practice_active", false)) or str(setting.get("mode", "actual")) != "matched": return actual
	if str(setting.get("faction", "")) != str(main.selected_faction) or hero_id not in setting.get("heroes", []): return actual
	return clampi(int(setting.get("level", actual)), 1, main.MAX_HERO_LEVEL)

static func caption(setting: Dictionary) -> String:
	return "레벨만 맞춤 Lv.%d · 장비·연구·돌파는 실제 상태" % int(setting.get("level", 1)) if str(setting.get("mode", "actual")) == "matched" else "현재 성장 상태로 연습"
