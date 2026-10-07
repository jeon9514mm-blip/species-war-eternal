extends RefCounted

## v83: SummonService. Main remains the single owner of mutable game state.
## The injected host supplies state, virtual UI hooks and runtime refreshes.
## No cached host reference, duplicate wallet, RNG or save schema is introduced.

static func summon_once(main: Node) -> Dictionary:
	if not preload("res://scripts/persistence/SaveSafety.gd").allow_mutation(main): return {}
	var roster = main._hero_roster_for_faction()
	if roster.is_empty():
		return {}
	var cost = 100
	if main.wallet_gems < cost:
		main._show_toast("소환에는 젬 %d개가 필요합니다." % cost)
		return {}
	main.wallet_gems -= cost
	main.summon_pity += 1
	var index = main.loot_rng.randi_range(0, roster.size() - 1)
	var hero: Dictionary = roster[index]
	var hero_id = str(hero["id"])
	var shards = 12
	if main.summon_pity >= 10:
		shards = 30
		main.summon_pity = 0
	main.hero_shards[hero_id] = main._hero_shard_count(hero_id) + shards
	main.codex_seen[hero_id] = true
	main._save_idle_state()
	return {"hero_id": hero_id, "name": str(hero["name"]), "shards": shards}


static func summon_guardian(main: Node) -> Dictionary:
	if not preload("res://scripts/persistence/SaveSafety.gd").allow_mutation(main): return {}
	if main.selected_faction not in ["aurelia","noxfera"]:return {}
	main._guardian_ensure_starter()
	var free = not main.guardian_free_claimed
	if not free and main.wallet_gems < main.GUARDIANS.SUMMON_COST:
		main._show_toast("수호신 소환에는 젬 %d개가 필요합니다." % main.GUARDIANS.SUMMON_COST)
		return {}
	var id: String=main.GUARDIANS.draw_id(main.loot_rng,main.guardian_mythic_pity,main.guardian_legendary_pity)
	var profile: Dictionary=main.GUARDIANS.profile(id)
	if profile.is_empty():return {}
	if free:main.guardian_free_claimed=true
	else:main.wallet_gems-=main.GUARDIANS.SUMMON_COST
	var new_guardian = not main.guardian_collection.has(id)
	var copies = mini(999,int(main.guardian_collection.get(id,{}).get("copies",0))+1)
	main.guardian_collection[id]={"copies":copies}
	main.guardian_mythic_pity=0 if str(profile["tier"])=="신화" else mini(main.GUARDIANS.MYTHIC_PITY-1,main.guardian_mythic_pity+1)
	main.guardian_legendary_pity=0 if main.GUARDIANS.tier_index(str(profile["tier"]))>=3 else mini(main.GUARDIANS.LEGENDARY_PITY-1,main.guardian_legendary_pity+1)
	main._save_idle_state()
	return {"id":id,"name":str(profile["name"]),"tier":str(profile["tier"]),"new":new_guardian,"copies":copies,"free":free}
