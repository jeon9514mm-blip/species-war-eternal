class_name EquipmentWorkshop
extends RefCounted

const RULES = preload("res://scripts/EquipmentRules.gd")
const REMOVE_COST := 6
const EXTRACT_COST := 18
const APPLY_CRYSTAL_COST := 8

static func _failure(item: Dictionary, reason: String, balance: int = 0) -> Dictionary:
	return {"ok": false, "reason": reason, "item": item.duplicate(true), "balance": balance, "cost": 0}

static func preview(item: Dictionary, family: String, balance: int, rng: RandomNumberGenerator) -> Dictionary:
	var gear := RULES.normalize(item)
	if gear.is_empty():
		return _failure(item, "올바른 장비가 아닙니다.", balance)
	if gear.get("item_type", "equipment") != "equipment":
		return _failure(item, "옵션 결정에는 새 옵션을 추가할 수 없습니다.", balance)
	if not RULES.FAMILIES.has(family):
		return _failure(item, "옵션 계열을 선택해 주세요.", balance)
	if not gear["proposal"].is_empty():
		return _failure(item, "저장된 후보를 먼저 선택하거나 포기해 주세요.", balance)
	if gear["affixes"].size() >= RULES.option_capacity(gear):
		return _failure(item, "옵션 칸이 가득 찼습니다. 기존 옵션을 삭제해 주세요.", balance)
	var available: Array = RULES.FAMILIES[family].duplicate()
	for affix in gear["affixes"]:
		available.erase(affix["stat"])
	if available.is_empty():
		return _failure(item, "이 계열의 옵션을 이미 모두 보유하고 있습니다.", balance)
	var cost: int = 12 + 8 * gear["affixes"].size()
	if balance < cost:
		return _failure(item, "레이드 정수가 부족합니다. 필요한 정수: %d" % cost, balance)
	if rng == null:
		return _failure(item, "옵션 생성기를 사용할 수 없습니다.", balance)
	var focused := int(gear["focus"]) >= 3
	var options: Array = []
	for stat in available:
		var bounds: Vector2i = RULES.STAT_RANGES[stat]
		var value := bounds.y if focused else rng.randi_range(bounds.x, bounds.y)
		options.append({"stat": stat, "value": value})
	gear["proposal"] = {"family": family, "options": options, "cost": cost}
	if focused:
		gear["focus"] = 0
	return {"ok": true, "reason": "옵션 후보를 저장했습니다. 한 개를 선택해 주세요.", "item": gear, "balance": balance - cost, "cost": cost}

static func choose(item: Dictionary, index: int) -> Dictionary:
	var gear := RULES.normalize(item)
	if gear.is_empty() or gear.get("item_type", "equipment") != "equipment" or gear["proposal"].is_empty():
		return _failure(item, "선택할 옵션 후보가 없습니다.")
	var options: Array = gear["proposal"]["options"]
	if index < 0 or index >= options.size():
		return _failure(item, "유효한 옵션 후보를 선택해 주세요.")
	gear["affixes"].append(options[index].duplicate(true))
	gear["proposal"] = {}
	return {"ok": true, "reason": "장비에 옵션을 추가했습니다.", "item": gear}

static func discard(item: Dictionary) -> Dictionary:
	var gear := RULES.normalize(item)
	if gear.is_empty() or gear.get("item_type", "equipment") != "equipment" or gear["proposal"].is_empty():
		return _failure(item, "포기할 옵션 후보가 없습니다.")
	gear["proposal"] = {}
	return {"ok": true, "reason": "후보를 포기했습니다. 사용한 레이드 정수는 반환되지 않습니다.", "item": gear}

static func remove(item: Dictionary, index: int, balance: int) -> Dictionary:
	var gear := RULES.normalize(item)
	if gear.is_empty():
		return _failure(item, "올바른 장비가 아닙니다.", balance)
	if gear.get("item_type", "equipment") != "equipment":
		return _failure(item, "옵션 결정은 장비에서 삭제하는 옵션이 아닙니다.", balance)
	if not gear["proposal"].is_empty():
		return _failure(item, "저장된 후보를 먼저 선택하거나 포기해 주세요.", balance)
	if index < 0 or index >= gear["affixes"].size():
		return _failure(item, "삭제할 옵션이 없습니다.", balance)
	if balance < REMOVE_COST:
		return _failure(item, "레이드 정수가 부족합니다. 필요한 정수: %d" % REMOVE_COST, balance)
	gear["affixes"].remove_at(index)
	gear["focus"] = mini(3, int(gear["focus"]) + 1)
	return {"ok": true, "reason": "옵션을 삭제하고 집중도를 쌓았습니다.", "item": gear, "balance": balance - REMOVE_COST, "cost": REMOVE_COST}

static func extract(item: Dictionary, index: int, balance: int) -> Dictionary:
	var gear := RULES.normalize(item)
	if gear.is_empty() or gear.get("item_type", "equipment") != "equipment":
		return _failure(item, "장비에서만 옵션을 추출할 수 있습니다.", balance)
	if not gear["proposal"].is_empty():
		return _failure(item, "저장된 후보를 먼저 선택하거나 포기해 주세요.", balance)
	if index < 0 or index >= gear["affixes"].size():
		return _failure(item, "추출할 옵션이 없습니다.", balance)
	if balance < EXTRACT_COST:
		return _failure(item, "레이드 정수가 부족합니다. 필요한 정수: %d" % EXTRACT_COST, balance)
	var option: Dictionary = gear["affixes"][index].duplicate(true)
	var was_traded := int(gear["trade_count"]) == 1 or int(option.get("trade_count", 0)) == 1
	if was_traded:
		option["trade_count"] = 1
	var crystal := RULES.normalize({"item_type": "option_crystal", "slot": "accessory", "stored_option": option,
		"origin": gear["origin"], "source_id": gear["source_id"], "zone": gear["zone"],
		"bound": was_traded, "trade_count": 1 if was_traded else 0})
	gear["affixes"].remove_at(index)
	return {"ok": true, "reason": "수치를 유지한 옵션 결정을 추출했습니다.", "item": gear,
		"crystal": crystal, "balance": balance - EXTRACT_COST, "cost": EXTRACT_COST}

static func apply_crystal(target: Dictionary, crystal: Dictionary, balance: int) -> Dictionary:
	var gear := RULES.normalize(target)
	var source := RULES.normalize(crystal)
	if gear.is_empty() or gear.get("item_type", "equipment") != "equipment":
		return _failure(target, "옵션 결정은 장비에만 이식할 수 있습니다.", balance)
	if source.is_empty() or source.get("item_type", "equipment") != "option_crystal":
		return _failure(target, "유효한 옵션 결정을 선택해 주세요.", balance)
	if bool(source["locked"]):
		return _failure(target, "이식할 옵션 결정의 잠금을 먼저 해제해 주세요.", balance)
	if not gear["proposal"].is_empty():
		return _failure(target, "저장된 후보를 먼저 선택하거나 포기해 주세요.", balance)
	if gear["affixes"].size() >= RULES.option_capacity(gear):
		return _failure(target, "옵션 칸이 가득 찼습니다. 기존 옵션을 삭제해 주세요.", balance)
	var option: Dictionary = source["stored_option"].duplicate(true)
	for affix in gear["affixes"]:
		if affix["stat"] == option["stat"]:
			return _failure(target, "같은 종류의 옵션을 중복 이식할 수 없습니다.", balance)
	if balance < APPLY_CRYSTAL_COST:
		return _failure(target, "레이드 정수가 부족합니다. 필요한 정수: %d" % APPLY_CRYSTAL_COST, balance)
	if int(source["trade_count"]) == 1:
		option["trade_count"] = 1
	gear["affixes"].append(option)
	return {"ok": true, "reason": "옵션 결정의 수치를 그대로 장비에 이식했습니다.", "item": gear,
		"balance": balance - APPLY_CRYSTAL_COST, "cost": APPLY_CRYSTAL_COST}
