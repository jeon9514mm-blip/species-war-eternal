extends RefCounted
## v83-2: observation only. No wallet, RNG, saves, stats or combat decisions.
## At most 10 actors and one wave of HP baselines are retained per session.
const CATALOG = preload("res://scripts/HeroRosterCatalog.gd")
const MAX_TOTAL: int = 1000000000000
var actors: Dictionary = {}
var _slots: Dictionary = {}
var _target_hp: Dictionary = {}
var _wave: int = -1
var _closed: bool = false
var total_damage: int = 0
var support_damage: int = 0
var unknown_damage: int = 0
var critical_hits: int = 0
var opening: Dictionary = {}

static func capabilities(roster: Array) -> Dictionary:
	var summary: Dictionary = {"size": 0, "tank": 0, "damage": 0, "support": 0, "control": 0, "heal": 0}
	var seen: Dictionary = {}
	for value in roster:
		if not value is Dictionary: continue
		var id: String = str(value.get("id", ""))
		var hero: Dictionary = CATALOG.hero(id)
		if hero.is_empty() or seen.has(id) or seen.size() >= 10: continue
		seen[id] = true
		summary["size"] += 1
		match str(hero.get("role_group", "")):
			"탱커": summary["tank"] += 1
			"딜러": summary["damage"] += 1
			"서포터": summary["support"] += 1
			"컨트롤러": summary["control"] += 1
		var heals: bool = false
		for skill in hero.get("skills", []):
			# Self lifesteal is not an allied healing capability.
			if (str(skill.get("kind", "")) == "heal" and not bool(skill.get("self_only", false))) or str(skill.get("action", "")) == "ally_heal":
				heals = true
		if heals: summary["heal"] += 1
	return summary

func begin(roster: Array, states: Dictionary, auto_skills: bool, auto_ultimates: bool) -> void:
	actors.clear(); _slots.clear(); _target_hp.clear()
	_wave = -1; _closed = false
	total_damage = 0; support_damage = 0; unknown_damage = 0; critical_hits = 0
	opening = capabilities(roster)
	opening["skill_auto"] = auto_skills
	opening["ultimate_auto"] = auto_ultimates
	for value in roster:
		if not value is Dictionary or actors.size() >= 10: continue
		var id: String = str(value.get("id", ""))
		if id.is_empty() or actors.has(id) or not states.has(id): continue
		var state: Dictionary = states[id]
		var slot: int = int(state.get("slot", -1))
		if slot < 0 or _slots.has(slot): continue
		actors[id] = {"id": id, "name": str(value.get("name", id)), "slot": slot,
			"role": str(state.get("role_group", value.get("role_group", ""))),
			"max_hp": maxi(1, int(state.get("max_hp", 1))), "hp": maxi(0, int(state.get("hp", 0))),
			"damage": 0, "damage_taken": 0, "healing_received": 0, "shield_absorbed": 0,
			"hits": 0, "criticals": 0, "kills": 0, "first_down_at": -1.0}
		_slots[slot] = id

func begin_wave(token: int, enemies: Array) -> void:
	if _closed or token < 0 or token == _wave: return
	_wave = token
	_target_hp.clear()
	for value in enemies:
		if not value is Dictionary: continue
		var id: String = str(value.get("id", ""))
		var hp: int = int(value.get("hp", 0))
		if not id.is_empty() and hp > 0: _target_hp[id] = hp

func damage(token: int, enemy_id: String, before: int, after: int, source_slot: int, critical: bool) -> int:
	if _closed or token != _wave or not _target_hp.has(enemy_id) or before <= 0 or after < 0 or after >= before:
		return 0
	var lowest: int = int(_target_hp[enemy_id])
	var amount: int = mini(maxi(0, mini(lowest, before) - after), MAX_TOTAL - total_damage)
	_target_hp[enemy_id] = mini(lowest, after)
	if amount <= 0: return 0
	total_damage += amount
	if critical: critical_hits += 1
	if _slots.has(source_slot):
		var actor: Dictionary = actors[_slots[source_slot]]
		actor["damage"] += amount; actor["hits"] += 1
		if critical: actor["criticals"] += 1
		if after == 0: actor["kills"] += 1
	elif source_slot == -1:
		support_damage += amount
	else:
		unknown_damage += amount
	return amount

func incoming(id: String, before: int, after: int, absorbed: int, elapsed: float) -> void:
	if _closed or not actors.has(id) or before <= 0 or after < 0 or after > before: return
	var actor: Dictionary = actors[id]
	actor["damage_taken"] = mini(MAX_TOTAL, int(actor["damage_taken"]) + before - after)
	actor["shield_absorbed"] = mini(MAX_TOTAL, int(actor["shield_absorbed"]) + maxi(0, absorbed))
	actor["hp"] = after
	if after == 0 and float(actor["first_down_at"]) < 0.0:
		actor["first_down_at"] = maxf(0.0, elapsed) if is_finite(elapsed) else 0.0

func healed(id: String, amount: int, hp: int) -> void:
	if _closed or not actors.has(id) or amount <= 0: return
	var actor: Dictionary = actors[id]
	actor["healing_received"] = mini(MAX_TOTAL, int(actor["healing_received"]) + amount)
	actor["hp"] = maxi(0, hp)

func snapshot(meta: Dictionary, states: Dictionary) -> Dictionary:
	if actors.is_empty(): return {}
	_closed = true
	var report: Dictionary = meta.duplicate(true)
	var seconds: float = maxf(0.0, float(meta.get("elapsed", 0.0)))
	if not is_finite(seconds): seconds = 0.0
	var rows: Array = actors.values().duplicate(true)
	var alive: int = 0
	for row in rows:
		var state: Dictionary = states.get(str(row["id"]), {})
		row["hp"] = maxi(0, int(state.get("hp", row["hp"])))
		if int(row["hp"]) > 0: alive += 1
		row["dps"] = float(row["damage"]) / seconds if seconds > 0.0 else 0.0
		row["share"] = float(row["damage"]) / float(total_damage) if total_damage > 0 else 0.0
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["slot"]) < int(b["slot"]) if a["damage"] == b["damage"] else a["damage"] > b["damage"])
	report.merge({"elapsed": seconds, "actors": rows, "total_damage": total_damage,
		"support_damage": support_damage, "unknown_damage": unknown_damage,
		"dps": float(total_damage) / seconds if seconds > 0.0 else 0.0,
		"alive": alive, "opening": opening.duplicate(true)}, true)
	report["advice"] = advice(report)
	return report

static func advice(report: Dictionary) -> Array:
	var tips: Array = []
	var reason: String = str(report.get("reason", ""))
	if reason in ["left_screen", "context_changed"]:
		return [{"text": "중도 이탈·조건 변경 기록입니다. 정상 완료한 도전과 성능을 비교하지 않아요.", "action": "none", "hero_id": ""}]
	var start: Dictionary = report.get("opening", {})
	if not bool(start.get("skill_auto", true)) or not bool(start.get("ultimate_auto", true)):
		tips.append({"text": "입장 시 자동 스킬 또는 자동 궁극기가 꺼져 있었어요. 수동 운용 의도가 아니라면 출전 전 설정을 확인하세요.", "action": "formation", "hero_id": ""})
	var first: Dictionary = {}
	for row in report.get("actors", []):
		var at: float = float(row.get("first_down_at", -1.0))
		if at >= 0.0 and (first.is_empty() or at < float(first["first_down_at"])): first = row
	if not first.is_empty():
		tips.append({"text": "%s이(가) %.1f초에 먼저 쓰러졌어요. 장비·생존 연구·전열 배치를 점검해 보세요." % [first["name"], first["first_down_at"]], "action": "growth", "hero_id": str(first["id"])})
	elif reason == "timeout":
		tips.append({"text": "생존 영웅이 남았지만 제한시간 안에 목표를 마치지 못했어요. 공격 성장과 딜러·제어 조합을 점검해 보세요.", "action": "formation", "hero_id": ""})
	if int(start.get("tank", 0)) == 0:
		tips.append({"text": "출전 탱커가 없었어요. 전열이 버티기 어렵다면 보유 탱커를 넣어 비교해 보세요. 필수 편성은 아니에요.", "action": "formation", "hero_id": ""})
	elif int(start.get("heal", 0)) == 0 and (reason in ["party_defeated", "timeout"] or str(report.get("mode", "")) == "weekly"):
		tips.append({"text": "아군 회복 스킬 보유 영웅이 없었어요. 장기전 생존이 부족할 때 회복형 영웅을 시험해 보세요. 자가흡혈은 별도예요.", "action": "formation", "hero_id": ""})
	if tips.is_empty():
		tips.append({"text": "아래 피해·피격·받은 회복을 함께 보고 조합을 비교하세요. 피해 순위만으로 탱커나 서포터의 가치를 판단하지 않아요.", "action": "formation", "hero_id": ""})
	if tips.size() > 3: tips.resize(3)
	return tips

static func comparison_key(report: Dictionary) -> String:
	var entry: Dictionary = report.get("entry", {})
	return JSON.stringify([report.get("pattern", {}).get("id", ""), report.get("pattern", {}).get("version", 0), report.get("practice", false), report.get("mode", ""), report.get("variant", ""), entry.get("faction", ""), entry.get("zone", ""),
		entry.get("floor", -1) if str(report.get("mode", "")) == "tower" else (entry.get("run_index", -1) if str(report.get("mode", "")) == "daily" else 0),
		entry.get("week", "") if str(report.get("mode", "")) == "weekly" else "",
		entry.get("level_mode", "actual") if bool(report.get("practice", false)) else "actual",
		entry.get("match_level", 0) if bool(report.get("practice", false)) and str(entry.get("level_mode", "actual")) == "matched" else 0])
