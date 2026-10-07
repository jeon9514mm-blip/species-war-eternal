extends RefCounted
## A guardian has one fixed rarity and visible, deterministic bonuses. Only the
## equipped guardian contributes; duplicates raise a capped resonance level.
const TIERS := ["고급", "희귀", "에픽", "전설", "신화"]
const WEIGHTS := [55, 27, 12, 5, 1] # 100% in total, before pity.
const SUMMON_COST := 80
const LEGENDARY_PITY := 30
const MYTHIC_PITY := 80
const DEFINITIONS := {
	"lumi": {"name":"빛의 여우 루미", "tier":"고급", "kind":"support", "interval":1.85, "symbol":"✦", "description":"빛탄과 위기 아군 회복", "bonuses":{"online_xp":0.04,"offline_xp":0.04}},
	"umbra": {"name":"그림자 늑대 움브라", "tier":"고급", "kind":"assault", "interval":1.65, "symbol":"☾", "description":"그림자 물어뜯기와 흡혈", "bonuses":{"online_gold":0.04,"offline_gold":0.04}},
	"moss": {"name":"고목의 수호신 베르", "tier":"희귀", "kind":"support", "interval":1.80, "symbol":"❖", "description":"수풀의 가호와 회복", "bonuses":{"item_drop":0.08,"attack":0.025}},
	"tide": {"name":"물결의 수호신 네리", "tier":"희귀", "kind":"support", "interval":1.78, "symbol":"◈", "description":"물결의 빛과 보호", "bonuses":{"online_gold":0.07,"offline_xp":0.07}},
	"thunder": {"name":"뇌광의 수호신 카인", "tier":"에픽", "kind":"assault", "interval":1.58, "symbol":"ϟ", "description":"번개 추격과 연쇄 타격", "bonuses":{"attack":0.065,"crit":0.025,"item_drop":0.06}},
	"dawn": {"name":"여명의 수호신 아린", "tier":"에픽", "kind":"support", "interval":1.72, "symbol":"☼", "description":"여명 치유와 영혼의 빛", "bonuses":{"online_xp":0.09,"offline_xp":0.09,"item_drop":0.10}},
	"phoenix": {"name":"태양의 수호신 화린", "tier":"전설", "kind":"assault", "interval":1.55, "symbol":"✹", "description":"불꽃의 날개로 전장 강타", "bonuses":{"online_gold":0.12,"offline_gold":0.12,"attack":0.09,"crit":0.04}},
	"leviathan": {"name":"심연의 수호신 라그", "tier":"전설", "kind":"assault", "interval":1.53, "symbol":"◆", "description":"깊은 바다의 추격과 포식", "bonuses":{"item_drop":0.16,"attack":0.10,"offline_xp":0.10,"crit":0.04}},
	"origin": {"name":"시원의 수호신 아르카", "tier":"신화", "kind":"support", "interval":1.48, "symbol":"✧", "description":"시원의 빛으로 원정대 보호", "bonuses":{"online_gold":0.16,"offline_gold":0.16,"online_xp":0.16,"offline_xp":0.16,"item_drop":0.18,"attack":0.12,"crit":0.06}},
	"eclipse": {"name":"월식의 수호신 녹티스", "tier":"신화", "kind":"assault", "interval":1.45, "symbol":"◉", "description":"달의 그림자로 적을 압박", "bonuses":{"online_gold":0.13,"offline_gold":0.13,"online_xp":0.13,"offline_xp":0.13,"item_drop":0.22,"attack":0.15,"crit":0.07}},
}
const BONUS_NAMES := {"online_gold":"온라인 골드", "offline_gold":"오프라인 골드", "online_xp":"온라인 경험치", "offline_xp":"오프라인 경험치", "item_drop":"장비 획득률", "attack":"공격력", "crit":"치명타 확률"}

static func starter(faction: String) -> String:
	return "lumi" if faction == "aurelia" else ("umbra" if faction == "noxfera" else "")

static func profile(id: String) -> Dictionary:
	return (DEFINITIONS.get(id, {}) as Dictionary).duplicate(true)

static func tier_index(tier: String) -> int:
	return TIERS.find(tier)

static func tier_color(tier: String) -> Color:
	return {"고급":Color("#8db6b7"),"희귀":Color("#61a9fa"),"에픽":Color("#bd8cff"),"전설":Color("#ffca76"),"신화":Color("#ff8fbc")}.get(tier,Color.WHITE)

static func resonance(copies: int) -> int:
	return mini(3, 1 + maxi(0,copies-1) / 3)

static func bonus(profile_data: Dictionary, copies: int, key: String) -> float:
	var base := float((profile_data.get("bonuses", {}) as Dictionary).get(key, 0.0))
	return base * (1.0 + float(resonance(copies)-1) * 0.10)

static func bonus_text(profile_data: Dictionary, copies: int) -> String:
	var result: Array[String] = []
	for key in BONUS_NAMES:
		var value := bonus(profile_data,copies,key)
		if value > 0.0: result.append("%s +%.1f%%" % [BONUS_NAMES[key],value*100.0])
	return " · ".join(result)

static func draw_id(rng: RandomNumberGenerator, mythic_pity: int, legendary_pity: int) -> String:
	var tier_index_value := -1
	if mythic_pity >= MYTHIC_PITY - 1:
		tier_index_value = 4
	elif legendary_pity >= LEGENDARY_PITY - 1:
		tier_index_value = 3
	else:
		var roll := rng.randi_range(1,100)
		for index in WEIGHTS.size():
			roll -= int(WEIGHTS[index])
			if roll <= 0:
				tier_index_value = index
				break
	var options: Array[String] = []
	for id in DEFINITIONS:
		if str(DEFINITIONS[id]["tier"]) == TIERS[tier_index_value]:options.append(id)
	return options[rng.randi_range(0,options.size()-1)]
