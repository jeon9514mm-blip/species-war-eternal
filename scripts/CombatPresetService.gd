extends RefCounted
const MODEL = preload("res://scripts/CombatPresetModel.gd")
const SAFETY = preload("res://scripts/SaveSafety.gd")

static func entry_error(main: Node) -> String:
	if main.challenge_session != null or main.raid_running or str(main.active_screen) in ["combat", "raid"]:
		return "전투를 마친 뒤 프리셋을 변경하세요."
	if main._save_blocked_for_newer_version: return "최신 버전 저장을 확인해 주세요."
	if SAFETY.pending(main): return SAFETY.entry_error(main)
	if str(main.selected_faction) not in MODEL.FACTIONS: return "진영을 선택해 주세요."
	return ""

static func get_preset(main: Node, index: int) -> Dictionary:
	if index < 0 or index > 2 or str(main.selected_faction) not in MODEL.FACTIONS: return {}
	return MODEL.sanitize(main.combat_presets)[str(main.selected_faction)][index].duplicate(true)

static func fingerprint(main: Node, index: int) -> String:
	return JSON.stringify([str(main.selected_faction), main._deployed_hero_ids(), main.idle_stage, main._party_slot_cap(),
		main.hero_equipment_items, main.loot_inventory, main.guardian_collection, main.guardian_equipped,
		main.skill_auto, main.ultimate_auto, main.formation_id, main.party_presets, main.faction_party_presets, get_preset(main, index)]).sha256_text()

static func save(main: Node, index: int) -> Dictionary:
	var error: String = entry_error(main)
	if not error.is_empty(): return {"ok": false, "reason": error}
	if index < 0 or index > 2 or main.deployed_heroes.is_empty(): return {"ok": false, "reason": "저장할 원정대와 P1~P3을 선택하세요."}
	var ids: Array[String] = main._deployed_hero_ids()
	var equipment: Dictionary = {}
	for id: String in ids:
		equipment[id] = {}
		for slot: String in MODEL.SLOTS:
			var item: Dictionary = main._gear_item("", id, slot)
			if item.is_empty(): return {"ok": false, "reason": "장비 정보를 읽지 못했어요."}
			equipment[id][slot] = str(item["id"])
	var next: Dictionary = MODEL.sanitize(main.combat_presets)
	next[str(main.selected_faction)][index] = {"schema": 1, "formation_id": main.formation_id, "heroes": ids.duplicate(), "equipment": equipment,
		"guardian": str(main.guardian_equipped), "skill_auto": bool(main.skill_auto), "ultimate_auto": bool(main.ultimate_auto)}
	var checked: Dictionary = MODEL.sanitize(next)
	if checked[str(main.selected_faction)][index].is_empty():
		return {"ok": false, "reason": "중복 장비 또는 잘못된 영웅 정보를 확인해 주세요."}
	main.combat_presets = checked
	# Keep the original roster-only bank readable and compatible.
	main._load_active_faction_presets()
	main.party_presets[index] = ids.duplicate()
	main.faction_party_presets[str(main.selected_faction)] = main.party_presets.duplicate(true)
	main.active_preset_index = index
	main._save_idle_state()
	return {"ok": not SAFETY.pending(main), "reason": "P%d · 편성·장비·수호신·자동 스킬 저장%s" % [index + 1, " · 저장 대기" if SAFETY.pending(main) else " 완료"]}

static func _bad(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}

static func plan(main: Node, index: int) -> Dictionary:
	var error: String = entry_error(main)
	if not error.is_empty(): return _bad(error)
	var saved: Dictionary = get_preset(main, index)
	if saved.is_empty(): return _bad("통합 기록이 없어요. 현재 전투 설정을 먼저 저장하세요.")
	var ids: Array = saved["heroes"]
	if ids.size() > main._party_slot_cap(): return _bad("저장된 인원보다 현재 출전 슬롯이 적어요.")
	for id: String in ids:
		var hero: Dictionary = MODEL.HEROES.HEROES.get(id, {})
		if str(hero.get("faction", "")) != str(main.selected_faction) or main.idle_stage < int(hero.get("unlock_stage", 1)):
			return _bad("현재 해금되지 않은 영웅이 있어요: " + id)
	var guardian: String = str(saved["guardian"])
	if not guardian.is_empty() and not main.guardian_collection.has(guardian): return _bad("보유하지 않은 수호신이 저장되어 있어요.")
	# Candidate maps: no equipment or currency is moved until all checks pass.
	var available: Dictionary = {}
	var origin: Dictionary = {}
	var equipped: Dictionary = main.hero_equipment_items.duplicate(true)
	var inventory: Array = main.loot_inventory.duplicate(true)
	for item: Dictionary in inventory:
		var key: String = str(item.get("id", ""))
		if key.is_empty() or available.has(key): return _bad("가방 물품 ID 중복을 확인해 주세요.")
		available[key] = item; origin[key] = "bag"
	for id: String in equipped:
		for slot: String in equipped[id]:
			var item: Dictionary = equipped[id][slot]
			var key: String = str(item.get("id", ""))
			if key.is_empty() or available.has(key): return _bad("장착 물품 ID 중복을 확인해 주세요.")
			available[key] = item; origin[key] = id + ":" + slot
	var desired: Dictionary = {}; var used: Dictionary = {}; var moved: int = 0
	for id: String in ids:
		desired[id] = {}
		for slot: String in MODEL.SLOTS:
			var key: String = str(saved["equipment"][id][slot])
			if not available.has(key): return _bad("없거나 판매·분해된 장비가 있어요: " + key)
			var where: String = str(origin[key])
			if where != "bag" and where.get_slice(":", 0) not in ids:
				return _bad("다른 영웅이 장착 중이에요. 먼저 가방으로 옮겨 주세요: " + where)
			var item: Dictionary = available[key].duplicate(true)
			if str(item.get("item_type", "equipment")) != "equipment" or str(item.get("slot", "")) != slot or not main._gear_role_matches(item, id):
				return _bad("장비 부위 또는 전용 역할이 맞지 않아요.")
			if not item.get("proposal", {}).is_empty() and where != id + ":" + slot: return _bad("옵션 후보 선택을 마친 뒤 프리셋을 적용하세요.")
			if used.has(key): return _bad("한 장비를 여러 슬롯에 배치할 수 없어요.")
			used[key] = true
			if where != id + ":" + slot: moved += 1
			item["bound"] = true
			desired[id][slot] = item
	var next_inventory: Array = []
	for item: Dictionary in inventory:
		if not used.has(str(item["id"])): next_inventory.append(item)
	for id: String in ids:
		if not equipped.has(id): return _bad("현재 영웅의 장비 정보를 다시 열어 확인해 주세요.")
		for slot: String in MODEL.SLOTS:
			var old: Dictionary = equipped[id].get(slot, {})
			if old.is_empty(): return _bad("현재 장착 정보가 비어 있어요.")
			if not used.has(str(old.get("id", ""))):
				if not old.get("proposal", {}).is_empty(): return _bad("교체할 장비의 옵션 후보 선택을 마쳐 주세요.")
				next_inventory.append(old)
			equipped[id][slot] = desired[id][slot]
	if next_inventory.size() > int(main.INVENTORY_CAP): return _bad("교체 장비를 보관할 가방 공간이 부족해요.")
	return {"ok": true, "reason": "전체 검증 완료 · 재화 소비 없음", "token": fingerprint(main, index),
		"saved": saved, "equipped": equipped, "inventory": next_inventory, "moved": moved}

static func apply(main: Node, index: int, expected: String = "") -> Dictionary:
	if not expected.is_empty() and expected != fingerprint(main, index): return _bad("미리보기 이후 편성·장비가 바뀌었어요. 다시 확인해 주세요.")
	var proposal: Dictionary = plan(main, index)
	if not bool(proposal.get("ok", false)): return proposal
	var saved: Dictionary = proposal["saved"]
	# Single synchronous commit. Never call per-item auto-save mid-swap.
	main.hero_equipment_items = proposal["equipped"]
	main.loot_inventory = proposal["inventory"]
	for id: String in saved["heroes"]:
		for slot: String in MODEL.SLOTS:
			var item: Dictionary = main.hero_equipment_items[id][slot]
			main._get_hero_equipment(id)[slot] = int(item["level"])
			main._get_hero_equipment_rarity(id)[slot] = str(item["rarity"])
			main._get_hero_equipment_names(id)[slot] = str(item["name"])
			main._get_hero_equipment_sets(id)[slot] = str(item["set"])
	main._restore_deployed_heroes(saved["heroes"])
	main.guardian_equipped = str(saved["guardian"])
	main.formation_id = preload("res://scripts/BattleFormation.gd").sanitize(saved.get("formation_id"))
	main.skill_auto = bool(saved["skill_auto"])
	main.ultimate_auto = bool(saved["ultimate_auto"])
	main.active_preset_index = index
	main._refresh_growth_runtime()
	main._save_idle_state()
	return {"ok": not SAFETY.pending(main), "applied": true, "reason": "P%d 통합 설정 적용%s" % [index + 1, " · 저장 대기" if SAFETY.pending(main) else " 완료"]}
