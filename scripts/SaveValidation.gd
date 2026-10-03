extends RefCounted
class_name SaveValidation

const MAX_CURRENCY := 1000000000000
const MAX_STAGE := 10000
const MAX_TIMESTAMP := 4102444800 # 2100-01-01; preserve a clock rollback high-water mark.
const HERO_LEVEL_CAP := 100
const PET_LEVEL_CAP := 100
const EQUIPMENT_LEVEL_CAP := 10
const SLOTS := ["weapon", "armor", "accessory"]
const RARITIES := ["일반", "희귀", "전설"]
const SETS := ["초보자", "개척자", "강철", "월광", "새벽의 맹약", "철벽의 맹세", "월식의 추격"]
const EQUIPMENT_RULES = preload("res://scripts/EquipmentRules.gd")
const DAILY_PROGRESS = preload("res://scripts/DailyDungeonProgress.gd")
const EQUIPMENT_MARKET = preload("res://scripts/EquipmentMarketService.gd")
const INVENTORY_CAP := EQUIPMENT_RULES.INVENTORY_CAP
const QUESTS := ["stage5", "raid1", "tower5"]
const FACTIONS := ["aurelia", "noxfera"]
const DICTIONARY_FIELDS := ["pet_progress", "guardian_collection", "hero_skill_tree", "hero_progress", "hero_equipment", "hero_equipment_rarity", "hero_equipment_names", "hero_equipment_sets", "hero_equipment_items", "gear_market_state", "raid_clears", "hero_shards", "hero_breakthrough", "hero_ascension", "quest_claimed", "codex_seen", "faction_war", "faction_march", "faction_conflict", "faction_party_presets", "faction_world_snapshots", "world_season", "world_authority", "world_server_gateway"]

static func number(value: Variant, fallback: int, minimum: int, maximum: int) -> int:
	if typeof(value) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(value)):
		return fallback
	# Clamp before int conversion to avoid overflow on e.g. JSON 1e300.
	return int(clampf(float(value), float(minimum), float(maximum)))

static func string_value(value: Variant, fallback: String = "", limit: int = 160) -> String:
	return value.substr(0, limit) if typeof(value) == TYPE_STRING else fallback

static func day_key(value: Variant) -> String:
	# Calendar checkpoints are ordered, so malformed strings must not become
	# permanent future dates when reward code compares them lexicographically.
	if typeof(value) != TYPE_STRING or value.length() != 10:
		return ""
	if value[4] != "-" or value[7] != "-":
		return ""
	var digits: String = value.replace("-", "")
	if digits.length() != 8:
		return ""
	for character in digits:
		if character < "0" or character > "9":
			return ""
	var year := int(value.substr(0, 4))
	var month := int(value.substr(5, 2))
	var day := int(value.substr(8, 2))
	if year < 1 or month < 1 or month > 12:
		return ""
	var leap := year % 4 == 0 and (year % 100 != 0 or year % 400 == 0)
	var month_days := [31, 29 if leap else 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
	return value if day >= 1 and day <= int(month_days[month - 1]) else ""

static func week_key(value: Variant) -> String:
	if typeof(value) != TYPE_STRING or value.is_empty() or value.length() > 12:
		return ""
	# Keep valid historical checkpoints, including pre-epoch negative weeks.
	if not value.is_valid_int():
		return ""
	return str(int(value))

static func dictionary(value: Variant) -> Dictionary:
	return value if typeof(value) == TYPE_DICTIONARY else {}

static func ids(value: Variant, allowed: Array, maximum: int = 10) -> Array:
	var clean: Array = []
	if typeof(value) != TYPE_ARRAY:
		return clean
	for entry in value:
		if typeof(entry) == TYPE_STRING and entry in allowed and entry not in clean:
			clean.append(entry)
			if clean.size() >= maximum:
				break
	return clean

static func sanitize(raw: Dictionary, zone_ids: Array, stage_target: int = 10) -> Dictionary:
	var data := raw.duplicate(true)
	data["formation_id"] = preload("res://scripts/BattleFormation.gd").sanitize(raw.get("formation_id"))
	data["combat_presets"] = preload("res://scripts/CombatPresetModel.gd").sanitize(raw.get("combat_presets", {}))
	var now := int(Time.get_unix_time_from_system())
	for key in DICTIONARY_FIELDS:
		data[key] = dictionary(data.get(key, {}))
	for key in ["unclaimed_gold", "unclaimed_xp", "wallet_gold", "wallet_xp", "wallet_gems", "idle_chest_gold", "idle_chest_xp", "weekly_trial_best"]:
		data[key] = number(data.get(key), 0, 0, MAX_CURRENCY)
	for key in ['offline_pending_gold','offline_pending_xp','offline_pending_chest_gold','offline_pending_chest_xp']:
		data[key]=number(data.get(key),0,0,MAX_CURRENCY)
	for key in ['skill_auto','ultimate_auto']:
		data[key]=data[key] if typeof(data.get(key))==TYPE_BOOL else true
	data["raid_crystals"] = number(data.get("raid_crystals"), 0, 0, 1000000000)
	data["gear_auto_equip"] = data["gear_auto_equip"] if typeof(data.get("gear_auto_equip")) == TYPE_BOOL else true
	data["save_version"] = number(data.get("save_version"), 1, 1, SaveStore.VERSION)
	data["idle_stage"] = number(data.get("idle_stage"), 1, 1, MAX_STAGE)
	data["idle_stage_kills"] = number(data.get("idle_stage_kills"), 0, 0, maxi(0, stage_target - 1))
	data["last_idle_timestamp"] = number(data.get("last_idle_timestamp"), now, 0, MAX_TIMESTAMP)
	if int(data["last_idle_timestamp"]) == 0:
		data["last_idle_timestamp"] = now
	data["selected_faction"] = string_value(data.get("selected_faction"))
	if data["selected_faction"] not in FACTIONS:
		data["selected_faction"] = ""
	data["current_zone_id"] = string_value(data.get("current_zone_id"), "gray_meadow")
	if data["current_zone_id"] not in zone_ids:
		data["current_zone_id"] = "gray_meadow"
	var speed = data.get("battle_speed", 1.0)
	data["battle_speed"] = clampf(float(speed),1.0,2.0) if typeof(speed) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(speed)) else 1.0
	data["active_preset_index"] = number(data.get("active_preset_index"), -1, -1, 2)
	data["party_slot_legacy_cap"] = number(data.get("party_slot_legacy_cap"), 0, 0, 10)
	data["rewarded_ad_claimed_count"] = number(data.get("rewarded_ad_claimed_count"), 0, 0, 3)
	data["daily_dungeon_runs"] = number(data.get("daily_dungeon_runs"), 0, 0, 3)
	data["daily_dungeon_clears"] = DAILY_PROGRESS.sanitize(data.get("daily_dungeon_clears", {}))
	data["weekly_trial_runs"] = number(data.get("weekly_trial_runs"), 0, 0, 5)
	data["summon_pity"] = number(data.get("summon_pity"), 0, 0, 9)
	var guardians := preload("res://scripts/GuardianCatalog.gd")
	var collection := {}
	for id in guardians.DEFINITIONS:
		if data["guardian_collection"].has(id):
			var entry := dictionary(data["guardian_collection"][id])
			var copies := number(entry.get("copies"),0,0,999)
			if copies>0:collection[id]={"copies":copies}
	var starter_id: String=guardians.starter(str(data["selected_faction"]))
	if not starter_id.is_empty() and not collection.has(starter_id):collection[starter_id]={"copies":1}
	data["guardian_collection"]=collection
	data["guardian_equipped"]=string_value(data.get("guardian_equipped"),"",32)
	if not collection.has(data["guardian_equipped"]):data["guardian_equipped"]=starter_id
	data["guardian_legendary_pity"]=number(data.get("guardian_legendary_pity"),0,0,guardians.LEGENDARY_PITY-1)
	data["guardian_mythic_pity"]=number(data.get("guardian_mythic_pity"),0,0,guardians.MYTHIC_PITY-1)
	data["guardian_free_claimed"]=typeof(data.get("guardian_free_claimed"))==TYPE_BOOL and data["guardian_free_claimed"]
	data["tower_floor"] = number(data.get("tower_floor"), 1, 1, MAX_STAGE)
	data["tower_best_floor"] = number(data.get("tower_best_floor"), 0, 0, int(data["tower_floor"]) - 1)
	data["tutorial_step"] = number(data.get("tutorial_step"), 0, 0, 6)
	data["tutorial_completed"] = typeof(data.get("tutorial_completed")) == TYPE_BOOL and data["tutorial_completed"]
	for key in ["daily_reward_claimed_day", "rewarded_ad_day", "daily_dungeon_day"]:
		data[key] = day_key(data.get(key))
	data["weekly_content_key"] = week_key(data.get("weekly_content_key"))
	data["weekly_trial_legacy_best"] = number(data.get("weekly_trial_legacy_best"), 0, 0, MAX_CURRENCY)
	data["weekly_trial_legacy_week"] = week_key(data.get("weekly_trial_legacy_week"))
	# Old power-derived points are not comparable with effective HP damage.
	# Preserve quota/wallet and archive once, then mark the new score semantics.
	if number(data.get("weekly_trial_score_version"), 0, 0, 1000) != 1:
		if int(data["weekly_trial_best"]) > int(data["weekly_trial_legacy_best"]):
			data["weekly_trial_legacy_best"] = int(data["weekly_trial_best"])
			data["weekly_trial_legacy_week"] = str(data["weekly_content_key"])
		data["weekly_trial_best"] = 0
	data["weekly_trial_score_version"] = 1
	data["tracked_quest_id"] = string_value(data.get("tracked_quest_id"), "", 32)
	if data["tracked_quest_id"] not in QUESTS:
		data["tracked_quest_id"] = ""
	data["auto_salvage_min_rarity"] = rarity(data.get("auto_salvage_min_rarity"))
	var hero_ids: Array = preload("res://scripts/HeroRosterCatalog.gd").HEROES.keys()
	data["deployed_hero_ids"] = ids(data.get("deployed_hero_ids"), hero_ids)
	var raw_presets = data.get("party_presets", [])
	data["party_presets"] = [[], [], []]
	if typeof(raw_presets) == TYPE_ARRAY:
		for index in mini(3, raw_presets.size()):
			data["party_presets"][index] = ids(raw_presets[index], hero_ids)
	var raw_faction_presets: Dictionary = data.get("faction_party_presets", {})
	var roster_catalog = preload("res://scripts/HeroRosterCatalog.gd")
	var clean_faction_presets := {}
	for faction in FACTIONS:
		var allowed: Array = []
		for hero_id in hero_ids:
			if str(roster_catalog.HEROES.get(hero_id, {}).get("faction", "")) == faction:
				allowed.append(hero_id)
		var clean_bank: Array = [[], [], []]
		var raw_bank = raw_faction_presets.get(faction, [])
		if typeof(raw_bank) == TYPE_ARRAY:
			for index in mini(3, raw_bank.size()):
				clean_bank[index] = ids(raw_bank[index], allowed)
		clean_faction_presets[faction] = clean_bank
	data["faction_party_presets"] = clean_faction_presets
	data["raid_clears"] = _numbers(data["raid_clears"], zone_ids, MAX_STAGE)
	data["hero_shards"] = _numbers(data["hero_shards"], hero_ids, 1000000)
	data["hero_breakthrough"] = _numbers(data["hero_breakthrough"], hero_ids, 5)
	data["hero_ascension"] = _numbers(data["hero_ascension"], hero_ids, 3)
	data["quest_claimed"] = _flags(data["quest_claimed"], QUESTS)
	data["codex_seen"] = _flags(data["codex_seen"], hero_ids)
	data["long_term_goals"] = preload("res://scripts/LongTermGoalState.gd").sanitize(data.get("long_term_goals", {}))
	_sanitize_growth(data, hero_ids)
	_sanitize_equipment(data, hero_ids)
	return data

static func rarity(value: Variant) -> String:
	var result := string_value(value, "일반")
	result = {"common": "일반", "uncommon": "희귀", "rare": "희귀", "epic": "전설"}.get(result, result)
	return result if result in RARITIES else "일반"

static func _numbers(raw: Dictionary, allowed: Array, maximum: int) -> Dictionary:
	var clean := {}
	for key in allowed:
		if raw.has(key):
			clean[key] = number(raw[key], 0, 0, maximum)
	return clean

static func _flags(raw: Dictionary, allowed: Array) -> Dictionary:
	var clean := {}
	for key in allowed:
		if typeof(raw.get(key)) == TYPE_BOOL and raw[key]:
			clean[key] = true
	return clean

static func _sanitize_growth(data: Dictionary, hero_ids: Array) -> void:
	for field in ["hero_progress", "hero_equipment", "hero_equipment_rarity", "hero_equipment_names", "hero_equipment_sets", "hero_skill_tree"]:
		var raw: Dictionary = data[field]
		var clean := {}
		for hero_id in hero_ids:
			if not raw.has(hero_id):
				continue
			var entry := dictionary(raw[hero_id])
			var result := {}
			if field == "hero_progress":
				var level := number(entry.get("level"), 1, 1, HERO_LEVEL_CAP)
				result = {"level": level, "xp": number(entry.get("xp"), 0, 0, 100 + (level - 1) * 75 - 1) if level < HERO_LEVEL_CAP else 0}
			elif field == "hero_skill_tree":
				var progress := dictionary(data["hero_progress"].get(hero_id, {}))
				var budget := int((number(progress.get("level"), 1, 1, HERO_LEVEL_CAP) - 1) / 3.0)
				for branch in ["offense", "survival", "utility"]:
					result[branch] = number(entry.get(branch), 0, 0, mini(10, budget))
					budget -= int(result[branch])
			else:
				for slot in SLOTS:
					match field:
						"hero_equipment": result[slot] = number(entry.get(slot), 1, 1, EQUIPMENT_LEVEL_CAP)
						"hero_equipment_rarity": result[slot] = rarity(entry.get(slot))
						"hero_equipment_names": result[slot] = string_value(entry.get(slot), "초보자 장비", 80)
						"hero_equipment_sets": result[slot] = entry.get(slot) if entry.get(slot) in SETS else "초보자"
			clean[hero_id] = result
		data[field] = clean
	var pets := {}
	for faction in FACTIONS:
		if not data["pet_progress"].has(faction):
			continue
		var entry := dictionary(data["pet_progress"][faction])
		var level := number(entry.get("level"), 1, 1, PET_LEVEL_CAP)
		pets[faction] = {"level": level, "xp": number(entry.get("xp"), 0, 0, 60 + (level - 1) * 35 - 1) if level < PET_LEVEL_CAP else 0, "evolution": 2 if level >= 10 else (1 if level >= 5 else 0)}
	data["pet_progress"] = pets

static func _equipment_item(value: Variant, fallback_id: String, expected_slot: String = "") -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	var entry: Dictionary = value.duplicate(true)
	var is_crystal := string_value(entry.get("item_type"), "equipment") == "option_crystal"
	# Extracted options occupy bag/storage slots, never a hero's equipment slot.
	if is_crystal and not expected_slot.is_empty():
		return {}
	if not is_crystal:
		var slot := string_value(entry.get("slot"), "weapon" if expected_slot.is_empty() else expected_slot)
		if slot not in SLOTS or (not expected_slot.is_empty() and slot != expected_slot):
			return {}
		entry["slot"] = slot
	# Legacy IDs must be stable across inspection, load and a second save.
	var item_id := string_value(entry.get("id"), "", 160).strip_edges()
	if item_id.is_empty():
		item_id = "%s_%s" % [fallback_id, JSON.stringify(entry).sha256_text().left(12)]
	entry["id"] = item_id
	entry["rarity"] = rarity(entry.get("rarity"))
	return EQUIPMENT_RULES.normalize(entry)

static func _sanitize_equipment(data: Dictionary, hero_ids: Array) -> void:
	# One identity can exist in only one ownership container. A worn item wins
	# over a stale bag copy, followed by the bag and then recovery storage.
	var seen: Dictionary = {}
	var equipped: Dictionary = {}
	var raw_equipped: Dictionary = data.get("hero_equipment_items", {})
	for hero_id in hero_ids:
		var raw_slots := dictionary(raw_equipped.get(hero_id))
		var clean_slots: Dictionary = {}
		for slot in SLOTS:
			var item := _equipment_item(raw_slots.get(slot), "legacy_equipped_%s_%s" % [hero_id, slot], slot)
			if item.is_empty() or seen.has(item["id"]):
				continue
			seen[item["id"]] = true
			clean_slots[slot] = item
		if not clean_slots.is_empty():
			equipped[hero_id] = clean_slots
	data["hero_equipment_items"] = equipped
	var inventory: Array = []
	var overflow: Array = []
	var raw = data.get("loot_inventory", [])
	if typeof(raw) == TYPE_ARRAY:
		for index in raw.size():
			var item := _equipment_item(raw[index], "legacy_%d" % index)
			if item.is_empty() or seen.has(item["id"]):
				continue
			if inventory.size() < INVENTORY_CAP:
				seen[item["id"]] = true
				inventory.append(item)
			else:
				seen[item["id"]] = true
				# Older versions truncated these entries. Preserve them in the
				# recovery store instead, including crafted and locked gear.
				overflow.append(item)
	var raw_overflow = data.get("equipment_overflow", [])
	if typeof(raw_overflow) == TYPE_ARRAY:
		# The runtime admission limit cannot discard already-earned items.
		# SaveStore bounds the entire file by bytes and rejects oversized writes
		# explicitly, retaining the complete pending state for recovery.
		for index in raw_overflow.size():
			var item := _equipment_item(raw_overflow[index], "legacy_overflow_%d" % index)
			if item.is_empty() or seen.has(item["id"]):
				continue
			seen[item["id"]] = true
			overflow.append(item)
	data["loot_inventory"] = inventory
	data["equipment_overflow"] = overflow
	var market := EQUIPMENT_MARKET.new()
	market.from_dict(dictionary(data.get("gear_market_state")), seen.keys())
	data["gear_market_state"] = market.to_dict()
