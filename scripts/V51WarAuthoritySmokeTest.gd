extends SceneTree

var failures: Array[String] = []
var checks := 0
var world: WorldWarState
var march: WorldMarchState
var conflict: WorldConflictState
var authority: WorldAuthorityService
var supply := WorldSupplyNetwork.new()
var resolver := WorldBattleResolver.new()

func _init() -> void:
	_run.call_deferred()

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		push_error("V51 war: " + label)

func unit(id: String, hp := 1000, attack := 5000, defense := 100) -> Dictionary:
	return {"id": id, "name": id, "role": "딜러", "row": "전열", "hp": hp, "max_hp": hp, "attack": attack, "defense": defense}

func fresh() -> void:
	world = WorldWarState.new()
	world.initialize_new(WorldWarState.FACTION_AURELIA)
	march = WorldMarchState.new()
	conflict = WorldConflictState.new()
	authority = WorldAuthorityService.new()
	authority.local_demo_allies = false
	authority.register_trusted_party("local_player", world.faction, [unit("hero")], 1000)

func command(kind: String, target: Vector2i, context := "") -> Dictionary:
	return {"id": authority.next_command_id(kind), "type": kind, "player_id": "local_player", "faction": world.faction, "target": [target.x, target.y], "context_id": context, "issued_at": authority.server_now(), "expected_revision": authority.last_revision}

func submit(kind: String, target: Vector2i, context := "") -> Dictionary:
	return authority.submit_command(world, march, conflict, supply, command(kind, target, context))

func arrive() -> Dictionary:
	authority.server_time_offset_seconds += march.remaining_seconds() + 1.0
	return authority.catch_up_march(world, march, conflict, supply, resolver, "local_player")

func frontline() -> Vector2i:
	world._set_owner(Vector2i(4, 10), world.faction)
	world.army_position = Vector2i(4, 10)
	var target := Vector2i(5, 10)
	world._set_owner(target, world.enemy_faction())
	world.set_garrison(target, [unit("enemy", 17, 1, 0)])
	return target

func _run() -> void:
	for mode in ["solo", "rally", "neutral", "guarded"]:
		fresh()
		var target := frontline()
		var rally_id := ""
		if mode in ["neutral", "guarded"]:
			world._set_owner(target, WorldWarState.FACTION_NEUTRAL)
			world.clear_garrison(target)
			world.cells[world._key(target)]["guard_level"] = 1 if mode == "guarded" else 0
		var previous_owner := world.tile_owner(target)
		if mode == "rally":
			var prepared := authority.prepare_rally(world, conflict, resolver, target, "local_player")
			check(bool(prepared.get("accepted", false)), "rally supply fixture prepares")
			rally_id = str(prepared.get("rally_id", ""))
		check(bool(submit("rally_march" if mode == "rally" else "march", target, rally_id).get("accepted", false)), "connected attack starts")
		world._set_owner(Vector2i(3, 10), WorldWarState.FACTION_NEUTRAL)
		check(not supply.is_supply_connected(world, march.origin, world.faction), "upstream supply cut does not modify final march edge")
		var result := arrive()
		check(not bool(result.get("accepted", false)), "arrival rejects combat after upstream supply loss")
		check(world.tile_owner(target) == previous_owner and world.battle_reports.is_empty(), "supply loss cannot capture or start battle")
		check(not march.active and world.army_position == Vector2i(4, 10), "rejected attack returns once to valid origin")
		check(conflict.rallies.is_empty(), "rejected rally arrival releases reservation")
		var retry := authority.catch_up_march(world, march, conflict, supply, resolver, "local_player")
		check(str(retry.get("event", "")) == "idle" and world.tile_owner(target) == previous_owner, "rejected arrival cannot replay conquest")

	fresh()
	var target := frontline()
	var prepared := authority.prepare_rally(world, conflict, resolver, target, "local_player")
	var rally_id := str(prepared.get("rally_id", ""))
	world.army_wounds = {"hero": 0.10}
	check(bool(submit("set_stance", Vector2i(-1, -1), "assault").get("accepted", false)), "tactic changes after rally preparation")
	check(bool(submit("rally_march", target, rally_id).get("accepted", false)), "updated wounded force starts rally")
	var result := arrive()
	check(bool(result.get("captured", false)), "live wounded force can win weak enemy")
	check(is_equal_approx(float(world.army_wounds.get("hero", 0.0)), 0.10), "rally never restores health from stale preparation snapshot")
	var participant_reports: Array = result.get("report", {}).get("battle_summaries", [])
	var summaries: Array = participant_reports[0].get("battle_summaries", []) if not participant_reports.is_empty() else []
	check(not summaries.is_empty() and str(summaries[0].get("stance", "")) == "assault", "rally uses current authoritative tactic")

	fresh()
	world.army_wounds = {"hero": 0.25}
	world.army_fatigue = 70
	var capital := world.capital_for(world.faction)
	var origin := world.army_position
	check(bool(submit("support", capital).get("accepted", false)), "wounded support army departs for capital")
	for index in conflict.capacity_at(world, capital):
		check(conflict.add_garrison(world, supply, capital, {"force_id": "ally_%d" % index, "faction": world.faction, "squad": [unit("ally_%d" % index)]}), "capital fills while support is en route")
	result = arrive()
	check(not bool(result.get("accepted", false)) and world.army_position == origin, "full support destination returns army")
	check(is_equal_approx(float(world.army_wounds.get("hero", 1.0)), 0.25) and world.army_fatigue == 70, "rejected capital support grants no early healing")
	conflict.clear_tile(capital)
	check(bool(submit("support", capital).get("accepted", false)), "support can retry after capacity is released")
	result = arrive()
	check(bool(result.get("accepted", false)) and world.army_position == capital and world.army_wounds.is_empty() and world.army_fatigue == 35, "accepted capital support commits movement and recovery")
	var stationed := conflict.find_force("player_local")
	check(not stationed.is_empty() and int(stationed["squad"][0]["hp"]) == 1000, "successful capital garrison records healed force")

	var report := resolver.resolve([unit("hero")], [unit("enemy", 17, 1, 0)], 0, 1.0, 197)
	check(int(report["attacker_damage"]) == 17 and int(report["timeline"][0]["attacker_damage"]) == 17, "report caps attacker overkill at actual HP lost")
	report = resolver.resolve([unit("hero", 11, 1, 0)], [unit("enemy", 1000, 9000, 0)], 0, 1.0, 198)
	check(int(report["defender_damage"]) == 11 and int(report["timeline"][0]["defender_damage"]) == 11, "report caps defender overkill at actual HP lost")
	print("V51WarAuthoritySmokeTest: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
