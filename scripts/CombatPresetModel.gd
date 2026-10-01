extends RefCounted
## Save schema: references only, never copies of owned equipment or currencies.
const HEROES = preload("res://scripts/HeroRosterCatalog.gd")
const FACTIONS: Array[String] = ["aurelia", "noxfera"]
const SLOTS: Array[String] = ["weapon", "armor", "accessory"]
static func sanitize(raw: Variant) -> Dictionary:
	var out: Dictionary = {"aurelia": [{}, {}, {}], "noxfera": [{}, {}, {}]}
	if typeof(raw) != TYPE_DICTIONARY: return out
	for faction: String in FACTIONS:
		var bank: Variant = raw.get(faction, [])
		if typeof(bank) != TYPE_ARRAY: continue
		for i in mini(3, bank.size()):
			var p: Variant = bank[i]
			if typeof(p) != TYPE_DICTIONARY or typeof(p.get("heroes")) != TYPE_ARRAY: continue
			var ids: Array[String] = []
			var valid: bool = true
			for id: Variant in p["heroes"]:
				if typeof(id) != TYPE_STRING or not HEROES.HEROES.has(id) or str(HEROES.HEROES[id].get("faction", "")) != faction or id in ids:
					valid = false; break
				ids.append(id)
				if ids.size() > 10: valid = false; break
			if not valid or ids.is_empty(): continue
			var gear: Dictionary = {}
			var source: Variant = p.get("equipment", {})
			if typeof(source) != TYPE_DICTIONARY: continue
			var used: Dictionary = {}
			for id: String in ids:
				gear[id] = {}
				var slots: Variant = source.get(id, {})
				if typeof(slots) != TYPE_DICTIONARY: valid = false; break
				for slot: String in SLOTS:
					var item: Variant = slots.get(slot, "")
					if typeof(item) != TYPE_STRING or item.is_empty() or item.length() > 160 or used.has(item):
						valid = false; break
					gear[id][slot] = item; used[item] = true
			if not valid: continue
			var guardian: String = p.get("guardian", "") if typeof(p.get("guardian")) == TYPE_STRING else ""
			out[faction][i] = {"schema": 1, "formation_id": preload("res://scripts/BattleFormation.gd").sanitize(p.get("formation_id")), "heroes": ids, "equipment": gear, "guardian": guardian.left(100),
				"skill_auto": p.get("skill_auto", true) if typeof(p.get("skill_auto")) == TYPE_BOOL else true,
				"ultimate_auto": p.get("ultimate_auto", true) if typeof(p.get("ultimate_auto")) == TYPE_BOOL else true}
	return out
