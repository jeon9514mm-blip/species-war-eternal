extends RefCounted

## v83: GuardianProgressionService. Main remains the single owner of mutable game state.
## The injected host supplies state, virtual UI hooks and runtime refreshes.
## No cached host reference, duplicate wallet, RNG or save schema is introduced.

static func guardian_ensure_starter(main: Node) -> void:
	var starter_id: String = main.GUARDIANS.starter(main.selected_faction)
	if starter_id.is_empty(): return
	if not main.guardian_collection.has(starter_id): main.guardian_collection[starter_id] = {"copies":1}
	if not main.guardian_collection.has(main.guardian_equipped) or main.GUARDIANS.profile(main.guardian_equipped).is_empty():
		main.guardian_equipped = starter_id


static func pet_profile(main: Node) -> Dictionary:
	main._guardian_ensure_starter()
	if main.guardian_equipped.is_empty():
		return {"name":"", "kind":"none", "interval":2.0, "description":""}
	return main.GUARDIANS.profile(main.guardian_equipped)


static func guardian_bonus(main: Node, key: String) -> float:
	var profile = main._pet_profile()
	if profile.is_empty() or not main.guardian_collection.has(main.guardian_equipped):return 0.0
	return main.GUARDIANS.bonus(profile, int(main.guardian_collection[main.guardian_equipped].get("copies",1)), key)


static func guardian_reward(main: Node, value: int, key: String) -> int:
	return maxi(0,int(round(minf(float(value),1000000000000.0)*(1.0+main._guardian_bonus(key)))))


static func guardian_equip(main: Node, id: String) -> bool:
	if not preload("res://scripts/SaveSafety.gd").allow_mutation(main): return false
	if not main.guardian_collection.has(id) or main.GUARDIANS.profile(id).is_empty():return false
	main.guardian_equipped=id
	main._refresh_growth_runtime()
	main._setup_pet_runtime()
	main._save_idle_state()
	return true


static func pet_progress_key(main: Node) -> String:
	return main.selected_faction if main.selected_faction in ["aurelia", "noxfera"] else "none"


static func get_pet_progress(main: Node) -> Dictionary:
	var key = main._pet_progress_key()
	if key == "none":
		return {"level": 1, "xp": 0, "evolution": 0}
	if not main.pet_progress.has(key) or typeof(main.pet_progress[key]) != TYPE_DICTIONARY:
		main.pet_progress[key] = {"level": 1, "xp": 0, "evolution": 0}
	var progress: Dictionary = main.pet_progress[key]
	progress["level"] = clampi(int(progress.get("level", 1)), 1, main.MAX_PET_LEVEL)
	progress["xp"] = clampi(int(progress.get("xp", 0)), 0, 100000000) if int(progress["level"]) < main.MAX_PET_LEVEL else 0
	progress["evolution"] = main._pet_evolution_for_level(int(progress["level"]))
	main.pet_progress[key] = progress
	return progress


static func pet_xp_to_next(main: Node, level: int) -> int:
	return 60 + (clampi(level, 1, main.MAX_PET_LEVEL) - 1) * 35


@warning_ignore("unused_parameter")
static func pet_evolution_for_level(main: Node, level: int) -> int:
	if level >= 10:
		return 2
	if level >= 5:
		return 1
	return 0


@warning_ignore("unused_parameter")
static func pet_evolution_name(main: Node, evolution: int) -> String:
	return ["유년", "각성", "초월"][clampi(evolution, 0, 2)]


static func grant_pet_xp(main: Node, amount: int) -> String:
	if amount <= 0 or main._pet_progress_key() == "none":
		return ""
	var progress = main._get_pet_progress()
	progress["xp"] = int(progress["xp"]) + mini(amount, 100000000)
	var level = int(progress["level"])
	var old_evolution = int(progress["evolution"])
	var leveled = false
	while level < main.MAX_PET_LEVEL and int(progress["xp"]) >= main._pet_xp_to_next(level):
		progress["xp"] = int(progress["xp"]) - main._pet_xp_to_next(level)
		level += 1
		leveled = true
	progress["level"] = level
	if level >= main.MAX_PET_LEVEL:
		progress["xp"] = 0
	progress["evolution"] = main._pet_evolution_for_level(level)
	main.pet_progress[main._pet_progress_key()] = progress
	if not main.pet_runtime.is_empty():
		main.pet_runtime["level"] = level
		main.pet_runtime["evolution"] = int(progress["evolution"])
	if int(progress["evolution"]) > old_evolution:
		return "%s 진화! %s 단계" % [str(main._pet_profile().get("name", "수호신")), main._pet_evolution_name(int(progress["evolution"]))]
	if leveled:
		return "%s Lv.%d" % [str(main._pet_profile().get("name", "수호신")), level]
	return "수호신 XP +%d" % amount


static func setup_pet_runtime(main: Node) -> void:
	var profile = main._pet_profile()
	var progress = main._get_pet_progress()
	main.pet_runtime = profile.duplicate(true)
	main.pet_runtime["remaining"] = 0.9
	main.pet_runtime["level"] = int(progress.get("level", 1))
	main.pet_runtime["evolution"] = int(progress.get("evolution", 0))
