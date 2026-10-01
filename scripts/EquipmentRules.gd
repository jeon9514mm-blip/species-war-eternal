class_name EquipmentRules
extends RefCounted

## Shared, local equipment rules. Normalization validates saved data; it does not
## replace an authoritative server when player-to-player trading is introduced.
const SLOTS := ["weapon", "armor", "accessory"]
const RARITIES := ["일반", "희귀", "전설"]
const HUNT_ROLES := ["dealer", "defender", "support"]
const HUNT_ROLE_NAMES := {"dealer": "딜러", "defender": "방어", "support": "보조"}
const HUNT_ROLE_STATS := {"dealer": "attack_pct", "defender": "hp_pct", "support": "ultimate_pct"}
const SETS := ["초보자", "개척자", "강철", "월광", "새벽의 맹약", "철벽의 맹세", "월식의 추격"]
const STAT_RANGES := {
	"attack_pct": Vector2i(2, 6), "hp_pct": Vector2i(3, 8),
	"defense": Vector2i(1, 4), "haste_pct": Vector2i(1, 3),
	"ultimate_pct": Vector2i(2, 5),
}
const STAT_CAPS := {"attack_pct": 24, "hp_pct": 30, "defense": 18, "haste_pct": 12, "ultimate_pct": 18}
const STAT_NAMES := {"attack_pct": "공격력", "hp_pct": "체력", "defense": "방어력", "haste_pct": "공격 속도", "ultimate_pct": "궁극기 충전"}
const FAMILIES := {
	"assault": ["attack_pct", "ultimate_pct"],
	"guard": ["hp_pct", "defense"],
	"flow": ["haste_pct", "ultimate_pct"],
}
const ZONES := {
	"gray_meadow": {"name": preload("res://scripts/ZoneCatalog.gd").MEADOW_NAME, "set": "개척자", "raid_set": "새벽의 맹약", "prefix": "초원"},
	"forgotten_mine": {"name": preload("res://scripts/ZoneCatalog.gd").MINE_NAME, "set": "강철", "raid_set": "철벽의 맹세", "prefix": "광맥"},
	"moonrest_forest": {"name": preload("res://scripts/ZoneCatalog.gd").FOREST_NAME, "set": "월광", "raid_set": "월식의 추격", "prefix": "달잠"},
}

static func _integer(value: Variant, fallback: int, minimum: int, maximum: int) -> int:
	if typeof(value) not in [TYPE_INT, TYPE_FLOAT]:
		return fallback
	if not is_finite(float(value)):
		return fallback
	return int(clampf(float(value), float(minimum), float(maximum)))

static func _string(value: Variant, fallback: String, limit: int = 96) -> String:
	if typeof(value) != TYPE_STRING:
		return fallback
	return String(value).strip_edges().left(limit)

static func _boolean(value: Variant, fallback: bool = false) -> bool:
	return bool(value) if typeof(value) == TYPE_BOOL else fallback

static func _new_id() -> String:
	return "gear_" + Crypto.new().generate_random_bytes(16).hex_encode()

static func option_capacity(item: Dictionary) -> int:
	if item.get("item_type", "equipment") == "option_crystal":
		return 0
	return int({"일반": 1, "희귀": 2, "전설": 3}.get(_string(item.get("rarity"), "일반"), 1))

static func _affix(raw: Variant) -> Dictionary:
	if not raw is Dictionary:
		return {}
	var stat := _string(raw.get("stat"), "")
	if not STAT_RANGES.has(stat):
		return {}
	var value: Variant = raw.get("value")
	if typeof(value) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(value)) or float(value) <= 0.0:
		return {}
	var bounds: Vector2i = STAT_RANGES[stat]
	var affix := {"stat": stat, "value": _integer(value, bounds.x, bounds.x, bounds.y)}
	if _integer(raw.get("trade_count"), 0, 0, 1) == 1:
		affix["trade_count"] = 1
	return affix

static func normalize(raw: Dictionary) -> Dictionary:
	var item_type := _string(raw.get("item_type", "equipment"), "")
	if item_type not in ["equipment", "option_crystal"]:
		return {}
	var slot := _string(raw.get("slot", "weapon"), "")
	if slot not in SLOTS:
		return {}
	var rarity := _string(raw.get("rarity"), "일반")
	if rarity not in RARITIES:
		rarity = "일반"
	var set_name := _string(raw.get("set"), "초보자")
	if set_name not in SETS:
		set_name = "초보자"
	var origin := _string(raw.get("origin"), "legacy")
	if origin not in ["legacy", "hunt", "raid"]:
		origin = "legacy"
	var hunt_role := _string(raw.get("hunt_role"), "", 16)
	if origin != "hunt" or hunt_role not in HUNT_ROLES:
		hunt_role = ""
	var item_id := _string(raw.get("id"), "", 160)
	if item_id.is_empty():
		item_id = _new_id()
	var item := {
		"id": item_id, "item_type": item_type, "slot": slot, "level": _integer(raw.get("level"), 1, 1, 10),
		"rarity": rarity, "name": _string(raw.get("name"), "미확인 장비"),
		"set": set_name, "zone": _string(raw.get("zone"), "알 수 없는 지역"),
		"origin": origin, "source_id": _string(raw.get("source_id"), "", 64), "hunt_role": hunt_role,
		"bound": _boolean(raw.get("bound")), "locked": _boolean(raw.get("locked")),
		"trade_count": _integer(raw.get("trade_count"), 0, 0, 1),
		"affixes": [], "focus": _integer(raw.get("focus"), 0, 0, 3), "proposal": {},
	}
	var base := int({"weapon": 22, "armor": 16, "accessory": 12}[slot])
	var multiplier := float({"일반": 1.0, "희귀": 1.45, "전설": 2.2}[rarity])
	item["power"] = int(int(item["level"]) * base * multiplier)
	if item_type == "option_crystal":
		var stored_option := _affix(raw.get("stored_option"))
		if stored_option.is_empty():
			return {}
		var bounds: Vector2i = STAT_RANGES[stored_option["stat"]]
		item["slot"] = "accessory"
		item["level"] = 1
		item["power"] = 0
		item["set"] = "초보자"
		item["rarity"] = "전설" if int(stored_option["value"]) == bounds.y else "희귀"
		item["name"] = "%s 옵션 결정" % STAT_NAMES[stored_option["stat"]]
		item["stored_option"] = stored_option
		item["focus"] = 0
		if int(item["trade_count"]) == 1 or int(stored_option.get("trade_count", 0)) == 1:
			item["trade_count"] = 1
			item["bound"] = true
		return item
	var used: Dictionary = {}
	var raw_affixes: Variant = raw.get("affixes", [])
	if raw_affixes is Array:
		for entry in raw_affixes:
			var affix := _affix(entry)
			if affix.is_empty() or used.has(affix["stat"]):
				continue
			item["affixes"].append(affix)
			used[affix["stat"]] = true
			if item["affixes"].size() >= option_capacity(item):
				break
	var raw_proposal: Variant = raw.get("proposal", {})
	if raw_proposal is Dictionary and item["affixes"].size() < option_capacity(item):
		var family := _string(raw_proposal.get("family"), "")
		var options: Array = []
		var raw_options: Variant = raw_proposal.get("options", [])
		if FAMILIES.has(family) and raw_options is Array:
			for entry in raw_options:
				var affix := _affix(entry)
				if affix.is_empty() or used.has(affix["stat"]) or affix["stat"] not in FAMILIES[family]:
					continue
				options.append(affix)
				used[affix["stat"]] = true
				if options.size() == 2:
					break
		if not options.is_empty():
			item["proposal"] = {"family": family, "options": options, "cost": 12 + 8 * item["affixes"].size()}
	return item

static func _zone_id(zone: Variant) -> String:
	if zone is String and ZONES.has(zone):
		return zone
	if zone is Dictionary:
		for key in ["id", "source_id"]:
			var candidate := _string(zone.get(key), "")
			if ZONES.has(candidate):
				return candidate
		for key in ZONES:
			if _string(zone.get("name"), "") == ZONES[key]["name"] or _string(zone.get("equipment_set"), "") == ZONES[key]["set"]:
				return key
	return "gray_meadow"

static func hunt_item(zone: Variant, slot: String, rarity: String, _rng: RandomNumberGenerator, hunt_role: String = "") -> Dictionary:
	if slot not in SLOTS:
		return {}
	var source_id := _zone_id(zone)
	var region: Dictionary = ZONES[source_id]
	var quality := rarity if rarity in RARITIES else "일반"
	var role := hunt_role if hunt_role in HUNT_ROLES else ""
	var names := {
		"weapon": {"일반": "사냥검", "희귀": "별의 활", "전설": "성검"},
		"armor": {"일반": "가죽갑옷", "희귀": "비늘갑옷", "전설": "수호갑"},
		"accessory": {"일반": "부적", "희귀": "반지", "전설": "심장석"},
	}
	var affixes: Array=[]
	if not role.is_empty() and quality != "일반":
		var stat: String=HUNT_ROLE_STATS[role]
		var bounds: Vector2i=STAT_RANGES[stat]
		var low: int=bounds.x if quality=="희귀" else maxi(bounds.x,bounds.y-2)
		affixes.append({"stat":stat,"value":_rng.randi_range(low,bounds.y)})
	return normalize({"id": _new_id(), "slot": slot, "rarity": quality, "level": 1,
		"name": "%s %s%s" % [region["prefix"],(HUNT_ROLE_NAMES[role]+" ") if not role.is_empty() else "",names[slot][quality]], "set": region["set"],
		"zone": region["name"], "origin": "hunt", "source_id": source_id,"hunt_role":role,"affixes":affixes})

static func raid_item(zone: Variant, slot: String, rarity: String, _rng: RandomNumberGenerator) -> Dictionary:
	if slot not in SLOTS:
		return {}
	var source_id := _zone_id(zone)
	var region: Dictionary = ZONES[source_id]
	var names := {"weapon": "무기", "armor": "갑옷", "accessory": "인장"}
	return normalize({"id": _new_id(), "slot": slot, "rarity": rarity, "level": 1,
		"name": "%s · %s" % [region["raid_set"], names[slot]], "set": region["raid_set"],
		"zone": region["name"], "origin": "raid", "source_id": source_id})

static func set_profile(sets: Dictionary) -> Dictionary:
	var counts: Dictionary = {}
	for slot in SLOTS:
		var set_name := _string(sets.get(slot), "초보자")
		counts[set_name] = int(counts.get(set_name, 0)) + 1
	var profile := {"attack_mult": 1.0, "hp_mult": 1.0, "defense_bonus": 0, "haste_pct": 0, "ultimate_pct": 0}
	var labels: Array[String] = []
	if int(counts.get("개척자", 0)) >= 2:
		profile["attack_mult"] += 0.05
		labels.append("개척자 2세트 ATK+5%")
	if int(counts.get("개척자", 0)) >= 3:
		profile["hp_mult"] += 0.08
		labels.append("개척자 3세트 HP+8%")
	if int(counts.get("강철", 0)) >= 2:
		profile["hp_mult"] += 0.08
		labels.append("강철 2세트 HP+8%")
	if int(counts.get("강철", 0)) >= 3:
		profile["defense_bonus"] += 5
		labels.append("강철 3세트 DEF+5")
	if int(counts.get("월광", 0)) >= 2:
		profile["attack_mult"] += 0.08
		labels.append("월광 2세트 ATK+8%")
	if int(counts.get("월광", 0)) >= 3:
		profile["attack_mult"] += 0.04
		profile["hp_mult"] += 0.06
		labels.append("월광 3세트 ATK+4%/HP+6%")
	if int(counts.get("새벽의 맹약", 0)) >= 2:
		profile["hp_mult"] += 0.10
		labels.append("새벽의 맹약 2세트 HP+10%")
	if int(counts.get("새벽의 맹약", 0)) >= 3:
		profile["ultimate_pct"] += 8
		labels.append("새벽의 맹약 3세트 궁극기 충전+8%")
	if int(counts.get("철벽의 맹세", 0)) >= 2:
		profile["hp_mult"] += 0.12
		labels.append("철벽의 맹세 2세트 HP+12%")
	if int(counts.get("철벽의 맹세", 0)) >= 3:
		profile["defense_bonus"] += 8
		labels.append("철벽의 맹세 3세트 DEF+8")
	if int(counts.get("월식의 추격", 0)) >= 2:
		profile["attack_mult"] += 0.10
		labels.append("월식의 추격 2세트 ATK+10%")
	if int(counts.get("월식의 추격", 0)) >= 3:
		profile["haste_pct"] += 6
		labels.append("월식의 추격 3세트 공격 속도+6%")
	profile["summary"] = " · ".join(labels) if not labels.is_empty() else "세트 효과 없음"
	return profile

static func affix_profile(items: Array) -> Dictionary:
	var totals := {"attack_pct": 0, "hp_pct": 0, "defense": 0, "haste_pct": 0, "ultimate_pct": 0}
	for raw in items:
		if not raw is Dictionary:
			continue
		var item := normalize(raw)
		if item.get("item_type", "equipment") == "option_crystal":
			continue
		for affix in item.get("affixes", []):
			var stat: String = affix["stat"]
			totals[stat] = mini(int(STAT_CAPS[stat]), int(totals[stat]) + int(affix["value"]))
	return totals

static func stat_text(affix: Dictionary) -> String:
	var entry := _affix(affix)
	if entry.is_empty():
		return ""
	return "%s +%d%s" % [STAT_NAMES[entry["stat"]], entry["value"], "" if entry["stat"] == "defense" else "%"]

static func affix_text(item: Dictionary) -> String:
	var gear := normalize(item)
	if gear.get("item_type", "equipment") == "option_crystal":
		return stat_text(gear["stored_option"])
	var labels: Array[String] = []
	for affix in gear.get("affixes", []):
		labels.append(stat_text(affix))
	return " · ".join(labels) if not labels.is_empty() else "추가 옵션 없음"

static func _quality_fraction(affix: Dictionary) -> float:
	var entry := _affix(affix)
	if entry.is_empty():
		return -1.0
	var bounds: Vector2i = STAT_RANGES[entry["stat"]]
	return float(int(entry["value"]) - bounds.x) / float(maxi(1, bounds.y - bounds.x))

static func _quality_label(fraction: float) -> String:
	if fraction < 0.0:
		return "옵션 없음"
	if fraction >= 1.0:
		return "최상급"
	if fraction >= 0.66:
		return "상급"
	if fraction >= 0.33:
		return "중급"
	return "기본"

static func option_quality_text(affix: Dictionary) -> String:
	return _quality_label(_quality_fraction(affix))

static func quality_text(item: Dictionary) -> String:
	var gear := normalize(item)
	if gear.is_empty():
		return "옵션 없음"
	if gear["item_type"] == "option_crystal":
		return option_quality_text(gear["stored_option"])
	var affixes: Array = gear["affixes"]
	if affixes.is_empty():
		return "옵션 없음"
	var total := 0.0
	for affix in affixes:
		total += _quality_fraction(affix)
	return _quality_label(total / float(affixes.size()))

static func origin_text(item: Dictionary) -> String:
	if item.get("item_type", "equipment") == "option_crystal":
		return "옵션 결정"
	var origin := _string(item.get("origin"), "legacy")
	return str({"hunt": "사냥터 장비", "raid": "레이드 세트 장비", "legacy": "기존 장비"}.get(origin, "기존 장비"))

static func protected(item: Dictionary) -> bool:
	var gear := normalize(item)
	return gear.is_empty() or gear["item_type"] == "option_crystal" or bool(gear["locked"]) or gear["origin"] == "raid" or not gear["affixes"].is_empty() or not gear["proposal"].is_empty()

static func trade_block_reason(item: Dictionary) -> String:
	var gear := normalize(item)
	if gear.is_empty():
		return "올바른 장비가 아닙니다."
	if bool(gear["locked"]):
		return "잠금을 해제한 뒤 거래할 수 있습니다."
	if bool(gear["bound"]) or int(gear["trade_count"]) >= 1:
		return "귀속되었거나 이미 거래한 장비입니다."
	for affix in gear["affixes"]:
		if int(affix.get("trade_count", 0)) >= 1:
			return "구매한 옵션이 담긴 장비는 다시 거래할 수 없습니다."
	if not gear["proposal"].is_empty():
		return "공방에서 옵션 후보를 먼저 선택하거나 포기해 주세요."
	if gear["set"] == "초보자" and gear["item_type"] != "option_crystal":
		return "기본 지급 장비는 거래할 수 없습니다."
	return ""

static func tradable(item: Dictionary) -> bool:
	return trade_block_reason(item).is_empty()
