extends RefCounted
## Bounded encounters reusing existing sprites/stats; no reward or save writes.
const VERSION: int = 1
const IDS: Array[String] = ["healing_guard", "charged_strike", "split_pack"]
const LABELS: Dictionary = {"healing_guard": "회복 지원대", "charged_strike": "차단 가능한 강타", "split_pack": "분산 포위"}
const HINTS: Dictionary = {
	"healing_guard": "지원몹 우선 처치 또는 집중 공격 · 우두머리 회복은 지원몹당 최대 3회",
	"charged_strike": "2초 시전 중 기절로 차단 · 방어·회복으로 버티거나 대상이 사거리 밖으로 이탈",
	"split_pack": "분산된 적 · 광역 공격과 후열 보호를 비교하세요"}

static func profile(mode: String, floor_number: int = 0, week: String = "") -> Dictionary:
	var index: int = -1
	if mode == "tower" and floor_number >= 10: index = (floor_number - 10) % IDS.size()
	if mode == "weekly" and not week.is_empty() and week.is_valid_int(): index = posmod(int(week), IDS.size())
	if index < 0: return {}
	var id: String = IDS[index]
	return {"id": id, "version": VERSION, "label": LABELS[id], "hint": HINTS[id]}

static func active(session: ChallengeBattleSession) -> bool:
	if session == null or not session.is_running() or session.pattern.is_empty(): return false
	if session.mode == "tower": return session.cleared_waves == session.required_waves - 1
	# First boss remains the familiar entry encounter; patterns start at boss #2.
	return session.mode == "weekly" and session.cleared_waves >= 1

static func prepare_enemies(session: ChallengeBattleSession, enemies: Array) -> void:
	if not active(session) or enemies.is_empty(): return
	var id: String = str(session.pattern["id"])
	var leader: Dictionary = enemies[0]
	if session.mode == "weekly" and id in ["healing_guard", "split_pack"]:
		# Divide, never add to the original encounter's HP/attack budget.
		var hp_budget: int = int(leader["max_hp"])
		var attack_budget: int = int(leader["attack"])
		var add_hp: int = maxi(1, int(hp_budget * (0.08 if id == "healing_guard" else 0.20)))
		var add_attack: int = maxi(1, int(attack_budget * 0.20))
		leader["hp"] = hp_budget - add_hp * 2; leader["max_hp"] = leader["hp"]
		leader["attack"] = maxi(1, attack_budget - add_attack * 2)
		leader["base_attack"] = leader["attack"]
		for slot in 2:
			var support: bool = id == "healing_guard"
			var name: String = "독버섯 정령" if support else ("수정 거미" if slot == 0 else "달빛 늑대")
			var add: Dictionary = preload("res://scripts/FieldEcology.gd").prepare_enemy({
				"id": str(leader["id"]) + "_guard_" + str(slot), "name": name,
				"hp": add_hp, "max_hp": add_hp, "attack": add_attack,
				"archetype": "support" if support else ("ranged" if slot == 0 else "skirmisher"),
				"row": 2 if support else slot, "elite": false, "challenge_boss": false,
				"attack_remaining": 0.8, "attack_speed_mult": 1.0,
				"challenge_attack_rate": float(leader.get("challenge_attack_rate", 1.0))}, 1, 1, 1)
			enemies.append(add)
	if id == "healing_guard" and enemies.size() > 1:
		var first: int = 1 if session.mode == "weekly" else enemies.size() - 1
		for index in range(first, enemies.size()):
			var enemy: Dictionary = enemies[index]
			enemy["name"] = "독버섯 정령"; enemy["archetype"] = "support"; enemy["row"] = 2
			enemy["challenge_pattern_role"] = "healer"; enemy["pattern_heals_left"] = 3
			enemy["pattern_cooldown"] = 4.0; enemy["pattern_leader_id"] = str(leader["id"])
	elif id == "charged_strike":
		leader["challenge_pattern_role"] = "charger"
		leader["pattern_cooldown"] = 5.0; leader["pattern_cast_remaining"] = 0.0
	elif id == "split_pack":
		for enemy in enemies: enemy["challenge_pattern_role"] = "split"

static func spread_positions(session: ChallengeBattleSession, roam: RoamingHuntDirector) -> void:
	if not active(session) or str(session.pattern.get("id", "")) != "split_pack" or roam.enemy_positions.is_empty(): return
	var origin: Vector2 = roam.enemy_positions[0]
	var offsets: Array[Vector2] = [Vector2(-1.4, 0), Vector2(1.3, -1.6), Vector2(1.3, 1.6), Vector2(-1.4, 1.8)]
	for index in roam.enemy_positions.size():
		var candidate: Vector2 = roam._clamp_field(origin + offsets[index % offsets.size()])
		if roam.field_navigation != null and not roam.field_navigation.has_clear_path(origin, candidate): continue
		# Reject a projected point too close to another assigned combatant.
		var clear: bool = true
		for previous in index:
			if candidate.distance_to(roam.enemy_positions[previous]) < 0.8: clear = false
		if not clear: continue
		roam.enemy_positions[index] = candidate; roam.enemy_home_positions[index] = candidate
		roam.enemy_wander_targets[index] = candidate
	# Retain one aggro pack; separation is positional, not off-map reinforcements.
