extends RefCounted

## v83: EquipmentCommandService. Main remains the single owner of mutable game state.
## The injected host supplies state, virtual UI hooks and runtime refreshes.
## No cached host reference, duplicate wallet, RNG or save schema is introduced.

static func gear_inventory_index(main: Node, item_id: String) -> int:
	for index in main.loot_inventory.size():
		if str(main.loot_inventory[index].get("id", "")) == item_id:
			return index
	return -1


static func gear_item(main: Node, item_id: String, hero_id: String = "", slot: String = "") -> Dictionary:
	if hero_id.is_empty():
		var index = main._gear_inventory_index(item_id)
		return main._normalize_inventory_item(main.loot_inventory[index]) if index >= 0 else {}
	if not main._valid_growth_hero(hero_id) or slot not in main.EQUIPMENT_SLOTS:
		return {}
	if not main.hero_equipment_items.has(hero_id):
		main.hero_equipment_items[hero_id] = {}
	var entries: Dictionary = main.hero_equipment_items[hero_id]
	var current: Dictionary = entries.get(slot, {}).duplicate(true)
	if current.is_empty():
		current = {"id": "legacy_equipped_%s_%s" % [hero_id, slot], "origin": "legacy", "bound": true}
	# Old saves and upgrades still use these maps. Overlay them on the full
	# item so legacy callers cannot accidentally discard its ID or options.
	current["slot"] = slot
	current["level"] = main._get_hero_equipment(hero_id)[slot]
	current["rarity"] = main._get_hero_equipment_rarity(hero_id)[slot]
	current["name"] = main._get_hero_equipment_names(hero_id)[slot]
	current["set"] = main._get_hero_equipment_sets(hero_id)[slot]
	current["bound"] = true
	current = main._normalize_inventory_item(current)
	entries[slot] = current.duplicate(true)
	return current if item_id.is_empty() or item_id == str(current.get("id", "")) else {}


static func gear_update_item(main: Node, item: Dictionary, hero_id: String = "", slot: String = "") -> bool:
	if hero_id.is_empty():
		var index = main._gear_inventory_index(str(item.get("id", "")))
		if index < 0:
			return false
		main.loot_inventory[index] = item.duplicate(true)
	else:
		if main._gear_item(str(item.get("id", "")), hero_id, slot).is_empty():
			return false
		main.hero_equipment_items[hero_id][slot] = item.duplicate(true)
		main._refresh_growth_runtime()
		main._update_equipment_card(hero_id)
	return true


static func gear_enhance_item(main: Node, item_id: String, hero_id: String = "", slot: String = "") -> Dictionary:
	var save_error: String = preload("res://scripts/SaveSafety.gd").mutation_error(main)
	if not save_error.is_empty():
		return {"ok": false, "reason": save_error}
	var item = main._gear_item(item_id, hero_id, slot)
	if item.is_empty():
		return {"ok": false, "reason": "장비가 이동했습니다. 다시 선택해 주세요."}
	if str(item.get("item_type", "equipment")) != "equipment":
		return {"ok": false, "reason": "옵션 결정은 강화할 수 없습니다. 장비에 이식해 사용하세요."}
	var level = int(item["level"])
	if level >= main.MAX_EQUIPMENT_LEVEL:
		return {"ok": false, "reason": "이미 최대 강화 단계(+10)입니다."}
	var cost = main._inventory_upgrade_cost(item)
	if main.wallet_gold < cost:
		return {"ok": false, "reason": "골드가 부족합니다. 강화 비용은 %d 골드입니다." % cost}
	item["level"] = level + 1
	item["power"] = main._item_power(item)
	if hero_id.is_empty():
		if not main._gear_update_item(item):
			return {"ok": false, "reason": "장비가 이동하여 강화를 취소했습니다."}
	else:
		# Keep the legacy scalar map and complete item metadata in one save image.
		main._get_hero_equipment(hero_id)[slot] = level + 1
		main.hero_equipment_items[hero_id][slot] = item.duplicate(true)
		main._refresh_growth_runtime()
		main._update_equipment_card(hero_id)
	main.wallet_gold -= cost
	main._record_first_session_action("growth")
	main._save_idle_state()
	main._presentation_event("upgrade")
	return {"ok": true, "item": item.duplicate(true), "cost": cost, "hero_id": hero_id, "slot": str(item["slot"]), "reason": "%s을(를) +%d로 강화했습니다. 골드 -%d" % [item["name"], item["level"], cost]}


static func gear_equip_item(main: Node, item_id: String, hero_id: String) -> Dictionary:
	var save_error: String = preload("res://scripts/SaveSafety.gd").mutation_error(main)
	if not save_error.is_empty():
		return {"ok": false, "reason": save_error}
	var index = main._gear_inventory_index(item_id)
	if index < 0 or not main._valid_growth_hero(hero_id):
		return {"ok": false, "reason": "장비나 영웅을 다시 선택해 주세요."}
	var item = main._normalize_inventory_item(main.loot_inventory[index])
	if item.is_empty() or str(item.get("item_type", "equipment")) != "equipment":
		return {"ok": false, "reason": "영웅에게 장착할 수 없는 물품입니다."}
	if not main._gear_role_matches(item,hero_id):
		return {"ok": false, "reason": "%s 전용 사냥 장비입니다. 해당 역할 영웅을 선택하세요." % main.GEAR.HUNT_ROLE_NAMES.get(str(item.get("hunt_role","")),"해당 역할")}
	if not main._equip_item_direct(index, hero_id):
		return {"ok": false, "reason": "조율 후보를 선택하거나 포기한 뒤 장착하세요."}
	main._save_idle_state()
	var slot = str(item["slot"])
	main._presentation_event("equip")
	return {"ok": true, "item": main._gear_item(item_id, hero_id, slot), "hero_id": hero_id, "slot": slot, "reason": "%s에게 %s을(를) 장착했습니다." % [main._hero_short_name(hero_id), item["name"]]}


static func gear_decompose_item(main: Node, item_id: String, confirmed: bool = false) -> Dictionary:
	var save_error: String = preload("res://scripts/SaveSafety.gd").mutation_error(main)
	if not save_error.is_empty():
		return {"ok": false, "reason": save_error}
	var index = main._gear_inventory_index(item_id)
	var item = main._gear_item(item_id)
	if index < 0 or item.is_empty():
		return {"ok": false, "reason": "장비가 이동했습니다. 다시 선택해 주세요."}
	if str(item.get("item_type", "equipment")) != "equipment":
		return {"ok": false, "reason": "옵션 결정은 분해할 수 없습니다. 보관하거나 이식해 주세요."}
	if bool(item.get("locked", false)) or not item.get("proposal", {}).is_empty():
		return {"ok": false, "reason": "잠금을 해제하고 진행 중인 옵션 선택을 마친 뒤 분해하세요."}
	if main.GEAR.protected(item) and not confirmed:
		return {"ok": false, "reason": "세트·옵션 장비는 분해 확인이 필요합니다."}
	var reward = main._inventory_salvage_value(item)
	main.wallet_gold += reward
	main.loot_inventory.remove_at(index)
	main._save_idle_state()
	return {"ok": true, "gold": reward, "reason": "%s을(를) 분해해 골드 %d를 얻었습니다." % [item["name"], reward]}


static func gear_workshop_action(main: Node, item_id: String, action: String, args: Dictionary = {}, hero_id: String = "", slot: String = "") -> Dictionary:
	var save_error: String = preload("res://scripts/SaveSafety.gd").mutation_error(main)
	if not save_error.is_empty():
		return {"ok": false, "reason": save_error}
	var item = main._gear_item(item_id, hero_id, slot)
	if item.is_empty():
		return {"ok": false, "reason": "장비가 이동했습니다. 목록을 다시 확인하세요."}
	if action == "remove" and not main._gear_option_matches(item, int(args.get("index", -1)), args.get("expected_option", {})):
		return {"ok": false, "reason": "옵션이 변경되었습니다. 목록을 다시 확인하세요."}
	var result: Dictionary
	match action:
		"preview": result = main.WORKSHOP.preview(item, str(args.get("family", "")), main.raid_crystals, main.loot_rng)
		"choose": result = main.WORKSHOP.choose(item, int(args.get("index", -1)))
		"discard": result = main.WORKSHOP.discard(item)
		"remove": result = main.WORKSHOP.remove(item, int(args.get("index", -1)), main.raid_crystals)
		"toggle_lock":
			item["locked"] = not bool(item.get("locked", false))
			result = {"ok": true, "item": item, "reason": "장비 잠금 설정을 변경했습니다."}
		_: return {"ok": false, "reason": "지원하지 않는 공방 작업입니다."}
	if not bool(result.get("ok", false)):
		return result
	if not main._gear_update_item(result["item"], hero_id, slot):
		return {"ok": false, "reason": "장비가 이동하여 작업을 취소했습니다."}
	main.raid_crystals = int(result.get("balance", main.raid_crystals))
	main._save_idle_state()
	return result


@warning_ignore("unused_parameter")
static func gear_option_matches(main: Node, item: Dictionary, index: int, expected_option: Dictionary) -> bool:
	if expected_option.is_empty():
		return true
	var affixes: Array = item.get("affixes", [])
	return index >= 0 and index < affixes.size() and affixes[index] == expected_option


static func gear_extract_option(main: Node, item_id: String, index: int, hero_id: String = "", slot: String = "", expected_option: Dictionary = {}) -> Dictionary:
	var save_error: String = preload("res://scripts/SaveSafety.gd").mutation_error(main)
	if not save_error.is_empty():
		return {"ok": false, "reason": save_error}
	var item = main._gear_item(item_id, hero_id, slot)
	if item.is_empty():
		return {"ok": false, "reason": "장비가 이동했습니다. 목록을 다시 확인하세요."}
	if not main._gear_option_matches(item, index, expected_option):
		return {"ok": false, "reason": "옵션이 변경되었습니다. 목록을 다시 확인하세요."}
	var into_inventory = main.loot_inventory.size() < main.INVENTORY_CAP
	if not into_inventory and main.equipment_overflow.size() >= main.GEAR_OVERFLOW_CAP-(2 if main.raid_running else 0):
		return {"ok": false, "reason": "가방과 우편함이 가득 찼습니다. 빈칸을 확보한 뒤 추출하세요."}
	var result: Dictionary = main.WORKSHOP.extract(item, index, main.raid_crystals)
	if not bool(result.get("ok", false)):
		return result
	if not main._gear_update_item(result["item"], hero_id, slot):
		return {"ok": false, "reason": "장비가 이동하여 추출을 취소했습니다."}
	# The source option, resulting crystal and currency share one save image.
	# Do not use generic loot storage: extraction never salvages another item.
	if into_inventory:
		main.loot_inventory.append(result["crystal"].duplicate(true))
	else:
		preload("res://scripts/EquipmentMailService.gd").deliver(main,result["crystal"],"옵션 추출 결정 배송")
	main.raid_crystals = int(result["balance"])
	result["destination"] = "inventory" if into_inventory else "overflow"
	result["reason"] = "수치를 유지한 옵션 결정을 %s에 보냈습니다." % ("가방" if into_inventory else "우편함")
	main._save_idle_state()
	return result


static func gear_apply_crystal(main: Node, crystal_id: String, target_item_id: String, hero_id: String = "", slot: String = "") -> Dictionary:
	var save_error: String = preload("res://scripts/SaveSafety.gd").mutation_error(main)
	if not save_error.is_empty():
		return {"ok": false, "reason": save_error}
	var crystal_index = main._gear_inventory_index(crystal_id)
	if crystal_index < 0:
		return {"ok": false, "reason": "옵션 결정이 이동했거나 이미 사용되었습니다."}
	var crystal = main._normalize_inventory_item(main.loot_inventory[crystal_index])
	var item = main._gear_item(target_item_id, hero_id, slot)
	if item.is_empty():
		return {"ok": false, "reason": "장비가 이동했습니다. 목록을 다시 확인하세요."}
	var result: Dictionary = main.WORKSHOP.apply_crystal(item, crystal, main.raid_crystals)
	if not bool(result.get("ok", false)):
		return result
	if not main._gear_update_item(result["item"], hero_id, slot):
		return {"ok": false, "reason": "장비가 이동하여 이식을 취소했습니다."}
	main.loot_inventory.remove_at(main._gear_inventory_index(crystal_id))
	main.raid_crystals = int(result["balance"])
	main._save_idle_state()
	return result


static func set_gear_auto_equip(main: Node, value: bool) -> void:
	if not preload("res://scripts/SaveSafety.gd").allow_mutation(main): return
	main.gear_auto_equip = value
	main._save_idle_state()


static func gear_claim_overflow(main: Node, item_id: String) -> Dictionary:
	return gear_claim_overflow_many(main, [item_id])


static func gear_claim_overflow_many(main: Node, item_ids: Array) -> Dictionary:
	var save_error: String = preload("res://scripts/SaveSafety.gd").mutation_error(main)
	if not save_error.is_empty():
		return {"ok": false, "reason": save_error}
	if item_ids.is_empty() or item_ids.size() > main.INVENTORY_CAP:
		return {"ok": false, "reason": "받을 장비를 선택해 주세요."}
	if item_ids.size() > main.INVENTORY_CAP - main.loot_inventory.size():
		return {"ok": false, "reason": "가방에 빈칸이 부족합니다. 선택한 장비는 모두 우편함에 남아 있습니다."}
	var wanted: Dictionary = {}
	for id: Variant in item_ids:
		if not id is String or str(id).is_empty() or wanted.has(id):
			return {"ok": false, "reason": "장비 선택이 중복되거나 잘못되었습니다. 다시 선택해 주세요."}
		wanted[id] = true
	# Resolve all IDs before moving anything. A stale selection must not partially
	# claim, and a duplicate ID must not clone an already owned/equipped item.
	var found: Dictionary = {}
	var remaining: Array = []
	for item: Dictionary in main.equipment_overflow:
		var id: String = str(item.get("id", ""))
		if not wanted.has(id):
			remaining.append(item)
		elif found.has(id):
			return {"ok": false, "reason": "우편의 장비 ID가 중복되어 수령을 보류했습니다."}
		else:
			found[id] = item
	if found.size() != wanted.size():
		return {"ok": false, "reason": "이미 받았거나 이동한 장비가 있습니다. 목록을 새로고침해 주세요."}
	var owned: Array = main.loot_inventory.duplicate()
	for equipment: Dictionary in main.hero_equipment_items.values():
		owned.append_array(equipment.values())
	for item: Dictionary in owned:
		if wanted.has(str(item.get("id", ""))):
			return {"ok": false, "reason": "이미 보유한 장비 ID가 있어 수령을 보류했습니다."}
	var claimed: Array = []
	for id: String in item_ids:
		claimed.append(found[id].duplicate(true))
	main.loot_inventory.append_array(claimed)
	main.equipment_overflow = remaining
	for id in item_ids:main.equipment_mail_headers.erase(id)
	main._save_idle_state()
	var pending: bool = preload("res://scripts/SaveSafety.gd").pending(main)
	return {"ok": true, "count": claimed.size(), "save_pending": pending,
		"reason": "장비 %d개를 가방으로 받았습니다.%s" % [claimed.size(), " · 저장 대기" if pending else ""]}


static func roll_raid_equipment(main: Node, zone: Dictionary) -> Dictionary:
	if not preload("res://scripts/SaveSafety.gd").mutation_error(main).is_empty() or preload("res://scripts/EquipmentMailService.gd").available(main,false)<1:return {}
	var zone_id = main.raid_encounter_zone if not main.raid_encounter_zone.is_empty() else main.current_zone_id
	var clear_count = int(main.raid_clears.get(zone_id, 0))
	var milestone = clear_count > 0 and clear_count % 5 == 0
	var candidates: Array = main.EQUIPMENT_SLOTS.duplicate()
	if milestone:
		var owned: Array = main.loot_inventory + main.equipment_overflow
		for hero_id in main.hero_equipment_items:
			for equipped in main.hero_equipment_items[hero_id].values():
				owned.append(equipped)
		var market: Dictionary = main.gear_market_service.to_dict() if main._gear_market_loaded else main.gear_market_state
		var market_account: Dictionary = market.get("accounts", {}).get("player_local", {})
		owned.append_array(market_account.get("deliveries", []))
		for listing in market.get("listings", {}).values():
			if str(listing.get("seller_id", "")) == "player_local" and str(listing.get("status", "")) == "active":
				owned.append(listing.get("item", {}))
		for item in owned:
			if str(item.get("item_type", "equipment")) == "equipment" and str(item.get("origin", "")) == "raid" and str(item.get("source_id", "")) == zone_id:
				candidates.erase(str(item.get("slot", "")))
		if candidates.is_empty():
			candidates = main.EQUIPMENT_SLOTS.duplicate()
	var slot: String = candidates[main.loot_rng.randi_range(0, candidates.size() - 1)]
	var rarity = "전설" if milestone or main.loot_rng.randf() < 0.15 + 0.05 * int(zone.get("difficulty", 1)) else "희귀"
	var source = zone.duplicate(true)
	source["id"] = zone_id
	var item: Dictionary = main.GEAR.raid_item(source, slot, rarity, main.loot_rng)
	var stored = main._store_or_salvage_loot(item)
	main.last_drop_text = "%s [%s] 확정 획득 · %s%s" % [item.get("name", "레이드 장비"), rarity, stored, " · 5회 클리어 보너스" if milestone else ""]
	return item


static func gear_market_ready(main: Node) -> Dictionary:
	if not main._gear_market_loaded:
		main.gear_market_service.from_dict(main.gear_market_state)
		main._gear_market_loaded = true
	if main.gear_market_service.account_snapshot("player_local").is_empty():
		return main.gear_market_service.bootstrap_account("player_local", main.wallet_gold, main.loot_inventory, "내 원정대", "player")
	return main.gear_market_service.sync_local_account("player_local", main.wallet_gold, main.loot_inventory)


static func market_snapshot(main: Node) -> Dictionary:
	var ready = main._gear_market_ready()
	if not bool(ready.get("ok", false)):
		return {"mode": "로컬 거래소 · 온라인 서버 미연결", "revision": 0, "listings": [], "own_listings": [], "account": {}, "reason": ready.get("reason", "거래 정보를 불러오지 못했습니다.")}
	var expired: int = main.gear_market_service.expire(int(Time.get_unix_time_from_system()))
	main.gear_market_state = main.gear_market_service.to_dict()
	if expired > 0:
		main._save_idle_state()
	var listings: Array = main.gear_market_service.browse()
	var own: Array = []
	for listing in main.gear_market_state.get("listings", {}).values():
		if str(listing.get("seller_id", "")) == "player_local":
			own.append(listing.duplicate(true))
	own.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("serial", 0)) > int(b.get("serial", 0)))
	own = own.slice(0, 20)
	return {"mode": "로컬 거래소 · 온라인 서버 미연결", "revision": int(main.gear_market_state.get("revision", 0)), "listings": listings, "own_listings": own, "account": main.gear_market_service.account_snapshot("player_local")}


static func market_submit(main: Node, action: String, params: Dictionary = {}) -> Dictionary:
	var save_error: String = preload("res://scripts/SaveSafety.gd").mutation_error(main)
	if not save_error.is_empty():
		return {"ok": false, "reason": save_error}
	var ready = main._gear_market_ready()
	if not bool(ready.get("ok", false)):
		return ready
	var command = params.duplicate(true)
	command["action"] = action
	if not command.has("request_id"):
		var sequence: int = int(main.gear_market_service.account_snapshot("player_local").get("last_request_seq", 0)) + 1
		command["request_seq"] = sequence
		command["request_id"] = "seq_%d" % sequence
	var result: Dictionary = main.gear_market_service.submit("player_local", command, int(Time.get_unix_time_from_system()))
	var account: Dictionary = main.gear_market_service.account_snapshot("player_local")
	main.wallet_gold = int(account.get("gold", main.wallet_gold))
	main.loot_inventory = account.get("inventory", main.loot_inventory).duplicate(true)
	main.gear_market_state = main.gear_market_service.to_dict()
	# Wallet, bag, escrow and deliveries are written in the same SaveStore image.
	main._save_idle_state()
	return result


static func equipped_slot_power(main: Node, hero_id: String, slot: String) -> int:
	if not main._valid_growth_hero(hero_id) or slot not in main.EQUIPMENT_SLOTS:
		return 0
	var levels = main._get_hero_equipment(hero_id)
	var rarities = main._get_hero_equipment_rarity(hero_id)
	return main._item_power({"slot": slot, "level": int(levels[slot]), "rarity": str(rarities[slot])})


static func automatic_equipment_gain(main: Node, item: Dictionary, hero_id: String) -> int:
	if not main._valid_growth_hero(hero_id):
		return 0
	var normalized = main._normalize_inventory_item(item)
	if normalized.is_empty():
		return 0
	if not main._gear_role_matches(normalized,hero_id):
		return 0
	var slot = str(normalized["slot"])
	if main.GEAR.protected(normalized) or main.GEAR.protected(main._gear_item("", hero_id, slot)):
		return 0
	var item_gain = main._item_power(normalized) - main._equipped_slot_power(hero_id, slot)
	if item_gain <= 0:
		return 0
	var old_set = main._equipment_set_profile(hero_id)
	var new_sets = main._get_hero_equipment_sets(hero_id).duplicate()
	new_sets[slot] = normalized["set"]
	var new_set = main._equipment_set_profile(hero_id, new_sets)
	# Automatic actions preserve defensive set bonuses. The player can still
	# explicitly choose an offensive trade-off through manual equipment.
	if float(new_set["hp_mult"]) < float(old_set["hp_mult"]) or int(new_set["defense_bonus"]) < int(old_set["defense_bonus"]):
		return 0
	var progress = main._get_hero_progress(hero_id)
	var raw = 140 + (int(progress["level"]) - 1) * 35 + main._equipment_power(hero_id) + main._skill_tree_spent(hero_id) * 22 + main._hero_breakthrough_rank(hero_id) * 55
	return maxi(0, int((raw + item_gain) * float(new_set["attack_mult"]) - raw * float(old_set["attack_mult"])))


static func best_auto_equipment_target(main: Node, item: Dictionary, roster: Array) -> String:
	var best_id = ""
	var best_gain = 0
	for hero in roster:
		var hero_id = str(hero.get("id", ""))
		var gain = main._automatic_equipment_gain(item, hero_id)
		if gain > best_gain:
			best_gain = gain
			best_id = hero_id
	return best_id


static func gear_role_matches(main: Node, item: Dictionary, hero_id: String) -> bool:
	var role=str(item.get("hunt_role",""))
	if role.is_empty():return true
	var hero_role=main._hero_role_group(hero_id)
	return (role=="dealer" and hero_role=="딜러") or (role=="defender" and hero_role=="탱커") or (role=="support" and hero_role in ["서포터","컨트롤러"])


static func equip_item_direct(main: Node, index: int, hero_id: String) -> bool:
	if not main._inventory_action_valid(index) or not main._valid_growth_hero(hero_id):
		return false
	var item = main._normalize_inventory_item(main.loot_inventory[index])
	if str(item.get("item_type", "equipment")) != "equipment":
		return false
	if not main._gear_role_matches(item,hero_id):
		return false
	var slot = str(item["slot"])
	var equipment = main._get_hero_equipment(hero_id)
	var rarities = main._get_hero_equipment_rarity(hero_id)
	var names = main._get_hero_equipment_names(hero_id)
	var sets = main._get_hero_equipment_sets(hero_id)
	if not item.get("proposal", {}).is_empty():
		return false
	var old_item = main._gear_item("", hero_id, slot)
	item["bound"] = true
	if not main.hero_equipment_items.has(hero_id):
		main.hero_equipment_items[hero_id] = {}
	main.hero_equipment_items[hero_id][slot] = item.duplicate(true)
	equipment[slot] = int(item["level"])
	rarities[slot] = str(item["rarity"])
	names[slot] = str(item["name"])
	sets[slot] = str(item["set"])
	# Replacing in place preserves inventory count even at the capacity limit.
	main.loot_inventory[index] = old_item
	main._refresh_growth_runtime()
	main._update_equipment_card(hero_id)
	return true


static func recommend_equip_all(main: Node) -> void:
	if not preload("res://scripts/SaveSafety.gd").allow_mutation(main): return
	var roster = main.deployed_heroes if not main.deployed_heroes.is_empty() else main._hero_roster_for_faction().slice(0, 3)
	if roster.is_empty() or main.loot_inventory.is_empty():
		main._show_toast("추천장착할 영웅 또는 장비가 없습니다.")
		return
	var equipped_count = 0
	# A displaced item can improve another hero. Repeat a bounded number of
	# passes until every item has been offered to the entire active party.
	for _pass in roster.size():
		var changed = false
		for index in main.loot_inventory.size():
			if not main._inventory_action_valid(index):
				continue
			var best_hero_id = main._best_auto_equipment_target(main.loot_inventory[index], roster)
			if not best_hero_id.is_empty() and main._equip_item_direct(index, best_hero_id):
				equipped_count += 1
				changed = true
		if not changed:
			break
	main._save_idle_state()
	main._show_toast("추천장착 완료 · %d개 교체 · 세트 효과 보호" % equipped_count)
	if main.active_screen not in ["combat", "raid"]:
		main._build_inventory_screen()
	else:
		main._update_reward_labels()


static func bulk_enhance_equipped(main: Node) -> void:
	if not preload("res://scripts/SaveSafety.gd").allow_mutation(main): return
	var roster = main.deployed_heroes if not main.deployed_heroes.is_empty() else main._hero_roster_for_faction().slice(0, 3)
	var upgraded = 0
	var spent = 0
	for hero in roster:
		var hero_id = str(hero.get("id", ""))
		if not main._valid_growth_hero(hero_id):
			continue
		var equipment = main._get_hero_equipment(hero_id)
		for slot in ["weapon", "armor", "accessory"]:
			var level = int(equipment[slot])
			if level >= 10:
				continue
			var cost = main._equipment_upgrade_cost(slot, level)
			if main.wallet_gold >= cost:
				main.wallet_gold -= cost
				spent += cost
				equipment[slot] = level + 1
				upgraded += 1
		main.hero_equipment[hero_id] = equipment
	main._refresh_growth_runtime()
	if upgraded > 0: main._record_first_session_action("growth")
	main._save_idle_state()
	main._show_toast("일괄강화 · %d회 강화 · %dG 사용" % [upgraded, spent])
	if main.active_screen not in ["combat", "raid"]:
		main._build_inventory_screen()
	else:
		main._update_reward_labels()
