extends SceneTree
var checks: int = 0
var failures: Array[String] = []
func _init() -> void: _run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); push_error(label)
func _run() -> void:
	var resolver := WorldBattleResolver.new()
	var source: Array = [{"id":"tank", "name":"전열", "role":"탱커", "row":"전열", "hp":333, "max_hp":333, "attack":71, "defense":23}, {"id":"healer", "name":"회복", "role":"서포터", "row":"후열", "hp":271, "max_hp":271, "attack":59, "defense":11}]
	for faction: String in ["aurelia", "noxfera"]:
		var world := WorldWarState.new(); world.initialize_new(faction)
		var conflict := WorldConflictState.new()
		var target: Vector2i = Vector2i(4,10) if faction == "aurelia" else Vector2i(15,10)
		world.cells[world._key(target)]["owner"] = "neutral"
		world.cells[world._key(target)]["guard_level"] = 1
		world.cells[world._key(target)]["type"] = "fort"
		for fatigue in [0, 43, 85]:
			for wound: float in [1.0, 0.42, 0.001]:
				world.army_fatigue = fatigue; world.army_wounds = {"tank": wound, "healer": wound}
				for stance: String in WorldCampaignRules.STANCES:
					world.battle_stance = stance
					var before: Dictionary = world.export_state().duplicate(true)
					var conflict_before: Dictionary = conflict.export_state().duplicate(true)
					var source_before: Array = source.duplicate(true)
					var scout: Dictionary = WorldCampaignRules.scout(world, conflict, target, 1500, source)
					var prepared: Dictionary = resolver.preview_combatants(WorldCampaignRules.wounded_party(world, source), scout["defenders"], fatigue, scout["terrain_defense"], stance)
					check(scout["attacker_preview"] == prepared["attacker"] and scout["defender_preview"] == prepared["defender"], "identical modifier path " + faction + stance)
					check(scout["attacker_strength"] == WorldCampaignRules.strength(prepared["attacker"]) and scout["defender_strength"] == WorldCampaignRules.strength(prepared["defender"]), "strength uses transformed real units")
					check(before == world.export_state() and conflict_before == conflict.export_state() and source == source_before, "scout no world/defender/source writes")
					var result: Dictionary = resolver.resolve(WorldCampaignRules.wounded_party(world, source), scout["defenders"], fatigue, scout["terrain_defense"], 835, stance)
					check(result == resolver.resolve(WorldCampaignRules.wounded_party(world, source), scout["defenders"], fatigue, scout["terrain_defense"], 835, stance), "scout does not advance combat RNG")
		world.army_fatigue = 0; world.army_wounds.clear(); world.rations = 10000
		var march := WorldMarchState.new(); var supply := WorldSupplyNetwork.new()
		var admission: Dictionary = WorldCampaignRules.march_check(world, march, supply, target, source)
		check(admission["ok"], "frontier plan ready")
		var snapshot: Dictionary = WorldCampaignRules.preparation_snapshot(world, conflict, march, target, 1500, source)
		world.battle_stance = "assault"
		check(snapshot != WorldCampaignRules.preparation_snapshot(world, conflict, march, target, 1500, source), "stance invalidates quote")
		world.rations = 0
		check(WorldCampaignRules.march_check(world, march, supply, target, source)["reason"] == "군량 부족", "rations checked at admission")
		world.rations = 10000; world.army_wounds = {"tank":0.0,"healer":0.0}
		check(WorldCampaignRules.march_check(world, march, supply, target, source)["reason"] == "부상 회복 필요", "dead party cannot attack")
		world.army_wounds.clear(); world.army_fatigue = 100
		check(WorldCampaignRules.march_check(world, march, supply, target, source)["reason"] == "피로 한도", "fatigue checked")
		world.army_fatigue = 0
		check(WorldCampaignRules.march_check(world, march, supply, target, source, false)["reason"] == "시즌 정산 중", "season checked")
		world.cells[world._key(target)]["type"] = "mine"
		var before_recommend: Dictionary = world.export_state().duplicate(true)
		var suggestion: Dictionary = WorldCampaignRules.recommend(world, march, supply, source, "resources")
		check(not suggestion.is_empty(), "resource objective has target")
		if not suggestion.is_empty():
			check(world.tile_type(suggestion["target"]) in ["mine", "forest_resource", "ruins"], "resource suggestion actual resource tile")
			check(WorldCampaignRules.march_check(world, march, supply, suggestion["target"], source)["ok"], "suggested route actually admissible")
		check(before_recommend == world.export_state() and not march.active, "recommendation cannot capture/march/spend")
		# A one-tile bridge connects an isolated friendly tile; evaluation is hypothetical.
		var bridge: Vector2i = target; var isolated: Vector2i = target + Vector2i(1 if faction == "aurelia" else -1,0)
		for cell in world.neighbors(isolated): world.cells[world._key(cell)]["owner"] = "neutral"
		world.cells[world._key(isolated)]["owner"] = faction
		check(WorldCampaignRules.supply_links_after_capture(world, bridge, supply.connected_keys(world,faction)) >= 1, "single bridge finds isolated territory")
	print("v835_war_rules checks=%d failures=%s" % [checks, JSON.stringify(failures)])
	quit(0 if failures.is_empty() else 1)
