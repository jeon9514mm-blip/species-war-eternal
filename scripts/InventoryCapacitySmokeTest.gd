extends SceneTree

class InventoryFixture:
	extends "res://scripts/Main.gd"
	var save_calls := 0
	func _save_idle_state() -> void:
		save_calls += 1

const RULES = preload("res://scripts/EquipmentRules.gd")
const MARKET = preload("res://scripts/EquipmentMarketService.gd")
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)

func item(id: String, locked: bool = true) -> Dictionary:
	return RULES.normalize({"id": id, "name": id, "slot": "weapon", "rarity": "희귀", "level": 1, "locked": locked, "origin": "hunt"})

func bag(count: int) -> Array:
	var items: Array = []
	for index in count:
		items.append(item("bag_%03d" % index))
	return items

func snapshot(main) -> Dictionary:
	return {"bag": main.loot_inventory.duplicate(true), "overflow": main.equipment_overflow.duplicate(true), "gold": main.wallet_gold, "crystals": main.raid_crystals, "saves": main.save_calls}

func _runtime_boundary() -> void:
	var main := InventoryFixture.new()
	check(main.INVENTORY_CAP == 200 and SaveValidation.INVENTORY_CAP == 200 and MARKET.INVENTORY_CAP == 200, "runtime, save and market share the 200-slot limit")
	main.auto_salvage_min_rarity = "일반"
	main.loot_inventory = bag(199)
	var original: Array = main.loot_inventory.duplicate(true)
	main._store_or_salvage_loot(item("reward_200"))
	check(main.loot_inventory.size() == 200 and main.equipment_overflow.is_empty(), "199 to 200 accepts the last item in the bag")
	check(main.loot_inventory.slice(0, 199) == original and main.loot_inventory[199]["id"] == "reward_200", "the 200th reward preserves every existing item and its own identity")
	var full: Array = main.loot_inventory.duplicate(true)
	var gold: int = main.wallet_gold
	main._store_or_salvage_loot(item("protected_201"))
	check(main.loot_inventory == full and main.wallet_gold == gold and main.equipment_overflow == [item("protected_201")], "the 201st protected reward is preserved in recovery storage without salvaging locked gear")
	var before := snapshot(main)
	check(not main._gear_claim_overflow("protected_201").get("ok", false) and snapshot(main) == before, "claiming recovery gear into 200 slots is rejected atomically")
	main.loot_inventory.remove_at(0)
	check(main._gear_claim_overflow("protected_201").get("ok", false) and main.loot_inventory.size() == 200 and main.equipment_overflow.is_empty(), "one free slot receives the protected reward exactly once")
	before = snapshot(main)
	check(not main._gear_claim_overflow("protected_201").get("ok", false) and snapshot(main) == before, "replaying a recovery claim never clones an item")
	var salvage_item := item("ordinary_201", false)
	gold = main.wallet_gold
	full = main.loot_inventory.duplicate(true)
	main._store_or_salvage_loot(salvage_item)
	check(main.loot_inventory == full and main.equipment_overflow.is_empty() and main.wallet_gold == gold + main._inventory_salvage_value(salvage_item), "existing ordinary-loot salvage compensates the 201st item and preserves locked gear")
	main.free()

func _crystal_boundary() -> void:
	var main := InventoryFixture.new()
	main.raid_crystals = 1000
	main.loot_inventory = bag(199)
	main.loot_inventory[0] = RULES.normalize({"id": "source", "slot": "weapon", "rarity": "전설", "affixes": [{"stat": "attack_pct", "value": 5}]})
	main.loot_inventory[1] = RULES.normalize({"id": "target", "slot": "armor", "rarity": "전설"})
	var extracted: Dictionary = main._gear_extract_option("source", 0)
	var crystal: Dictionary = extracted.get("crystal", {})
	check(extracted.get("ok", false) and extracted.get("destination", "") == "inventory" and main.loot_inventory.size() == 200, "extracting an option at 199 uses the last bag slot")
	check(main._gear_item("source").get("affixes", []).is_empty() and crystal.get("stored_option", {}).get("value", 0) == 5, "extraction moves the exact option once")
	var applied: Dictionary = main._gear_apply_crystal(str(crystal.get("id", "")), "target")
	check(applied.get("ok", false) and main.loot_inventory.size() == 199 and main._gear_item("target").get("affixes", []) == [{"stat": "attack_pct", "value": 5}], "crystal application from a full bag consumes one slot and preserves its exact stat")
	var before := snapshot(main)
	check(not main._gear_apply_crystal(str(crystal.get("id", "")), "source").get("ok", false) and snapshot(main) == before, "a consumed crystal cannot be applied a second time")
	main.loot_inventory.append(item("fill_200"))
	extracted = main._gear_extract_option("target", 0)
	crystal = extracted.get("crystal", {})
	check(extracted.get("ok", false) and extracted.get("destination", "") == "overflow" and main.loot_inventory.size() == 200 and main.equipment_overflow.size() == 1, "extracting at 200 sends the crystal into protected storage")
	check(main.equipment_overflow[0] == crystal and main._gear_item("target").get("affixes", []).is_empty(), "full-bag extraction retains exact crystal identity with one source removal")
	main.loot_inventory[0]["affixes"] = [{"stat": "hp_pct", "value": 5}]
	main.equipment_overflow.clear()
	for index in main.GEAR_OVERFLOW_CAP:
		main.equipment_overflow.append(item("recovery_%d" % index))
	before = snapshot(main)
	check(not main._gear_extract_option("source", 0).get("ok", false) and snapshot(main) == before, "full bag and full protected storage reject extraction without losing the option or currency")
	main.free()

func _save_boundary() -> void:
	var items := bag(201)
	var overflow_item := item("already_protected")
	var legacy := SaveValidation.sanitize({"save_version": 37, "loot_inventory": items.slice(0, 30)}, ["gray_meadow"])
	check(legacy["loot_inventory"] == items.slice(0, 30) and legacy["equipment_overflow"].is_empty(), "an existing 30-item v37 save stays intact without a schema migration")
	var clean := SaveValidation.sanitize({"save_version": 37, "loot_inventory": items, "equipment_overflow": [items[200], overflow_item, items[0]]}, ["gray_meadow"])
	check(clean["loot_inventory"].size() == 200 and clean["equipment_overflow"] == [items[200], overflow_item], "save validation keeps 200 bag items and deduplicates spill plus existing recovery items")
	var store := SaveStore.new()
	var folder := "user://inventory-capacity-%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	var path := folder.path_join("save.json")
	check(store.write_save(path, clean).get("ok", false), "200-slot save commits through the real integrity-protected writer")
	var read := store.read_save(path)
	check(read.get("ok", false), "integrity-protected save is readable after writing")
	var restored := SaveValidation.sanitize(read.get("data", {}), ["gray_meadow"])
	check(restored["loot_inventory"] == clean["loot_inventory"] and restored["equipment_overflow"] == clean["equipment_overflow"], "file round trip restores every bag and recovery identity without loss or duplication")
	check(store.write_save(path, restored).get("ok", false), "restored 200-slot state can be saved again")
	var twice := SaveValidation.sanitize(store.read_save(path).get("data", {}), ["gray_meadow"])
	check(twice["loot_inventory"] == clean["loot_inventory"] and twice["equipment_overflow"] == clean["equipment_overflow"] and SaveStore.VERSION == 37, "second save/load retains identities and save version 37")
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(folder))

func _run() -> void:
	_runtime_boundary()
	_crystal_boundary()
	_save_boundary()
	print("inventory_capacity checks=%d failures=%d" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
