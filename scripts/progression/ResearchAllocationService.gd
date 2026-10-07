extends RefCounted
## v83-4. Preview is pure; confirm commits one allocation with the same real budget.
## No gems, gold, skill ranks, gear or earned levels are copied or refunded.
const HEROES = preload("res://scripts/heroes/HeroRosterCatalog.gd")
const SAFETY = preload("res://scripts/persistence/SaveSafety.gd")
const BRANCHES: Array[String] = ["offense", "survival", "utility"]

static func entry_error(main: Node, hero_id: String) -> String:
	if main.challenge_session != null or main.raid_running or str(main.active_screen) in ["combat", "raid"] or bool(main.get_meta("practice_active", false)):
		return "전투를 마친 뒤 연구를 재배분하세요."
	if main._save_blocked_for_newer_version: return "최신 버전의 저장 기록을 먼저 확인해 주세요."
	if SAFETY.pending(main): return SAFETY.entry_error(main)
	var hero: Dictionary = HEROES.HEROES.get(hero_id, {})
	if hero.is_empty() or str(hero.get("faction", "")) != str(main.selected_faction) or int(main.idle_stage) < int(hero.get("unlock_stage", 1)):
		return "현재 진영에서 합류한 영웅만 재배분할 수 있어요."
	return ""

static func budget(main: Node, hero_id: String) -> int:
	# Read the actual level, never the practice-only effective combat level.
	var actual: Dictionary = main.hero_progress.get(hero_id, {})
	var level: int = clampi(int(actual.get("level", 1)), 1, main.MAX_HERO_LEVEL)
	return clampi(int((level - 1) / 3.0), 0, 30)

static func current(main: Node, hero_id: String) -> Dictionary:
	var raw: Dictionary = main.hero_skill_tree.get(hero_id, {})
	return {"offense": int(raw.get("offense", 0)), "survival": int(raw.get("survival", 0)), "utility": int(raw.get("utility", 0))}

static func fingerprint(main: Node, hero_id: String) -> String:
	var view: int = main.content_root.get_instance_id() if is_instance_valid(main.content_root) else 0
	return JSON.stringify([str(main.selected_faction), hero_id, main.hero_progress.get(hero_id, {}),
		main.hero_skill_tree.get(hero_id, {}), main.idle_stage, main._deployed_hero_ids(),
		main.hero_equipment_items, main.guardian_equipped, main.hero_ascension, main.hero_breakthrough,
		main.PRESETS.fingerprint(main, 0), str(main.active_screen), view, int(main.get_meta("research_revision", 0))]).sha256_text()

static func preview(main: Node, hero_id: String, draft: Dictionary) -> Dictionary:
	var error: String = entry_error(main, hero_id)
	if not error.is_empty(): return {"ok": false, "reason": error}
	if draft.size() != 3: return {"ok": false, "reason": "공격·생존·기능 세 분야를 확인해 주세요."}
	var total: int = 0
	for branch: String in BRANCHES:
		if not draft.has(branch) or typeof(draft[branch]) != TYPE_INT or int(draft[branch]) < 0 or int(draft[branch]) > 10:
			return {"ok": false, "reason": "각 분야는 정수 0~10단계만 지정할 수 있어요."}
		total += int(draft[branch])
	var earned: int = budget(main, hero_id)
	if total > earned: return {"ok": false, "reason": "획득한 연구 포인트 %d P를 초과했어요." % earned}
	var before: Dictionary = current(main, hero_id)
	return {"ok": true, "reason": "총 획득 포인트 유지 · 비용 0 · 확인 전에는 반영하지 않음",
		"before": before, "after": draft.duplicate(true), "budget": earned,
		"spent": total, "available": earned - total, "changed": before != draft,
		"token": fingerprint(main, hero_id)}

static func apply(main: Node, hero_id: String, draft: Dictionary, expected: String) -> Dictionary:
	# A mandatory token rejects double-taps and callbacks from an older view.
	if expected.is_empty() or expected != fingerprint(main, hero_id):
		return {"ok": false, "reason": "영웅·성장·화면이 바뀌었어요. 다시 미리보기 해 주세요."}
	var proposal: Dictionary = preview(main, hero_id, draft)
	if not bool(proposal.get("ok", false)): return proposal
	if not bool(proposal["changed"]): return {"ok": false, "reason": "현재 연구 배분과 같아요."}
	main.hero_skill_tree[hero_id] = proposal["after"].duplicate(true)
	main.set_meta("research_revision", int(main.get_meta("research_revision", 0)) + 1)
	main._refresh_growth_runtime()
	main._save_idle_state()
	SAFETY.observe(main)
	return {"ok": not SAFETY.pending(main), "applied": true,
		"reason": "연구 재배분 완료 · 남은 %d P%s" % [proposal["available"], " · 저장 대기, 다시 저장해 주세요" if SAFETY.pending(main) else ""]}
