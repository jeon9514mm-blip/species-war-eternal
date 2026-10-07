extends "res://tests/support/V83UpgradeTestBase.gd"
func _init() -> void: _run.call_deferred()
func _run() -> void:
	for faction in ["aurelia", "noxfera"]:
		var main = await make_main(faction, 3)
		main._open_combat_presets(); await settle()
		main.guardian_collection["moss"] = {"copies":1}
		main.guardian_equipped = "moss"
		var original_ids: Array = main._deployed_hero_ids()
		check(PRESET.save(main,0).ok, "save integrated preset " + faction)
		var saved: Dictionary = PRESET.get_preset(main,0)
		var first: String = str(original_ids[0])
		var old: Dictionary = main.hero_equipment_items[first].weapon.duplicate(true)
		var replacement: Dictionary = old.duplicate(true)
		replacement.id = "test_replacement_" + faction; replacement.level = int(old.level)+2
		main.hero_equipment_items[first].weapon = replacement
		main.loot_inventory.append(old)
		main._get_hero_equipment(first).weapon = replacement.level
		main.skill_auto = false; main.ultimate_auto = false
		main.guardian_equipped = main.GUARDIANS.starter(faction)
		var reversed: Array = original_ids.duplicate(); reversed.reverse(); main._restore_deployed_heroes(reversed)
		main._save_idle_state()
		var original_items: Array = items(main)
		var before: Dictionary = economic(main)
		var preview: Dictionary = PRESET.plan(main,0)
		check(preview.ok and preview.moved == 1, "plan identifies one equipment move")
		check(before == economic(main), "plan cannot mutate or spend")
		check(PRESET.apply(main,0,preview.token).ok, "atomic integrated apply")
		check(main._deployed_hero_ids() == original_ids and main.skill_auto and main.ultimate_auto, "party order and autos restored")
		check(main.guardian_equipped == "moss", "owned guardian restored with preset")
		check(main.hero_equipment_items[first].weapon.id == old.id and items(main) == original_items, "all item IDs conserved")
		check(main.wallet_gold == before.wallet_gold and main.wallet_gems == before.wallet_gems and main.hero_progress == before.hero_progress, "no currency or levels changed")
		var reloaded: Dictionary = main.save_store.read_save(main.save_state_path).data
		check(int(reloaded.save_version) == SaveStore.VERSION and reloaded.combat_presets[faction][0].heroes == original_ids, "integrated preset persisted in current schema")
		check(reloaded.daily_dungeon_runs == 3 and reloaded.weekly_trial_runs == 5, "save preserves consumed allowances")
		main.combat_presets = {}
		main._load_idle_state()
		check(PRESET.get_preset(main,0) == saved, "actual game loader restores full preset")
		check(items(main) == original_items, "save/load preserves physical item IDs")
		var plan: Dictionary = PRESET.plan(main,0)
		main.skill_auto = false
		check(not PRESET.apply(main,0,plan.token).ok, "changed setup rejects old preview")
		main.skill_auto = true
		# A deleted ID fails the whole proposal without modifying the roster or other gear.
		main.hero_equipment_items[first].weapon.id = "deleted_replaced_id"
		var missing_before: Dictionary = economic(main)
		check(not PRESET.apply(main,0).ok and economic(main) == missing_before, "missing saved gear is atomic rejection")
		main.hero_equipment_items[first].weapon.id = old.id
		# A stronger current revision of the same item must not be reverted by a preset.
		main.hero_equipment_items[first].weapon.level = 7
		check(PRESET.apply(main,0).ok and main._get_hero_equipment(first).weapon == 7, "preset references ID not historical enhance level")
		var bank: Dictionary = main.combat_presets.duplicate(true)
		var duplicate_id: String = main.hero_equipment_items[first].armor.id
		main.hero_equipment_items[first].armor.id = old.id
		check(not PRESET.save(main,0).ok and main.combat_presets == bank, "bad save cannot overwrite existing preset")
		main.hero_equipment_items[first].armor.id = duplicate_id
		var other: String = "noxfera" if faction == "aurelia" else "aurelia"
		check(PRESET.MODEL.sanitize(main.combat_presets)[other][0].is_empty(), "no cross-faction preset contamination")

		# Saved gear on a hero outside this roster must never be stolen automatically.
		var outside: String = str(ROSTER.roster(faction)[10].id)
		var safe_items: Dictionary = main.hero_equipment_items.duplicate(true)
		var safe_bag: Array = main.loot_inventory.duplicate(true)
		main._gear_item("",outside,"weapon"); main._gear_item("",outside,"armor"); main._gear_item("",outside,"accessory")
		var saved_weapon: Dictionary = main.hero_equipment_items[first].weapon.duplicate(true)
		var outside_weapon: Dictionary = main.hero_equipment_items[outside].weapon.duplicate(true)
		main.hero_equipment_items[first].weapon = outside_weapon
		main.hero_equipment_items[outside].weapon = saved_weapon
		var conflict: Dictionary = economic(main)
		check(not PRESET.apply(main,0).ok and economic(main) == conflict, "outside-owner conflict leaves both heroes unchanged")
		main.hero_equipment_items = safe_items; main.loot_inventory = safe_bag
		var valid_before: Dictionary = economic(main)
		main.guardian_collection.erase("moss")
		var missing_guardian: Dictionary = economic(main)
		check(not PRESET.apply(main,0).ok and economic(main) == missing_guardian, "unowned guardian blocks entire transaction")
		main.guardian_collection = valid_before.guardian_collection
		# Full bag is legal for an unchanged loadout; no phantom overflow needed.
		while main.loot_inventory.size() < main.INVENTORY_CAP:
			var copy: Dictionary = main.hero_equipment_items[first].weapon.duplicate(true)
			copy.id = "bag_fill_" + str(main.loot_inventory.size()); main.loot_inventory.append(copy)
		check(PRESET.plan(main,0).ok, "full inventory does not block no-op apply")
		var duplicate: Dictionary = main.loot_inventory[0].duplicate(true)
		main.loot_inventory.append(duplicate)
		check(not PRESET.plan(main,0).ok, "duplicate physical item IDs rejected")
		main.loot_inventory = safe_bag
		var clean_before: Dictionary = economic(main)
		main.set_meta("game_save_pending",true)
		check(not PRESET.apply(main,0).ok and not PRESET.save(main,1).ok, "pending save blocks preset changes")
		check(clean_before == economic(main), "blocked commands have no state side effects")
		main.set_meta("game_save_pending",false)
		await dispose(main)
	done("v83_loadout")
