extends RefCounted
class_name HeroCombatRules

# Shared active-skill source for UI, field combat, and raid adapters.
const SKILLS := {
		"leonhardt": {"role_group": "탱커", "skill": "철벽 방패", "cooldown": 4.0, "effect": "받는 피해 감소", "kind": "guard", "value": 0.0, "duration": 2.4},
		"mira": {"role_group": "딜러", "skill": "정밀 사격", "cooldown": 3.0, "effect": "강력한 단일 피해", "kind": "damage", "value": 2.2},
		"elisia": {"role_group": "서포터", "skill": "숲의 치유", "cooldown": 5.0, "effect": "원정대 회복", "kind": "heal", "value": 0.22, "threshold": 0.72},
		"kairen": {"role_group": "컨트롤러", "skill": "별빛 속박", "cooldown": 5.0, "effect": "적 공격력 감소", "kind": "weaken", "value": 0.0, "duration": 3.0},
		"orwin": {"role_group": "탱커", "skill": "황금 방진", "cooldown": 5.0, "effect": "원정대 피해 경감", "kind": "guard", "value": 0.0, "duration": 3.0},
		"seria": {"role_group": "딜러", "skill": "질풍 연사", "cooldown": 2.8, "effect": "빠른 연속 피해", "kind": "damage", "value": 1.75},
		"astel": {"role_group": "서포터", "skill": "새벽의 찬가", "cooldown": 4.2, "effect": "원정대 회복", "kind": "heal", "value": 0.16, "threshold": 0.78},
		"darius": {"role_group": "딜러", "skill": "왕국 처단", "cooldown": 4.0, "effect": "강력한 처형 피해", "kind": "damage", "value": 2.6},
		"lunea": {"role_group": "컨트롤러", "skill": "안개 봉인", "cooldown": 5.0, "effect": "적 공격력 감소", "kind": "weaken", "value": 0.0, "duration": 3.5},
		"caelum": {"role_group": "딜러", "skill": "태양검 낙하", "cooldown": 3.4, "effect": "태양 속성 피해", "kind": "damage", "value": 2.0},
		"valeria": {"role_group": "딜러", "skill": "혈월 베기", "cooldown": 3.0, "effect": "피해와 흡혈", "kind": "lifesteal", "value": 1.9, "lifesteal": 0.14},
		"morgas": {"role_group": "서포터", "skill": "핏빛 저주", "cooldown": 4.0, "effect": "적 방어 약화", "kind": "vulnerable", "value": 0.0, "duration": 3.0},
		"ragna": {"role_group": "딜러", "skill": "달빛 돌진", "cooldown": 3.0, "effect": "연속 피해", "kind": "damage", "value": 1.8},
		"bron": {"role_group": "탱커", "skill": "대지 분쇄", "cooldown": 4.0, "effect": "피해와 기절", "kind": "stun", "value": 1.4, "duration": 0.65},
		"nyx": {"role_group": "컨트롤러", "skill": "밤의 낙인", "cooldown": 4.5, "effect": "적 방어 약화", "kind": "vulnerable", "value": 0.0, "duration": 2.8},
		"fenris": {"role_group": "딜러", "skill": "회색 발톱", "cooldown": 2.7, "effect": "빠른 연속 피해", "kind": "damage", "value": 1.7},
		"isolde": {"role_group": "서포터", "skill": "붉은 성찬", "cooldown": 4.4, "effect": "원정대 회복", "kind": "heal", "value": 0.17, "threshold": 0.78},
		"garm": {"role_group": "탱커", "skill": "철갑 포효", "cooldown": 5.0, "effect": "원정대 피해 경감", "kind": "guard", "value": 0.0, "duration": 2.8},
		"veyra": {"role_group": "딜러", "skill": "그림자 흡혈검", "cooldown": 3.4, "effect": "치명 피해와 흡혈", "kind": "lifesteal", "value": 2.15, "lifesteal": 0.09},
		"ulric": {"role_group": "컨트롤러", "skill": "월식 강습", "cooldown": 3.8, "effect": "피해와 기절", "kind": "stun", "value": 1.65, "duration": 0.5}
	}

# Modifiers describe mechanics, not merely different coefficients for the same hit.
const SPECIALIZATIONS := {
	"leonhardt": {"guard_scope":"self", "effect":"자신 피해 감소 52% · 도발"},
	"mira": {"elite_bonus":1.20, "effect":"단일 피해 · 정예에게 20% 추가 피해"},
	"elisia": {"heal_targets":1, "emergency_threshold":0.35, "emergency_bonus":1.35, "effect":"최저 체력 아군 치유 · HP 35% 이하 치유량 35% 증가"},
	"kairen": {"kind":"stun", "value":0.65, "duration":0.80, "aoe":true, "max_targets":2, "effect":"사거리 안 적 최대 2명 피해 · 기절"},
	"orwin": {"guard_scope":"party", "duration":1.8, "effect":"살아 있는 아군 전원 피해 감소 52%"},
	"seria": {"hits":3, "effect":"단일 3연사 · 대상 처치 시 남은 타격 재선택"},
	"astel": {"heal_targets":10, "heal_scale":0.62, "effect":"살아 있는 아군 전원 회복"},
	"darius": {"value":2.1, "execute_threshold":0.35, "execute_bonus":1.6, "effect":"단일 피해 · 적 HP 35% 이하 피해 60% 증가"},
	"lunea": {"aoe":true, "effect":"사거리 안 적 전체 공격 피해 35% 감소"},
	"caelum": {"aoe":true, "aoe_scale":0.68, "effect":"사거리 안 적 전체 태양검 피해"},
	"valeria": {"low_hp_threshold":0.50, "low_hp_sustain_bonus":1.6, "effect":"단일 피해·흡혈 · 자신 HP 50% 이하 흡혈량 60% 증가"},
	"morgas": {"ultimate_role":"컨트롤러", "effect":"단일 적 받는 피해 25% 증가 · 궁극기는 광역 저주"},
	"ragna": {"aoe":true, "max_targets":3, "aoe_scale":0.72, "effect":"사거리 안 적 최대 3명에게 돌진 피해"},
	"bron": {"aoe":true, "max_targets":3, "aoe_scale":0.72, "self_guard":1.0, "effect":"사거리 안 최대 3명 피해·기절 · 자신 1초 피해 감소"},
	"nyx": {"aoe":true, "max_targets":3, "effect":"사거리 안 적 최대 3명 받는 피해 25% 증가"},
	"fenris": {"hits":4, "extra_ultimate":5.0, "effect":"단일 4연격 · 추가 궁극기 충전 5"},
	"isolde": {"heal_targets":2, "heal_scale":0.70, "effect":"체력 비율이 낮은 아군 최대 2명 회복"},
	"garm": {"guard_scope":"self", "self_heal":0.08, "effect":"자신 피해 감소 52%·도발 · 최대 HP 8% 회복"},
	"veyra": {"execute_threshold":0.40, "execute_bonus":1.45, "effect":"피해·흡혈 · 적 HP 40% 이하 피해 45% 증가"},
	"ulric": {"aoe":false, "self_guard":0.65, "effect":"단일 돌진 피해·기절 · 자신 0.65초 피해 감소"}
}

static func skill_profile(hero_id: String) -> Dictionary:
	var data := preload("res://scripts/HeroRosterCatalog.gd").skill(hero_id, "a1")
	return data if not data.is_empty() else {"role_group":"딜러", "skill":"기본 공격", "cooldown":4.0, "effect":"추가 피해", "kind":"damage", "value":1.2}

static func adjusted_profile(hero_id: String, identity: Dictionary, tree: Dictionary) -> Dictionary:
	var result := skill_profile(hero_id)
	result["cooldown"] = maxf(1.2, float(result.get("cooldown", 4.0)) * float(identity.get("skill_cooldown_mult", 1.0)) * (1.0 - float(tree.get("utility", 0)) * 0.03))
	if str(result.get("kind", "damage")) in ["damage", "lifesteal", "stun", "heal"]:
		result["value"] = float(result.get("value", 1.0)) * float(identity.get("skill_value_mult", 1.0))
	if result.has("duration"):
		result["duration"] = float(result["duration"]) * float(identity.get("duration_mult", 1.0))
	if result.has("lifesteal"):
		result["lifesteal"] = float(result["lifesteal"]) * float(identity.get("sustain_mult", 1.0))
	return result

static func hit_damage(profile: Dictionary, attack: int, enemy: Dictionary, scale := 1.0) -> int:
	if int(enemy.get("hp", 0)) <= 0 or attack <= 0:
		return 0
	var multiplier := float(profile.get("value", 1.0)) * maxf(0.0, scale)
	if bool(enemy.get("elite", false)):
		multiplier *= float(profile.get("elite_bonus", 1.0))
	var ratio := float(enemy.get("hp", 0)) / maxf(1.0, float(enemy.get("max_hp", 1)))
	if ratio <= float(profile.get("execute_threshold", -1.0)):
		multiplier *= float(profile.get("execute_bonus", 1.0))
	return maxi(1, int(float(attack) * multiplier))

static func healing_targets(profile: Dictionary, states: Dictionary, alive_ids: Array) -> Array[String]:
	var injured: Array[String] = []
	for id_value in alive_ids:
		var hero_id := str(id_value)
		var state: Dictionary = states.get(hero_id, {})
		if int(state.get("hp", 0)) > 0 and int(state.get("hp", 0)) < int(state.get("max_hp", 1)):
			injured.append(hero_id)
	injured.sort_custom(func(a: String, b: String) -> bool:
		var ratio_a := float(states[a]["hp"]) / maxf(1.0, float(states[a]["max_hp"]))
		var ratio_b := float(states[b]["hp"]) / maxf(1.0, float(states[b]["max_hp"]))
		return ratio_a < ratio_b if not is_equal_approx(ratio_a, ratio_b) else int(states[a].get("slot", 0)) < int(states[b].get("slot", 0))
	)
	injured.resize(mini(injured.size(), maxi(1, int(profile.get("heal_targets", 1)))))
	return injured

static func heal_amount(profile: Dictionary, ally: Dictionary) -> int:
	var ratio := float(ally.get("hp", 0)) / maxf(1.0, float(ally.get("max_hp", 1)))
	var amount := float(ally.get("max_hp", 1)) * float(profile.get("value", 0.18)) * float(profile.get("heal_scale", 1.0))
	if ratio <= float(profile.get("emergency_threshold", -1.0)):
		amount *= float(profile.get("emergency_bonus", 1.0))
	return maxi(1, int(amount))

static func lifesteal_amount(profile: Dictionary, state: Dictionary, actual_damage: int) -> int:
	if actual_damage <= 0:
		return 0
	var ratio := float(state.get("hp", 0)) / maxf(1.0, float(state.get("max_hp", 1)))
	var amount := float(actual_damage) * float(profile.get("lifesteal", 0.10))
	if ratio <= float(profile.get("low_hp_threshold", -1.0)):
		amount *= float(profile.get("low_hp_sustain_bonus", 1.0))
	return maxi(0, int(amount))

static func ultimate_role(hero_id: String, fallback_role: String) -> String:
	return str(SPECIALIZATIONS.get(hero_id, {}).get("ultimate_role", fallback_role))

static func ultimate_status(hero_id: String) -> String:
	return str(preload("res://scripts/HeroRosterCatalog.gd").skill(hero_id, "ultimate").get("kind", "damage"))
