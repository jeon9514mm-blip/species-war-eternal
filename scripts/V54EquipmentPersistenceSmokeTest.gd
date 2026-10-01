extends SceneTree

# Exercise the actual schema and file writer: item identity must survive a swap,
# a full bag, JSON serialization and restart without cloning ownership.
const RULES = preload("res://scripts/EquipmentRules.gd")
const MARKET = preload("res://scripts/EquipmentMarketService.gd")
var checks := 0
var failures: Array[String] = []
var fixture_root := "user://v54-equipment-persistence-%d" % OS.get_process_id()
var store := SaveStore.new()

func _init() -> void:
	_run.call_deferred()

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		push_error("V54 equipment persistence: " + label)

func _item(item_id: String, slot := "weapon") -> Dictionary:
	return RULES.normalize({"id": item_id, "slot": slot, "level": 6, "rarity": "전설", "name": "보존 검증 장비", "set": "새벽의 맹약", "origin": "raid", "source_id": "gray_meadow", "zone": "회색 초원", "bound": true, "locked": true, "trade_count": 1, "focus": 2, "affixes": [{"stat": "attack_pct", "value": 5}], "proposal": {"family": "guard", "options": [{"stat": "hp_pct", "value": 7}, {"stat": "defense", "value": 4}], "cost": 20}})

func _schema() -> void:
	var worn := _item("worn")
	var bag := _item("bag", "armor")
	var recovered := _item("recovered", "accessory")
	var raw := {
		"hero_equipment": {"leonhardt": {"weapon": 8, "armor": 3, "accessory": 1}},
		"hero_equipment_sets": {"leonhardt": {"weapon": "새벽의 맹약", "armor": "철벽의 맹세", "accessory": "월식의 추격"}},
		"hero_equipment_items": {"leonhardt": {"weapon": worn, "armor": worn, "head": recovered}, "fake": {"accessory": recovered}, "mira": []},
		"loot_inventory": [worn, bag, [], {"id": "invalid", "slot": "head"}],
		"equipment_overflow": [worn, bag, recovered, null],
		"raid_crystals": 717, "gear_auto_equip": false, "wallet_gold": 900, "hero_progress": {"leonhardt": {"level": 8, "xp": 17}}
	}
	var before := JSON.stringify(raw)
	var clean := SaveValidation.sanitize(raw, ["gray_meadow"])
	_check(JSON.stringify(raw) == before, "schema validation never mutates source ownership")
	_check(clean["hero_equipment_items"].size() == 1 and clean["hero_equipment_items"]["leonhardt"].size() == 1, "equipped metadata rejects unknown heroes, slots and slot mismatches")
	_check(clean["hero_equipment_items"]["leonhardt"]["weapon"] == worn, "worn item identity and protection metadata survive")
	_check(clean["hero_equipment"]["leonhardt"]["weapon"] == 8, "legacy equipment levels remain authoritative for runtime overlay")
	_check(clean["hero_equipment_sets"]["leonhardt"] == raw["hero_equipment_sets"]["leonhardt"], "all three raid sets survive legacy set projections")
	_check(clean["loot_inventory"] == [bag] and clean["equipment_overflow"] == [recovered], "worn, bag and recovery ownership resolve duplicates once")
	_check(clean["raid_crystals"] == 717 and not clean["gear_auto_equip"], "raid currency and explicit auto-equip opt-out persist")
	_check(clean["wallet_gold"] == 900 and clean["hero_progress"] == raw["hero_progress"], "equipment migration preserves existing gold and hero progression")

	var legacy := {"loot_inventory": [{"slot": "weapon", "rarity": "epic", "level": 5}], "hero_equipment": {"leonhardt": {"weapon": 7}}}
	var first := SaveValidation.sanitize(legacy, ["gray_meadow"])
	var second := SaveValidation.sanitize(legacy, ["gray_meadow"])
	_check(first["loot_inventory"][0]["id"] == second["loot_inventory"][0]["id"] and first["loot_inventory"][0]["rarity"] == "전설", "legacy item IDs are deterministic and legacy rarity migrates")
	_check(first["hero_equipment_items"].is_empty() and first["hero_equipment"]["leonhardt"]["weapon"] == 7 and first["gear_auto_equip"], "legacy saves keep worn levels without inventing ownership metadata")
	_check(SaveValidation.sanitize(first, ["gray_meadow"])["loot_inventory"] == first["loot_inventory"], "repeated normalization is idempotent for item identity")

	for invalid in [null, true, "500", [], {}, NAN, INF, -INF]:
		var invalid_clean := SaveValidation.sanitize({"raid_crystals": invalid, "gear_auto_equip": invalid, "hero_equipment_items": invalid, "equipment_overflow": invalid, "gear_market_state": invalid}, ["gray_meadow"])
		_check(invalid_clean["raid_crystals"] == 0 and invalid_clean["hero_equipment_items"].is_empty() and invalid_clean["equipment_overflow"].is_empty(), "malformed equipment roots and non-finite currency rejected " + str(invalid))
	_check(SaveValidation.sanitize({"raid_crystals": 1e100}, ["gray_meadow"])["raid_crystals"] == 1000000000, "finite overflowing raid currency clamps before integer conversion")
	_check(SaveValidation.sanitize({"raid_crystals": -99}, ["gray_meadow"])["raid_crystals"] == 0, "negative raid currency cannot become a credit")

func _nested_metadata() -> void:
	var malformed := {"id": "nested", "slot": "weapon", "rarity": "전설", "level": INF, "bound": [], "locked": "true", "trade_count": 1e100, "focus": -3, "origin": [], "name": {}, "affixes": [null, {"stat": "attack_pct", "value": INF}, {"stat": "hp_pct", "value": NAN}, {"stat": "defense", "value": []}, {"stat": "fake", "value": 100}, {"stat": "attack_pct", "value": 1e100}, {"stat": "attack_pct", "value": 3}], "proposal": {"family": "guard", "cost": -900, "options": [{"stat": "hp_pct", "value": 999}, {"stat": "defense", "value": 2}, {"stat": "ultimate_pct", "value": 4}]}}
	var clean := SaveValidation.sanitize({"loot_inventory": [malformed]}, ["gray_meadow"])
	var item: Dictionary = clean["loot_inventory"][0]
	_check(item["affixes"] == [{"stat": "attack_pct", "value": 6}], "saved affixes reject bad types, non-finite values and repeated stats")
	_check(item["level"] == 1 and item["trade_count"] == 1 and item["focus"] == 0 and not item["bound"] and not item["locked"], "item scalar metadata uses bounded typed defaults")
	_check(item["proposal"] == {"family": "guard", "cost": 20, "options": [{"stat": "hp_pct", "value": 8}, {"stat": "defense", "value": 2}]}, "saved proposal retains valid choices with recomputed cost and family limits")
	_check(item["power"] == 48, "saved power derives from rarity and level instead of arbitrary metadata")
	var invalid: Dictionary = SaveValidation.sanitize({"loot_inventory": [{"id": "empty_nested", "slot": "armor", "affixes": {}, "proposal": []}]}, ["gray_meadow"])["loot_inventory"][0]
	_check(invalid["affixes"].is_empty() and invalid["proposal"].is_empty(), "wrong nested option containers normalize without runtime errors")
	var blank: Dictionary = SaveValidation.sanitize({"loot_inventory": [{"id": "   ", "slot": "weapon"}]}, ["gray_meadow"])["loot_inventory"][0]
	var repeated: Dictionary = SaveValidation.sanitize({"loot_inventory": [{"id": "   ", "slot": "weapon"}]}, ["gray_meadow"])["loot_inventory"][0]
	_check(blank["id"] == repeated["id"], "blank legacy IDs are also stable between migrations")

func _capacity() -> void:
	var items: Array = []
	for index in 32:
		items.append(_item("bag_%d" % index))
	var extra := _item("overflow_existing")
	var clean := SaveValidation.sanitize({"loot_inventory": items, "equipment_overflow": [extra]}, ["gray_meadow"])
	_check(clean["loot_inventory"].size() == 30 and clean["equipment_overflow"].size() == 3, "oversized legacy bag moves protected excess into recovery storage")
	_check(clean["equipment_overflow"][0]["id"] == "bag_30" and clean["equipment_overflow"][2]["id"] == "overflow_existing", "bag spill preserves exact items alongside existing recovery items")
	var many: Array = []
	for index in 3002:
		many.append({"id": "overflow_%d" % index, "slot": "armor", "locked": true})
	var bounded := SaveValidation.sanitize({"equipment_overflow": many}, ["gray_meadow"])
	_check(bounded["equipment_overflow"].size() == 3000, "malformed over-cap recovery input is bounded to the runtime maximum")
	var ids: Dictionary = {}
	for item in bounded["equipment_overflow"]:
		ids[item["id"]] = true
	_check(ids.size() == 3000, "recovery cap does not clone or recycle item IDs")

func _trade_item(item_id: String) -> Dictionary:
	var item := _item(item_id)
	item["bound"] = false
	item["locked"] = false
	item["trade_count"] = 0
	item["proposal"] = {}
	return item

func _market_schema() -> void:
	var market := MARKET.new()
	var bag := _trade_item("market_bag")
	var escrow := _trade_item("market_escrow")
	_check(market.bootstrap_account("player_local", 800, [bag]).get("ok", false) and market.bootstrap_account("seller", 100, [escrow]).get("ok", false), "market ownership fixture creates independent wallets")
	var listed: Dictionary = market.submit("seller", {"request_id": "list-1", "action": "list", "item_id": "market_escrow", "price": 200}, 1000)
	_check(listed.get("ok", false), "real market moves listed gear into escrow")
	var raw := market.to_dict()
	# Reproduce an interrupted old save containing stale copies in several
	# containers. The game-owned worn and bag records must each win once.
	raw["accounts"]["player_local"]["deliveries"] = [bag, escrow]
	raw["accounts"]["seller"]["inventory"] = [bag, escrow]
	var clean := SaveValidation.sanitize({"hero_equipment_items": {"leonhardt": {"weapon": escrow}}, "loot_inventory": [bag], "gear_market_state": raw}, ["gray_meadow"])
	var state: Dictionary = clean["gear_market_state"]
	_check(state["accounts"]["player_local"]["inventory"] == [bag], "local market bag mirror is retained without cloning game ownership")
	_check(state["accounts"]["player_local"]["deliveries"].is_empty() and state["accounts"]["seller"]["inventory"].is_empty(), "market delivery and foreign bag duplicates yield to canonical game ownership")
	_check(state["listings"][listed["listing_id"]]["status"] == "cancelled", "duplicate active escrow cannot sell an already worn item")
	_check(clean["hero_equipment_items"]["leonhardt"]["weapon"]["id"] == "market_escrow" and clean["loot_inventory"][0]["id"] == "market_bag", "duplicate recovery preserves canonical worn and bag records")

	var purchase := MARKET.new()
	purchase.bootstrap_account("seller", 100, [_trade_item("delivery_once")])
	purchase.bootstrap_account("player_local", 800, [bag])
	var listing: Dictionary = purchase.submit("seller", {"request_id": "sale-list", "action": "list", "item_id": "delivery_once", "price": 200}, 1000)
	var buy_command := {"request_id": "purchase-once", "action": "buy", "listing_id": listing.get("listing_id", "")}
	var bought: Dictionary = purchase.submit("player_local", buy_command, 1001)
	_check(bought.get("ok", false), "actual purchase produces a persistent delivery and seller settlement")
	var transaction := SaveValidation.sanitize({"wallet_gold": purchase.account_snapshot("player_local")["gold"], "loot_inventory": [bag], "gear_market_state": purchase.to_dict()}, ["gray_meadow"])
	var path := fixture_root.path_join("market.json")
	_check(store.write_save(path, transaction).get("ok", false), "market receipt, game wallet and ownership commit together")
	var restored := SaveValidation.sanitize(store.read_save(path).get("data", {}), ["gray_meadow"])
	var restored_market := MARKET.new()
	restored_market.from_dict(restored["gear_market_state"], ["market_bag"])
	var account := restored_market.account_snapshot("player_local")
	_check(restored["wallet_gold"] == 600 and account["gold"] == 600 and account["deliveries"].size() == 1 and account["deliveries"][0]["bound"], "purchase reload preserves one paid wallet and one bound delivery")
	_check(restored_market.account_snapshot("seller")["pending_gold"] == 190, "seller settlement retains the exact five-percent fee")
	var duplicate: Dictionary = restored_market.submit("player_local", buy_command, 1002)
	_check(duplicate.get("duplicate", false) and restored_market.account_snapshot("player_local") == account, "replayed purchase after restart cannot spend or deliver again")

func _crystal(item_id: String, traded := false) -> Dictionary:
	var option := {"stat": "attack_pct", "value": 5}
	if traded:
		option["trade_count"] = 1
	return RULES.normalize({"id": item_id, "item_type": "option_crystal", "stored_option": option, "bound": traded, "trade_count": 1 if traded else 0})

func _crystal_schema() -> void:
	var crystal := _crystal("crystal_bag")
	var traded := _crystal("crystal_recovery", true)
	var clean := SaveValidation.sanitize({"hero_equipment_items": {"leonhardt": {"weapon": crystal, "armor": traded}}, "loot_inventory": [crystal], "equipment_overflow": [traded]}, ["gray_meadow"])
	_check(clean["hero_equipment_items"].is_empty(), "option crystals cannot become equipped metadata on load")
	_check(clean["loot_inventory"] == [crystal] and clean["equipment_overflow"] == [traded], "rejecting crystal equipment preserves its valid bag and recovery ownership")
	_check(clean["loot_inventory"][0].get("item_type") == "option_crystal" and clean["loot_inventory"][0].get("stored_option", {}).get("value") == 5, "extracted option kind and numeric value survive shared normalization")
	var path := fixture_root.path_join("crystals.json")
	_check(store.write_save(path, clean).get("ok", false), "option crystals persist through the verified save writer")
	var loaded := SaveValidation.sanitize(store.read_save(path).get("data", {}), ["gray_meadow"])
	_check(loaded["loot_inventory"] == clean["loot_inventory"] and loaded["equipment_overflow"] == clean["equipment_overflow"], "crystal identity, option and traded lineage survive a file round trip")
	_check(loaded["equipment_overflow"][0]["stored_option"].get("trade_count", 0) == 1 and loaded["equipment_overflow"][0]["bound"], "purchased crystal lineage remains bound after restart")

func _legacy_v30() -> void:
	var path := fixture_root.path_join("legacy-v30.json")
	var payload := {"save_version": 30, "wallet_gold": 9123, "selected_faction": "aurelia", "hero_equipment": {"leonhardt": {"weapon": 9, "armor": 7, "accessory": 3}}, "hero_equipment_sets": {"leonhardt": {"weapon": "월광", "armor": "강철", "accessory": "개척자"}}, "loot_inventory": [{"id": "old-v30-item", "slot": "armor", "level": 7, "rarity": "희귀", "set": "강철"}]}
	var canonical = JSON.parse_string(JSON.stringify(payload))
	payload[SaveStore.INTEGRITY_KEY] = {"format": 1, "sha256": JSON.stringify(canonical).sha256_text()}
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(payload))
	file.close()
	var old := store.read_save(path)
	_check(old.get("ok", false) and old.get("migrated", false), "authentic version-30 checksum remains readable for migration")
	var migrated := SaveValidation.sanitize(old.get("data", {}), ["gray_meadow"])
	_check(migrated["wallet_gold"] == 9123 and migrated["hero_equipment"]["leonhardt"] == payload["hero_equipment"]["leonhardt"] and migrated["hero_equipment_sets"]["leonhardt"] == payload["hero_equipment_sets"]["leonhardt"], "version-30 wallet, enhancement and field sets are preserved")
	_check(migrated["raid_crystals"] == 0 and migrated["equipment_overflow"].is_empty() and migrated["hero_equipment_items"].is_empty() and migrated["loot_inventory"][0]["id"] == "old-v30-item", "migration initializes new fields without replacing existing item IDs")
	_check(store.write_save(path, migrated).get("ok", false) and int(store.read_save(path)["data"]["save_version"]) == SaveStore.VERSION, "migrated state commits under the new downgrade-protected version")

func _store_roundtrip() -> void:
	var path := fixture_root.path_join("roundtrip.json")
	var data := SaveValidation.sanitize({"hero_equipment_items": {"leonhardt": {"weapon": _item("roundtrip_worn")}}, "loot_inventory": [_item("roundtrip_bag", "armor")], "equipment_overflow": [_item("roundtrip_overflow", "accessory")], "raid_crystals": 719, "gear_auto_equip": false}, ["gray_meadow"])
	_check(bool(store.write_save(path, data).get("ok", false)), "new equipment schema commits atomically")
	var read := store.read_save(path)
	_check(bool(read.get("ok", false)) and int(read.get("data", {}).get("save_version", 0)) == SaveStore.VERSION, "equipment save has current version and valid checksum")
	var loaded := SaveValidation.sanitize(read.get("data", {}), ["gray_meadow"])
	for field in ["hero_equipment_items", "loot_inventory", "equipment_overflow", "raid_crystals", "gear_auto_equip"]:
		_check(loaded[field] == data[field], "JSON round trip preserves " + field)
	data["raid_crystals"] = 718
	_check(bool(store.write_save(path, data).get("ok", false)), "updated equipment transaction commits")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("{truncated")
	file.close()
	var recovered := store.read_save(path)
	_check(recovered.get("source") == "backup" and int(recovered["data"]["raid_crystals"]) == 719 and recovered["data"]["hero_equipment_items"]["leonhardt"]["weapon"]["id"] == "roundtrip_worn", "damaged primary restores one coherent currency and ownership generation")

func _new_main(path: String):
	var main = load("res://scenes/Main.tscn").instantiate()
	main.save_state_path = path
	root.add_child(main)
	await process_frame
	main.set_physics_process(false)
	main.set_process(false)
	return main

func _dispose_main(main) -> void:
	main.active_screen = ""
	main.combat_running = false
	main.free()

func _main_roundtrip() -> void:
	var path := fixture_root.path_join("main.json")
	var main = await _new_main(path)
	main.selected_faction = "aurelia"
	main._setup_hero_progress(main._hero_roster_for_faction())
	main.deployed_heroes = main._hero_roster_for_faction().slice(0, 1)
	main._offline_checked = true
	main.wallet_gold = 10000
	main.raid_crystals = 713
	main.gear_auto_equip = false
	var worn := _item("main_worn")
	worn["proposal"] = {}
	main.loot_inventory = [worn]
	main.equipment_overflow = [_item("main_recovery", "accessory")]
	_check(main._equip_item_direct(0, "leonhardt"), "real Main equips a full item with stable identity")
	main._enhance_equipment(main.deployed_heroes[0], "weapon")
	main._save_idle_state()
	_check(main.last_save_status == "saved", "real Main commits new equipment fields")
	_dispose_main(main)
	var restored = await _new_main(path)
	_check(restored.raid_crystals == 713 and not restored.gear_auto_equip and restored.equipment_overflow[0]["id"] == "main_recovery", "Main restores currency, settings and protected recovery equipment")
	var restored_worn: Dictionary = restored.hero_equipment_items.get("leonhardt", {}).get("weapon", {})
	_check(restored_worn.get("id") == "main_worn" and restored_worn.get("affixes") == worn["affixes"] and restored_worn.get("source_id") == "gray_meadow", "Main restart retains worn identity, random options and source")
	_check(int(restored.hero_equipment["leonhardt"]["weapon"]) == 7, "legacy enhancement level survives full-item persistence")
	var returned_starter_id: String = restored.loot_inventory[0]["id"]
	_check(restored._equip_item_direct(0, "leonhardt"), "restored Main swaps the original item back out")
	var returned: Dictionary = restored.loot_inventory[0]
	_check(returned["id"] == "main_worn" and returned["affixes"] == worn["affixes"] and int(returned["level"]) == 7 and returned["locked"] and returned["bound"], "unequip preserves enhanced full metadata rather than reconstructing a new item")
	_check(restored.hero_equipment_items["leonhardt"]["weapon"]["id"] == returned_starter_id, "original starter ID also survives repeated swaps")
	restored._save_idle_state()
	_dispose_main(restored)
	var again = await _new_main(path)
	_check(again.loot_inventory[0]["id"] == "main_worn" and again.loot_inventory[0]["affixes"] == worn["affixes"], "second restart retains the unequipped crafted item exactly once")
	_dispose_main(again)

func _main_crystal_roundtrip() -> void:
	var path := fixture_root.path_join("main-crystal.json")
	var main = await _new_main(path)
	main.selected_faction = "aurelia"
	main._setup_hero_progress(main._hero_roster_for_faction())
	main.deployed_heroes = main._hero_roster_for_faction().slice(0, 1)
	main._offline_checked = true
	main.gear_auto_equip = false
	main.wallet_gold = 1000
	main.raid_crystals = 1000
	main.loot_inventory = [_trade_item("crystal_source")]
	_check(main._equip_item_direct(0, "leonhardt"), "crystal fixture equips a never-traded source item")
	var extracted: Dictionary = main._gear_extract_option("crystal_source", 0, "leonhardt", "weapon")
	_check(extracted.get("ok", false) and main.raid_crystals == 982, "real Main extraction charges exactly 18 raid currency")
	if not extracted.get("ok", false):
		_dispose_main(main)
		return
	var crystal: Dictionary = extracted["crystal"]
	var crystal_id: String = crystal["id"]
	_check(crystal.get("item_type") == "option_crystal" and crystal["stored_option"]["value"] == 5 and RULES.tradable(crystal), "extraction preserves the option value and creates a distinct tradable crystal")
	_dispose_main(main)
	var restored = await _new_main(path)
	_check(restored.raid_crystals == 982 and restored.hero_equipment_items["leonhardt"]["weapon"]["affixes"].is_empty(), "restart keeps extracted option removed and extraction currency already spent")
	var crystal_index: int = restored._gear_inventory_index(crystal_id)
	_check(crystal_index >= 0 and restored.loot_inventory[crystal_index]["stored_option"] == crystal["stored_option"], "extracted crystal ID and exact value survive real Main restart")
	if crystal_index < 0:
		_dispose_main(restored)
		return
	# Trusted two-account fixture places that serialized crystal in a supplier
	# offer. All subsequent purchase, delivery, application and saves use Main.
	restored.loot_inventory.remove_at(crystal_index)
	var market := MARKET.new()
	_check(market.bootstrap_account("supplier", 100, [crystal]).get("ok", false) and market.bootstrap_account("player_local", restored.wallet_gold, restored.loot_inventory).get("ok", false), "trade fixture has one crystal owner and mirrors the actual local bag")
	var now := int(Time.get_unix_time_from_system())
	var listed: Dictionary = market.submit("supplier", {"request_id": "crystal-list", "action": "list", "item_id": crystal_id, "price": 200}, now)
	_check(listed.get("ok", false), "extracted crystal is accepted as a market offer")
	var listing_id: String = listed.get("listing_id", "")
	restored.gear_market_state = market.to_dict()
	restored._gear_market_loaded = false
	restored._save_idle_state()
	_dispose_main(restored)
	var buyer = await _new_main(path)
	var bought: Dictionary = buyer._market_submit("buy", {"listing_id": listing_id})
	_check(bought.get("ok", false) and buyer.wallet_gold == 800, "real Main purchases the persisted crystal offer once")
	_dispose_main(buyer)
	var delivered = await _new_main(path)
	var account: Dictionary = delivered.gear_market_state.get("accounts", {}).get("player_local", {})
	_check(account.get("deliveries", []).size() == 1 and account["deliveries"][0]["id"] == crystal_id and account["deliveries"][0]["trade_count"] == 1 and account["deliveries"][0]["bound"], "purchased crystal survives restart as one bound delivery")
	var claimed: Dictionary = delivered._market_submit("claim", {"item_id": crystal_id})
	_check(claimed.get("ok", false), "real Main claims the persisted crystal delivery")
	var applied: Dictionary = delivered._gear_apply_crystal(crystal_id, "crystal_source", "leonhardt", "weapon")
	_check(applied.get("ok", false) and delivered.raid_crystals == 974 and delivered._gear_inventory_index(crystal_id) < 0, "Main application consumes exactly one crystal and eight raid currency")
	_dispose_main(delivered)
	var final_main = await _new_main(path)
	var final_item: Dictionary = final_main.hero_equipment_items.get("leonhardt", {}).get("weapon", {})
	var affixes: Array = final_item.get("affixes", [])
	_check(affixes.size() == 1 and affixes[0] == {"stat": "attack_pct", "value": 5, "trade_count": 1}, "application restart preserves exact option value and purchased lineage")
	_check(final_item.get("bound", false) and not RULES.tradable(final_item) and final_main.raid_crystals == 974 and final_main.wallet_gold == 800, "restart keeps equipped binding and both already-spent currencies")
	_check(final_main._gear_inventory_index(crystal_id) < 0 and final_main.gear_market_state["accounts"]["player_local"]["deliveries"].is_empty(), "consumed crystal cannot return from a stale bag or market delivery")
	_dispose_main(final_main)

func _remove_tree(path: String) -> void:
	var directory := DirAccess.open(path)
	if directory == null:
		return
	for entry in directory.get_files():
		directory.remove(entry)
	for entry in directory.get_directories():
		_remove_tree(path.path_join(entry))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(fixture_root))
	_schema()
	_nested_metadata()
	_crystal_schema()
	_capacity()
	_legacy_v30()
	_store_roundtrip()
	_market_schema()
	if "--schema-only" not in OS.get_cmdline_user_args():
		await _main_roundtrip()
		await _main_crystal_roundtrip()
	_remove_tree(fixture_root)
	await create_timer(0.5).timeout
	await process_frame
	print("v54_equipment_persistence_smoke_test checks=%d passed=%d failures=%s" % [checks, checks - failures.size(), JSON.stringify(failures)])
	quit(0 if failures.is_empty() else 1)
