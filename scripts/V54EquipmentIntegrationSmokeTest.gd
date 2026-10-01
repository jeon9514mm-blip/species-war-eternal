extends SceneTree

# Production Main entry points remain intact. The fixture only isolates disk
# persistence and transient visual notifications; no loot/stat/action rule is mocked.
class EquipmentFixture:
	extends "res://scripts/Main.gd"
	var save_calls := 0
	var saved_equipment: Dictionary = {}
	func _load_idle_state() -> void:
		pass
	func _save_idle_state() -> void:
		save_calls += 1
		saved_equipment = {"crystals": get("raid_crystals"), "inventory": loot_inventory.duplicate(true), "equipped": get("hero_equipment_items").duplicate(true), "overflow": get("equipment_overflow").duplicate(true), "market": get("gear_market_state").duplicate(true), "gold": wallet_gold}
	func _show_toast(_message: String) -> void:
		pass
	func _show_battle_result_popup(_title: String, _headline: String, _detail: String, _accent: Color) -> void:
		pass

const RULES = preload("res://scripts/EquipmentRules.gd")
# Captured from clean v53 commit 27906a5 before the v54 Main changes. For each
# hero: starter +1, rare +4/steel set at Lv20, legendary +10/moonlight at Lv20.
# Columns: max HP, attack, defense, attack interval, ultimate gain, party power.
const LEGACY_BASELINE := {"adrien":[[500,51,7,1.0,1.0,320],[1695,244,12,1.0,1.0,1368],[2120,501,7,1.0,1.0,2572]],"astel":[[517,34,11,1.06,1.12,295],[1636,159,16,1.06,1.12,1227],[2031,327,11,1.06,1.12,2296]],"bora":[[500,51,7,1.0,1.0,320],[1695,244,12,1.0,1.0,1368],[2120,501,7,1.0,1.0,2572]],"bron":[[728,31,22,1.04,0.99,301],[1927,146,27,1.04,0.99,1263],[2342,300,22,1.04,0.99,2366]],"caelum":[[510,55,8,0.98,1.0,326],[1729,259,13,0.98,1.0,1408],[2162,532,8,0.98,1.0,2648]],"corvin":[[500,51,7,1.0,1.0,320],[1695,244,12,1.0,1.0,1368],[2120,501,7,1.0,1.0,2572]],"darius":[[475,57,7,1.02,0.98,325],[1610,271,12,1.02,0.98,1398],[2014,556,7,1.02,0.98,2629]],"elisia":[[469,33,10,1.04,1.1,281],[1485,153,15,1.04,1.1,1146],[1844,313,10,1.04,1.1,2138]],"fenris":[[421,50,6,0.84,1.04,305],[1427,234,11,0.84,1.04,1286],[1785,481,6,0.84,1.04,2412]],"garm":[[832,31,24,1.07,0.96,317],[2204,147,29,1.07,0.96,1355],[2678,303,24,1.07,0.96,2547]],"isolde":[[507,36,10,1.04,1.1,296],[1604,167,15,1.04,1.1,1234],[1991,342,10,1.04,1.1,2311]],"kairen":[[476,40,8,1.02,1.05,300],[1539,188,13,1.02,1.05,1257],[1915,385,8,1.02,1.05,2355]],"leonhardt":[[686,28,23,1.04,0.96,286],[1818,132,28,1.04,0.96,1175],[2209,272,23,1.04,0.96,2195]],"lucien":[[500,51,7,1.0,1.0,320],[1695,244,12,1.0,1.0,1368],[2120,501,7,1.0,1.0,2572]],"lunea":[[525,43,9,1.02,1.05,319],[1699,201,14,1.02,1.05,1365],[2114,412,9,1.02,1.05,2565]],"mira":[[399,48,6,0.98,1.0,289],[1350,224,11,0.98,1.0,1191],[1688,459,6,0.98,1.0,2226]],"morgas":[[445,34,9,1.05,1.07,283],[1439,161,14,1.05,1.07,1154],[1791,331,9,1.05,1.07,2155]],"naia":[[500,51,7,1.0,1.0,320],[1695,244,12,1.0,1.0,1368],[2120,501,7,1.0,1.0,2572]],"nyx":[[471,40,8,1.01,1.06,300],[1523,186,13,1.01,1.06,1256],[1895,381,8,1.01,1.06,2352]],"odelia":[[536,43,9,1.0,1.05,319],[1733,199,14,1.0,1.05,1366],[2157,408,9,1.0,1.05,2567]],"orwin":[[755,29,24,1.06,0.95,300],[1999,136,29,1.06,0.95,1253],[2429,280,24,1.06,0.95,2347]],"ragna":[[432,46,7,0.91,1.04,293],[1465,215,12,0.91,1.04,1213],[1832,442,7,0.91,1.04,2269]],"rokan":[[500,51,7,1.0,1.0,320],[1695,244,12,1.0,1.0,1368],[2120,501,7,1.0,1.0,2572]],"sael":[[500,51,7,1.0,1.0,320],[1695,244,12,1.0,1.0,1368],[2120,501,7,1.0,1.0,2572]],"selene":[[554,39,10,1.0,1.08,314],[1752,180,15,1.0,1.08,1334],[2176,370,10,1.0,1.08,2506]],"seria":[[426,49,6,0.86,1.03,304],[1443,230,11,0.86,1.03,1277],[1804,473,6,0.86,1.03,2393]],"tessa":[[500,51,7,1.0,1.0,320],[1695,244,12,1.0,1.0,1368],[2120,501,7,1.0,1.0,2572]],"ulric":[[536,46,9,0.95,1.03,326],[1733,215,14,0.95,1.03,1407],[2157,442,9,0.95,1.03,2647]],"valeria":[[420,46,7,0.98,1.02,291],[1422,217,12,0.98,1.02,1202],[1778,446,7,0.98,1.02,2247]],"veyra":[[455,57,6,0.96,1.01,325],[1542,271,11,0.96,1.01,1401],[1929,556,6,0.96,1.01,2635]]}
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error("V54 EQUIPMENT INTEGRATION: " + label)

func _fixture():
	var main = EquipmentFixture.new()
	main._offline_checked = true
	root.add_child(main)
	main.set_process(false)
	main.set_physics_process(false)
	main.selected_faction = "aurelia"
	main.party_slot_legacy_cap = 10
	main.idle_stage = 25
	main.current_zone_id = "gray_meadow"
	main._restore_deployed_heroes(["leonhardt", "mira", "elisia"])
	main._setup_hero_skills()
	main.active_screen = "combat"
	main.combat_running = true
	main.combat_effects_enabled = false
	main.combat_fx.enabled = false
	main.wallet_gold = 100000
	main.raid_crystals = 0
	main.loot_rng.seed = 540123
	main.save_calls = 0
	return main

func _wallet_snapshot(main) -> Dictionary:
	return {"gold": main.wallet_gold, "crystals": main.raid_crystals, "inventory": main.loot_inventory.duplicate(true), "equipped": main.hero_equipment_items.duplicate(true), "overflow": main.equipment_overflow.duplicate(true), "saves": main.save_calls}

func _find_item(main, item_id: String) -> Dictionary:
	for item in main.loot_inventory:
		if str(item.get("id", "")) == item_id:
			return item
	for slots in main.hero_equipment_items.values():
		for item in slots.values():
			if str(item.get("id", "")) == item_id:
				return item
	for item in main.equipment_overflow:
		if str(item.get("id", "")) == item_id:
			return item
	return {}

func _legacy_equipment_preserved() -> void:
	var main = _fixture()
	main.idle_stage = 1
	for faction in ["aurelia", "noxfera"]:
		main.selected_faction = faction
		for hero in main._hero_roster_for_faction():
			var id := str(hero["id"])
			for scenario in 3:
				main.deployed_heroes = [hero]
				main.hero_progress = {id: {"level": 1 if scenario == 0 else 20, "xp": 0}}
				var level: int = [1, 4, 10][scenario]
				var rarity: String = ["일반", "희귀", "전설"][scenario]
				var set_name: String = ["초보자", "강철", "월광"][scenario]
				main.hero_equipment = {id: {"weapon": level, "armor": level, "accessory": level}}
				main.hero_equipment_rarity = {id: {"weapon": rarity, "armor": rarity, "accessory": rarity}}
				main.hero_equipment_sets = {id: {"weapon": set_name, "armor": set_name, "accessory": set_name}}
				main.hero_equipment_items = {}
				main.hero_equipment_names = {}
				main.hero_skill_tree = {}
				main.hero_ascension = {}
				main.hero_breakthrough = {}
				main._setup_hero_skills()
				var state: Dictionary = main.hero_battle_state[id]
				var actual := [state["max_hp"], state["attack"], state["defense"], state["attack_interval_mult"], state["ult_gain_mult"], main._calculate_party_power()]
				# Equipment baseline is unchanged; the new default balanced formation adds 10% HP/ATK.
				var expected: Array = LEGACY_BASELINE[id][scenario].duplicate()
				for column in [0,1,5]: expected[column] = roundi(float(expected[column]) * 1.1)
				_check(actual == expected, "%s/%d equipment baseline plus balanced formation: %s" % [id, scenario, str(actual)])
				var world: Dictionary = main._world_party_snapshot()[0]
				_check(world["attack"] == state["attack"] and world["max_hp"] == state["max_hp"] and world["defense"] == state["defense"], "%s/%d field and world stats agree" % [id, scenario])
	main.free()

func _hunt_drop_sources() -> void:
	var main = _fixture()
	for zone_id in main._zone_data():
		var zone: Dictionary = main._zone_data()[zone_id]
		var sources_ok := true
		var found := 0
		var slots: Dictionary = {}
		var ids: Dictionary = {}
		for attempt in 120:
			var item: Dictionary = main._roll_equipment_drop(zone)
			if item.is_empty():
				continue
			found += 1
			sources_ok = sources_ok and item.get("origin") == "hunt" and item.get("source_id") == zone_id and item.get("set") == zone["equipment_set"] and not ids.has(item["id"])
			ids[item["id"]] = true
			slots[item["slot"]] = true
		_check(found > 40 and slots.size() == 3 and sources_ok, "%s production hunt drop pipeline creates unique region-specific items in all three slots" % zone_id)
		_check(main.raid_crystals == 0, "%s ordinary equipment drops never grant raid currency" % zone_id)
	# Settle an actually dead habitat through the same hunt reward entry point.
	main.enemy_wave = [{"hp": 0, "max_hp": 10, "habitat_pack": 0, "corps_id": 1}]
	main.invasion.reset(); main.invasion.register({})
	main.hunt_ai.encounter_id += 1
	main.hunt_ai.set_state(AutoHuntController.State.FIGHTING)
	var kills_before: int = main.combat_kills
	var gold_before: int = main.unclaimed_gold
	main._finish_hunt_target()
	_check(main.combat_kills == kills_before + 1 and main.unclaimed_gold > gold_before and main.raid_crystals == 0, "hunt settlement preserves ordinary pack rewards without adding raid currency")
	var settled := _wallet_snapshot(main)
	main._finish_hunt_target()
	_check(_wallet_snapshot(main) == settled, "duplicate hunt settlement cannot duplicate equipment or resources")
	main.free()

func _start_raid(main, zone_id: String) -> void:
	main.raid_running = false
	main.current_zone_id = zone_id
	main.active_screen = "raid"
	main._start_raid()
	main.combat_timer.stop()

func _raid_reward_flow() -> void:
	var main = _fixture()
	for zone_id in main._zone_data():
		main.raid_clears = {}
		main.loot_inventory = []
		main.equipment_overflow = []
		main.hero_equipment_items = {}
		var seen_slots: Dictionary = {}
		for clear_index in 5:
			_start_raid(main, zone_id)
			var crystals_before: int = main.raid_crystals
			var saves_before: int = main.save_calls
			main.raid_boss_hp = 0
			main._finish_raid("victory")
			var difficulty: int = main._zone_data()[zone_id]["difficulty"]
			var items: Array = main.raid_reward_receipt.get("items", [])
			var raids: Array = items.filter(func(item): return item.get("origin") == "raid")
			_check(main.raid_crystals == crystals_before + 6 + 6 * difficulty, "%s clear %d grants exact raid crystals" % [zone_id, clear_index + 1])
			_check(main.save_calls == saves_before + 1, "%s clear %d settles all raid rewards in one save" % [zone_id, clear_index + 1])
			_check(raids.size() == 1 and items.size() in [1, 2], "%s clear %d guarantees one raid set plus at most one hunt drop" % [zone_id, clear_index + 1])
			if raids.size() == 1:
				var raid: Dictionary = raids[0]
				_check(raid.get("source_id") == zone_id and raid.get("set") == RULES.ZONES[zone_id]["raid_set"] and not _find_item(main, str(raid["id"])).is_empty(), "%s raid receipt describes an actually retained regional set item" % zone_id)
				if clear_index == 4 and seen_slots.size() < 3:
					_check(not seen_slots.has(raid["slot"]), "%s fifth clear prioritizes a missing owned raid slot" % zone_id)
				seen_slots[raid["slot"]] = true
				if clear_index == 4:
					_check(raid["rarity"] == "전설", "%s fifth clear guarantees legendary raid gear" % zone_id)
			var settled := _wallet_snapshot(main)
			var receipt: Dictionary = main.raid_reward_receipt.duplicate(true)
			main._finish_raid("victory")
			_check(_wallet_snapshot(main) == settled and main.raid_reward_receipt == receipt, "%s duplicate victory cannot repeat currency, gear or save" % zone_id)
	for outcome in ["defeat", "timeout", "cancelled"]:
		_start_raid(main, "gray_meadow")
		var before := _wallet_snapshot(main)
		main._finish_raid(outcome)
		_check(_wallet_snapshot(main) == before and main.raid_outcome == outcome, "%s grants no crystals or equipment" % outcome)
	_start_raid(main, "gray_meadow")
	var before := _wallet_snapshot(main)
	main._finish_raid("victory")
	_check(main.raid_running and _wallet_snapshot(main) == before, "living boss rejects premature victory without rewards")
	main._finish_raid("cancelled")
	main.free()

func _runtime_snapshot(main) -> Dictionary:
	return {"states": main.hero_battle_state.duplicate(true), "runtime": main.hero_skill_runtime.duplicate(true), "position": main.expedition_position}

func _preserved_runtime(main, old: Dictionary, action: String) -> void:
	var valid: bool = main.active_screen == "combat" and main.combat_running and main.expedition_position == old["position"]
	for id in old["states"]:
		var previous: Dictionary = old["states"][id]
		var state: Dictionary = main.hero_battle_state[id]
		if int(previous["hp"]) == 0:
			valid = valid and int(state["hp"]) == 0 and not bool(state["alive"])
		else:
			valid = valid and absf(float(previous["hp"]) / float(previous["max_hp"]) - float(state["hp"]) / float(state["max_hp"])) <= 1.0 / float(state["max_hp"])
		for key in ["ultimate", "guard", "taunt"]:
			valid = valid and state[key] == previous[key]
		for key in ["remaining", "attack_remaining", "windup", "target_index"]:
			valid = valid and main.hero_skill_runtime[id][key] == old["runtime"][id][key]
	_check(valid, action + " preserves HP ratio, dead allies, cooldowns and active battle")

func _workshop_flow() -> void:
	var main = _fixture()
	var item := RULES.hunt_item("gray_meadow", "weapon", "전설", main.loot_rng)
	main.loot_inventory = [item]
	main.raid_crystals = 120
	var id := str(item["id"])
	var before := _wallet_snapshot(main)
	var invalid: Dictionary = main._gear_workshop_action(id, "preview", {"family": "invalid"})
	_check(not bool(invalid.get("ok", false)) and _wallet_snapshot(main) == before, "invalid workshop family cannot charge currency or save")
	var preview: Dictionary = main._gear_workshop_action(id, "preview", {"family": "assault"})
	var proposal: Dictionary = _find_item(main, id).get("proposal", {})
	_check(bool(preview.get("ok", false)) and main.raid_crystals == 108 and not proposal.is_empty(), "preview pays 12 crystals and persists candidates on the inventory item")
	_check(main.save_calls == int(before["saves"]) + 1 and main.saved_equipment["crystals"] == 108 and main.saved_equipment["inventory"][0]["proposal"] == proposal, "preview item and currency are present in the same save")
	before = _wallet_snapshot(main)
	main._gear_workshop_action(id, "preview", {"family": "assault"})
	_check(_wallet_snapshot(main) == before, "repeated preview preserves paid candidates without charging again")
	var chosen: Dictionary = proposal.get("options", [{}])[0].duplicate(true)
	var choose: Dictionary = main._gear_workshop_action(id, "choose", {"index": 0})
	_check(bool(choose.get("ok", false)) and main.raid_crystals == 108 and _find_item(main, id).get("affixes", []) == [chosen], "selection adds exactly the displayed candidate without another fee")
	for hero_id in main.hero_battle_state:
		var state: Dictionary = main.hero_battle_state[hero_id]
		state["hp"] = int(float(state["max_hp"]) * .45)
		state["ultimate"] = 63.0
		state["guard"] = 1.5
		state["taunt"] = .5
		main.hero_skill_runtime[hero_id]["remaining"] = 2.5
		main.hero_skill_runtime[hero_id]["attack_remaining"] = .8
		main.hero_skill_runtime[hero_id]["windup"] = .12
		main.hero_skill_runtime[hero_id]["target_index"] = 0
	main.hero_battle_state["mira"]["hp"] = 0
	main.hero_battle_state["mira"]["alive"] = false
	main._sync_party_hp_from_heroes()
	var runtime := _runtime_snapshot(main)
	main._equip_inventory_item(0, "leonhardt", id)
	var equipped: Dictionary = main.hero_equipment_items.get("leonhardt", {}).get("weapon", {})
	_check(equipped.get("id") == id and equipped.get("affixes") == [chosen] and bool(equipped.get("bound", false)), "manual equip preserves full source/affix item metadata and binds gear")
	_preserved_runtime(main, runtime, "affixed weapon equip")
	var attack_before: int = main.hero_battle_state["leonhardt"]["attack"]
	runtime = _runtime_snapshot(main)
	var removal: Dictionary = main._gear_workshop_action(id, "remove", {"index": 0}, "leonhardt", "weapon")
	_check(bool(removal.get("ok", false)) and main.raid_crystals == 102 and _find_item(main, id).get("affixes", []).is_empty() and int(_find_item(main, id).get("focus", 0)) == 1, "equipped option removal pays six crystals and retains item with one focus")
	if chosen.get("stat") == "attack_pct":
		_check(main.hero_battle_state["leonhardt"]["attack"] < attack_before, "removing an equipped attack option immediately updates live attack")
	_preserved_runtime(main, runtime, "equipped option removal")
	main._gear_workshop_action(id, "preview", {"family": "guard"}, "leonhardt", "weapon")
	var pending: Dictionary = _find_item(main, id).get("proposal", {}).duplicate(true)
	before = _wallet_snapshot(main)
	main._gear_workshop_action(id, "choose", {"index": -1}, "leonhardt", "weapon")
	_check(_wallet_snapshot(main) == before and _find_item(main, id).get("proposal", {}) == pending, "invalid candidate selection preserves paid equipped proposal")
	var discard: Dictionary = main._gear_workshop_action(id, "discard", {}, "leonhardt", "weapon")
	_check(bool(discard.get("ok", false)) and main.raid_crystals == int(before["crystals"]) and _find_item(main, id).get("proposal", {}).is_empty(), "discard clears the equipped proposal without refund or extra charge")
	var locked: Dictionary = main._gear_workshop_action(id, "toggle_lock", {}, "leonhardt", "weapon")
	_check(bool(locked.get("ok", false)) and bool(_find_item(main, id).get("locked", false)), "equipped gear lock is retained in full item metadata")
	_check(main.saved_equipment["equipped"]["leonhardt"]["weapon"] == _find_item(main, id), "latest save includes all equipped workshop state")
	main.free()

func _full_bag_protection() -> void:
	var main = _fixture()
	main.auto_salvage_min_rarity = "전설"
	main.loot_inventory = []
	for index in main.INVENTORY_CAP:
		var protected := RULES.raid_item("gray_meadow", "weapon", "희귀", main.loot_rng)
		protected["locked"] = true
		main.loot_inventory.append(protected)
	var original: Array = main.loot_inventory.duplicate(true)
	var raid := RULES.raid_item("moonrest_forest", "armor", "희귀", main.loot_rng)
	var gold_before: int = main.wallet_gold
	main._store_or_salvage_loot(raid)
	_check(main.loot_inventory == original and not _find_item(main, str(raid["id"])).is_empty() and main.wallet_gold == gold_before, "full bag never auto-salvages a raid set or existing locked gear")
	_check(main.equipment_overflow.size() == 1 and main.equipment_overflow[0]["id"] == raid["id"], "protected full-bag raid reward enters the overflow store")
	var option_item := RULES.hunt_item("gray_meadow", "accessory", "일반", main.loot_rng)
	option_item["affixes"] = [{"stat": "hp_pct", "value": 3}]
	main._store_or_salvage_loot(option_item)
	_check(main.equipment_overflow.size() == 2 and main.wallet_gold == gold_before and main.loot_inventory == original, "crafted common gear is protected even below the automatic salvage threshold")
	var before := _wallet_snapshot(main)
	var claim: Dictionary = main._gear_claim_overflow(str(raid["id"]))
	_check(not bool(claim.get("ok", false)) and _wallet_snapshot(main) == before, "full-bag overflow claim keeps the protected reward safely stored")
	main._decompose_inventory_item(0, str(main.loot_inventory[0]["id"]), true)
	_check(_wallet_snapshot(main) == before, "even confirmed manual decomposition cannot consume locked gear")
	main.loot_inventory.pop_back()
	var save_count: int = main.save_calls
	claim = main._gear_claim_overflow(str(raid["id"]))
	_check(bool(claim.get("ok", false)) and main.loot_inventory.size() == main.INVENTORY_CAP and main.equipment_overflow.size() == 1 and main.save_calls == save_count + 1, "opening a bag slot allows one atomic overflow claim")
	before = _wallet_snapshot(main)
	claim = main._gear_claim_overflow(str(raid["id"]))
	_check(not bool(claim.get("ok", false)) and _wallet_snapshot(main) == before, "duplicate overflow claim never duplicates equipment")
	main.free()

func _equip_fixture_item(main, item: Dictionary, hero_id := "leonhardt") -> void:
	main.loot_inventory.append(item)
	main._equip_inventory_item(main.loot_inventory.size() - 1, hero_id, str(item["id"]))

func _stat_effects_in_live_battle() -> void:
	var main = _fixture()
	main._restore_deployed_heroes(["leonhardt"])
	main._setup_hero_skills()
	for slot in RULES.SLOTS:
		_equip_fixture_item(main, RULES.normalize({"slot": slot, "rarity": "전설", "level": 4, "set": "초보자"}))
	var plain: Dictionary = main.hero_battle_state["leonhardt"].duplicate(true)
	for slot in RULES.SLOTS:
		var item := RULES.normalize({"slot": slot, "rarity": "전설", "level": 4, "set": "초보자"})
		item["affixes"] = [{"stat": "haste_pct", "value": 3}, {"stat": "ultimate_pct", "value": 5}] if slot == "armor" else [{"stat": "attack_pct", "value": 6}, {"stat": "hp_pct", "value": 8}, {"stat": "defense", "value": 4}]
		_equip_fixture_item(main, item)
	var changed: Dictionary = main.hero_battle_state["leonhardt"].duplicate(true)
	_check(changed["attack"] > plain["attack"] and changed["max_hp"] > plain["max_hp"] and changed["defense"] == int(plain["defense"]) + 8, "equipped attack, HP and defense options affect real battle stats")
	_check(changed["attack_interval_mult"] < plain["attack_interval_mult"] and changed["ult_gain_mult"] > plain["ult_gain_mult"], "equipped speed and ultimate options affect battle scheduling multipliers")
	var world: Dictionary = main._world_party_snapshot()[0]
	_check(world["attack"] == changed["attack"] and world["max_hp"] == changed["max_hp"] and world["defense"] == changed["defense"], "affixed gear provides the same attack, HP and defense to field and faction squads")
	_start_raid(main, "gray_meadow")
	main.pet_runtime = {"kind": "none"}
	main.raid_boss_attack_remaining = 1000.0
	main.hero_skill_runtime["leonhardt"]["remaining"] = 1000.0
	main.hero_skill_runtime["leonhardt"]["secondary_remaining"] = 1000.0
	main.hero_skill_runtime["leonhardt"]["passive_remaining"] = 1000.0
	main.hero_skill_runtime["leonhardt"]["attack_remaining"] = 0.0
	main.hero_battle_state["leonhardt"]["ultimate"] = 0.0
	var hp_before: int = main.raid_boss_hp
	main._advance_raid_encounter(.01)
	var state: Dictionary = main.hero_battle_state["leonhardt"]
	_check(hp_before - main.raid_boss_hp == int(changed["attack"]), "natural raid basic attack deals the affix-adjusted attack value")
	_check(is_equal_approx(float(main.hero_skill_runtime["leonhardt"]["attack_remaining"]), .78 * float(changed["attack_interval_mult"])), "natural raid basic attack schedules its next attack with equipment speed")
	_check(is_equal_approx(float(state["ultimate"]), 10.0 * float(changed["ult_gain_mult"])), "natural raid basic attack gains ultimate charge with its equipment option")
	main._finish_raid("cancelled")
	main.free()
	for zone_id in RULES.ZONES:
		main = _fixture()
		main._restore_deployed_heroes(["leonhardt"])
		main._setup_hero_skills()
		for slot in RULES.SLOTS:
			_equip_fixture_item(main, RULES.normalize({"slot": slot, "rarity": "희귀", "level": 1, "set": "초보자"}))
		plain = main.hero_battle_state["leonhardt"].duplicate(true)
		for slot in RULES.SLOTS:
			_equip_fixture_item(main, RULES.raid_item(zone_id, slot, "희귀", main.loot_rng))
		changed = main.hero_battle_state["leonhardt"].duplicate(true)
		if zone_id == "gray_meadow":
			_check(changed["max_hp"] > plain["max_hp"] and changed["ult_gain_mult"] > plain["ult_gain_mult"], "Dawn Pact three-piece set improves HP and ultimate charge in battle")
		elif zone_id == "forgotten_mine":
			_check(changed["max_hp"] > plain["max_hp"] and changed["defense"] == int(plain["defense"]) + 8, "Iron Oath three-piece set improves HP and defense in battle")
		else:
			_check(changed["attack"] > plain["attack"] and changed["attack_interval_mult"] < plain["attack_interval_mult"], "Eclipse Hunt three-piece set improves attack and speed in battle")
		world = main._world_party_snapshot()[0]
		_check(world["attack"] == changed["attack"] and world["max_hp"] == changed["max_hp"] and world["defense"] == changed["defense"], "%s raid set attack, HP and defense agree between battle modes" % zone_id)
		main.free()

func _market_local_lifecycle() -> void:
	var main = _fixture()
	main.loot_inventory = []
	var item := RULES.hunt_item("gray_meadow", "weapon", "희귀", main.loot_rng)
	item["affixes"] = [{"stat": "attack_pct", "value": 4}]
	main.loot_inventory.append(item)
	var item_id := str(item["id"])
	var snapshot: Dictionary = main._market_snapshot()
	_check(str(snapshot.get("mode", "")).contains("로컬") and snapshot.get("listings", []).is_empty(), "market honestly identifies an empty local exchange")
	var gold_before: int = main.wallet_gold
	var saves_before: int = main.save_calls
	var listing: Dictionary = main._market_submit("list", {"item_id": item_id, "price": 100, "request_id": "integration_list"})
	_check(bool(listing.get("ok", false)) and _find_item(main, item_id).is_empty() and main.wallet_gold == gold_before, "listing removes the exact crafted item into escrow without spending its sale price")
	_check(main.save_calls == saves_before + 1 and main.saved_equipment["inventory"].is_empty() and not main.saved_equipment["market"].is_empty(), "listing saves bag removal and exchange escrow in one state image")
	snapshot = main._market_snapshot()
	_check(snapshot.get("own_listings", []).size() == 1, "local snapshot returns the player's own active listing")
	var listing_id := str(listing.get("listing_id", ""))
	var rejected: Dictionary = main._market_submit("buy", {"listing_id": listing_id, "request_id": "integration_self_buy"})
	_check(not bool(rejected.get("ok", false)) and main.wallet_gold == gold_before and _find_item(main, item_id).is_empty(), "local player cannot buy their own escrowed item or duplicate ownership")
	var cancelled: Dictionary = main._market_submit("cancel", {"listing_id": listing_id, "request_id": "integration_cancel"})
	snapshot = main._market_snapshot()
	_check(bool(cancelled.get("ok", false)) and snapshot["account"].get("deliveries", []).size() == 1 and _find_item(main, item_id).is_empty(), "cancelling a listing moves equipment to delivery rather than duplicating it in the bag")
	saves_before = main.save_calls
	var claimed: Dictionary = main._market_submit("claim", {"item_id": item_id, "request_id": "integration_claim"})
	snapshot = main._market_snapshot()
	var returned := _find_item(main, item_id)
	_check(bool(claimed.get("ok", false)) and returned.get("affixes", []) == item["affixes"] and snapshot["account"].get("deliveries", []).is_empty(), "delivery claim restores the exact crafted equipment once")
	_check(main.save_calls == saves_before + 1 and main.saved_equipment["inventory"].size() == 1 and main.saved_equipment["market"] == main.gear_market_state, "delivery and bag are saved atomically in the same write")
	main._market_submit("claim", {"item_id": item_id, "request_id": "integration_claim"})
	_check(main.loot_inventory.size() == 1 and main.wallet_gold == gold_before, "replaying delivery claim cannot duplicate equipment or currency")
	main.free()

func _milestone_ownership_locations() -> void:
	for location in ["bag", "equipped", "overflow", "escrow", "delivery"]:
		var main = _fixture()
		var owned: Array = []
		for slot in ["weapon", "armor"]:
			owned.append(RULES.raid_item("gray_meadow", slot, "희귀", main.loot_rng))
		if location == "equipped":
			for item in owned:
				_equip_fixture_item(main, item)
		elif location == "overflow":
			main.equipment_overflow = owned.duplicate(true)
		else:
			main.loot_inventory = owned.duplicate(true)
			if location in ["escrow", "delivery"]:
				for item in owned:
					var listed: Dictionary = main._market_submit("list", {"item_id": item["id"], "price": 100})
					_check(bool(listed.get("ok", false)), "%s milestone fixture moves owned raid gear into market escrow" % location)
					if location == "delivery":
						var cancelled: Dictionary = main._market_submit("cancel", {"listing_id": listed.get("listing_id", "")})
						_check(bool(cancelled.get("ok", false)), "milestone fixture retains cancelled gear in delivery")
		main.raid_clears = {"gray_meadow": 4}
		_start_raid(main, "gray_meadow")
		main.raid_boss_hp = 0
		main._finish_raid("victory")
		var drops: Array = main.raid_reward_receipt.get("items", []).filter(func(item): return item.get("origin") == "raid")
		_check(drops.size() == 1 and drops[0]["slot"] == "accessory" and drops[0]["rarity"] == "전설", "fifth-clear pity counts owned gear in %s and supplies the missing legendary accessory" % location)
		main.free()

func _extract_trade_and_apply_flow() -> void:
	var seller = _fixture()
	seller.raid_crystals = 100
	var source := RULES.normalize({"slot": "weapon", "rarity": "전설", "level": 4, "affixes": [{"stat": "attack_pct", "value": 6}, {"stat": "hp_pct", "value": 7}], "focus": 2})
	_equip_fixture_item(seller, source)
	for hero_id in seller.hero_battle_state:
		var state: Dictionary = seller.hero_battle_state[hero_id]
		state["hp"] = int(float(state["max_hp"]) * .45)
		state["ultimate"] = 53.0
		state["guard"] = 1.0
		seller.hero_skill_runtime[hero_id]["remaining"] = 2.0
	seller.hero_battle_state["mira"]["hp"] = 0
	seller.hero_battle_state["mira"]["alive"] = false
	seller._sync_party_hp_from_heroes()
	var runtime := _runtime_snapshot(seller)
	var saves_before: int = seller.save_calls
	var extraction: Dictionary = seller._gear_extract_option(str(source["id"]), 1, "leonhardt", "weapon")
	_check(bool(extraction.get("ok", false)), "a self-found option can be extracted from equipped bound gear")
	if not bool(extraction.get("ok", false)):
		seller.free()
		return
	var crystal: Dictionary = extraction.get("crystal", {})
	var crystal_id := str(crystal.get("id", ""))
	var remaining := _find_item(seller, str(source["id"]))
	_check(remaining.get("affixes", []) == [{"stat": "attack_pct", "value": 6}] and remaining.get("focus") == 2, "extraction removes only the chosen option without granting deletion focus")
	_check(seller.raid_crystals == 82 and seller.save_calls == saves_before + 1, "extraction spends eighteen raid currency and commits once")
	_check(crystal.get("item_type") == "option_crystal" and crystal.get("stored_option", {}).get("stat") == "hp_pct" and int(crystal.get("stored_option", {}).get("value", 0)) == 7, "extracted crystal preserves the exact HP option value without rerolling")
	_check(not bool(crystal.get("bound", true)) and int(crystal.get("trade_count", 1)) == 0 and not _find_item(seller, crystal_id).is_empty(), "equipping self-found gear does not bind its freshly extracted sellable option")
	_check(seller.saved_equipment["crystals"] == 82 and seller.saved_equipment["equipped"]["leonhardt"]["weapon"]["affixes"] == remaining["affixes"], "one extraction save contains both currency deduction and original option removal")
	_check(int(seller.hero_battle_state["leonhardt"]["max_hp"]) < int(runtime["states"]["leonhardt"]["max_hp"]), "extracting equipped HP immediately removes its live stat bonus")
	_preserved_runtime(seller, runtime, "equipped HP option extraction")
	var listing: Dictionary = seller._market_submit("list", {"item_id": crystal_id, "price": 200})
	_check(bool(listing.get("ok", false)) and _find_item(seller, crystal_id).is_empty(), "option crystal can be registered for sale through the actual Main market action")
	if not bool(listing.get("ok", false)):
		seller.free()
		return
	var service = seller.gear_market_service
	var created: Dictionary = service.bootstrap_account("crystal_buyer", 1000, [], "옵션 구매자", "player")
	var bought: Dictionary = service.submit("crystal_buyer", {"action": "buy", "listing_id": listing["listing_id"], "request_id": "buy_crystal"}, int(Time.get_unix_time_from_system()))
	var delivered: Dictionary = service.submit("crystal_buyer", {"action": "claim", "item_id": crystal_id, "request_id": "claim_crystal"}, int(Time.get_unix_time_from_system()))
	var account: Dictionary = service.account_snapshot("crystal_buyer")
	_check(bool(created.get("ok", false)) and bool(bought.get("ok", false)) and bool(delivered.get("ok", false)) and int(account.get("gold", 0)) == 800, "a distinct buyer pays the asking price and receives the option crystal")
	var seller_gold: int = seller.wallet_gold
	var proceeds: Dictionary = seller._market_submit("claim", {"gold_only": true})
	_check(bool(proceeds.get("ok", false)) and seller.wallet_gold == seller_gold + 190, "seller can claim crystal-sale proceeds after the five-percent market fee")
	var purchased: Dictionary = {}
	for item in account.get("inventory", []):
		if item.get("id") == crystal_id:
			purchased = item.duplicate(true)
	_check(not purchased.is_empty() and bool(purchased.get("bound", false)) and int(purchased.get("trade_count", 0)) == 1 and int(purchased.get("stored_option", {}).get("value", 0)) == 7, "trading preserves the exact option value and records its one-trade ownership")
	if purchased.is_empty():
		seller.free()
		return
	# Transfer the authoritative buyer delivery snapshot into a separate Main
	# fixture to exercise the same client-side application action after purchase.
	var buyer = _fixture()
	buyer.wallet_gold = int(account["gold"])
	buyer.loot_inventory = account["inventory"].duplicate(true)
	buyer.raid_crystals = 100
	var target := RULES.normalize({"slot": "armor", "rarity": "전설", "level": 4, "affixes": [{"stat": "defense", "value": 2}]})
	_equip_fixture_item(buyer, target)
	var maximum_before: int = buyer.hero_battle_state["leonhardt"]["max_hp"]
	buyer.hero_battle_state["leonhardt"]["hp"] = int(maximum_before * .5)
	buyer._sync_party_hp_from_heroes()
	runtime = _runtime_snapshot(buyer)
	saves_before = buyer.save_calls
	var applied: Dictionary = buyer._gear_apply_crystal(crystal_id, str(target["id"]), "leonhardt", "armor")
	var target_after := _find_item(buyer, str(target["id"]))
	_check(bool(applied.get("ok", false)) and buyer.raid_crystals == 92 and _find_item(buyer, crystal_id).is_empty(), "purchased crystal application spends eight currency and consumes exactly one crystal")
	var affixes: Array = target_after.get("affixes", [])
	_check(affixes.size() == 2 and affixes[0].get("stat") == "defense" and affixes[1].get("stat") == "hp_pct" and int(affixes[1].get("value", 0)) == 7 and int(affixes[1].get("trade_count", 0)) == 1, "application keeps existing options and carries exact value plus purchased provenance")
	_check(buyer.save_calls == saves_before + 1 and buyer.saved_equipment["crystals"] == 92 and buyer.saved_equipment["equipped"]["leonhardt"]["armor"]["affixes"] == affixes, "one application save includes consumed crystal, added option and currency")
	_check(int(buyer.hero_battle_state["leonhardt"]["max_hp"]) > maximum_before, "applied HP crystal immediately improves equipped live stats")
	_preserved_runtime(buyer, runtime, "purchased HP option application")
	var settled := _wallet_snapshot(buyer)
	buyer._gear_apply_crystal(crystal_id, str(target["id"]), "leonhardt", "armor")
	_check(_wallet_snapshot(buyer) == settled, "repeating application cannot consume currency or duplicate an already-used option crystal")
	var extracted_again: Dictionary = buyer._gear_extract_option(str(target["id"]), 1, "leonhardt", "armor")
	var reused: Dictionary = extracted_again.get("crystal", {})
	_check(bool(extracted_again.get("ok", false)) and bool(reused.get("bound", false)) and int(reused.get("trade_count", 0)) == 1 and int(reused.get("stored_option", {}).get("value", 0)) == 7, "re-extraction of a purchased option retains its exact value and non-tradable provenance")
	var resell: Dictionary = buyer._market_submit("list", {"item_id": reused.get("id", ""), "price": 300})
	_check(not bool(resell.get("ok", false)) and not _find_item(buyer, str(reused.get("id", ""))).is_empty(), "applying and re-extracting an option cannot bypass the one-trade restriction")
	buyer.free()
	seller.free()

func _crystal_rejections_and_capacity() -> void:
	var main = _fixture()
	main.raid_crystals = 100
	var source := RULES.normalize({"slot": "weapon", "rarity": "전설", "affixes": [{"stat": "hp_pct", "value": 7}]})
	main.loot_inventory = [source]
	var before := _wallet_snapshot(main)
	var extraction: Dictionary = main._gear_extract_option(str(source["id"]), 10)
	_check(not bool(extraction.get("ok", false)) and _wallet_snapshot(main) == before, "invalid extraction index preserves original equipment and currency")
	extraction = main._gear_extract_option(str(source["id"]), 0, "", "", {"stat": "hp_pct", "value": 6})
	_check(not bool(extraction.get("ok", false)) and _wallet_snapshot(main) == before, "stale extraction confirmation cannot remove an option whose displayed value has changed")
	extraction = main._gear_extract_option(str(source["id"]), 0)
	_check(bool(extraction.get("ok", false)), "inventory option extraction succeeds before crystal rejection checks")
	if not bool(extraction.get("ok", false)):
		main.free()
		return
	var original_crystal: Dictionary = extraction.get("crystal", {}).duplicate(true)
	before = _wallet_snapshot(main)
	main._equip_inventory_item(main._gear_inventory_index(str(original_crystal["id"])), "leonhardt", str(original_crystal["id"]))
	_check(_wallet_snapshot(main) == before, "an option crystal cannot be equipped as an accessory through legacy equip actions")
	main._enhance_inventory_item(main._gear_inventory_index(str(original_crystal["id"])), str(original_crystal["id"]))
	_check(_wallet_snapshot(main) == before, "legacy equipment enhancement cannot spend gold on an option crystal")
	for scenario in ["duplicate", "full", "proposal", "locked_crystal", "no_currency", "missing_target", "equipment_as_crystal"]:
		var target := RULES.normalize({"slot": "accessory", "rarity": "전설", "level": 1})
		var crystal: Dictionary = original_crystal.duplicate(true)
		main.raid_crystals = 100
		if scenario == "duplicate":
			target["affixes"] = [{"stat": "hp_pct", "value": 3}]
		elif scenario == "full":
			target["rarity"] = "일반"
			target["affixes"] = [{"stat": "attack_pct", "value": 2}]
		elif scenario == "proposal":
			target["proposal"] = {"family": "assault", "options": [{"stat": "attack_pct", "value": 3}], "cost": 12}
		elif scenario == "locked_crystal":
			crystal["locked"] = true
		elif scenario == "no_currency":
			main.raid_crystals = 7
		main.loot_inventory = [target, crystal]
		before = _wallet_snapshot(main)
		var crystal_id: String = str(target["id"]) if scenario == "equipment_as_crystal" else str(crystal["id"])
		var target_id: String = "missing" if scenario == "missing_target" else str(target["id"])
		var result: Dictionary = main._gear_apply_crystal(crystal_id, target_id)
		_check(not bool(result.get("ok", false)) and _wallet_snapshot(main) == before, "%s crystal application rejection is atomic and preserves resources" % scenario)
	main.free()
	main = _fixture()
	main.raid_crystals = 100
	source = RULES.normalize({"slot": "weapon", "rarity": "전설", "affixes": [{"stat": "attack_pct", "value": 5}], "trade_count": 1, "bound": true})
	main.loot_inventory = [source]
	for index in main.INVENTORY_CAP - 1:
		var item := RULES.hunt_item("gray_meadow", "armor", "희귀", main.loot_rng)
		item["locked"] = true
		main.loot_inventory.append(item)
	var bag_before: Array = main.loot_inventory.duplicate(true)
	extraction = main._gear_extract_option(str(source["id"]), 0)
	var crystal: Dictionary = extraction.get("crystal", {})
	_check(bool(extraction.get("ok", false)) and main.loot_inventory.size() == main.INVENTORY_CAP and main.equipment_overflow.size() == 1, "full-bag extraction delivers its crystal to protected overflow without dropping equipment")
	_check(bool(crystal.get("bound", false)) and int(crystal.get("trade_count", 0)) == 1, "an option extracted from already-traded equipment inherits the no-resale restriction")
	var other_items_preserved := true
	for index in range(1, bag_before.size()):
		other_items_preserved = other_items_preserved and main.loot_inventory[index] == bag_before[index]
	_check(other_items_preserved and main.raid_crystals == 82 and _find_item(main, str(source["id"])).get("affixes", []).is_empty(), "full-bag extraction preserves every other item and removes the source option once")
	main.free()

func _run() -> void:
	_legacy_equipment_preserved()
	_hunt_drop_sources()
	_raid_reward_flow()
	_workshop_flow()
	_full_bag_protection()
	_stat_effects_in_live_battle()
	_market_local_lifecycle()
	_milestone_ownership_locations()
	_extract_trade_and_apply_flow()
	_crystal_rejections_and_capacity()
	await process_frame
	await create_timer(0.5).timeout
	await process_frame
	print("v54_equipment_integration checks=%d passed=%d failures=%s" % [checks, checks - failures.size(), JSON.stringify(failures)])
	quit(0 if failures.is_empty() else 1)
