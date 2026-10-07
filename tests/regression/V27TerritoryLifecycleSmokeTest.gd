extends SceneTree

var failures: Array[String] = []
var checks := 0
var world := WorldWarState.new()
var march := WorldMarchState.new()
var conflict := WorldConflictState.new()
var supply := WorldSupplyNetwork.new()
var resolver := WorldBattleResolver.new()
var authority := WorldAuthorityService.new()
var season := WorldSeasonState.new()
var gateway := WorldServerGateway.new()
var session := WorldWarClientSession.new()

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		push_error("V27 territory: " + label)

func force(id := "player_local") -> Dictionary:
	return {"force_id": id, "faction": world.faction, "power": 1000, "squad": [{"id": "hero", "name": "Hero", "max_hp": 1000, "hp": 1000, "attack": 200, "defense": 20}]}

func command(kind: String, target := Vector2i(-1, -1)) -> Dictionary:
	return {"id": authority.next_command_id(kind), "type": kind, "player_id": "local_player", "faction": world.faction, "target": [target.x, target.y], "issued_at": authority.server_now(), "expected_revision": authority.last_revision}

func submit(kind: String, target := Vector2i(-1, -1)) -> Dictionary:
	return authority.submit_command(world, march, conflict, supply, command(kind, target))

func fresh() -> void:
	world = WorldWarState.new()
	world.initialize_new(WorldWarState.FACTION_AURELIA)
	march = WorldMarchState.new()
	conflict = WorldConflictState.new()
	season = WorldSeasonState.new()
	authority = WorldAuthorityService.new()
	authority.bind_season(season)
	authority.register_trusted_party("local_player", world.faction, force()["squad"], 1000)
	gateway = WorldServerGateway.new()
	session = WorldWarClientSession.new()
	session.bind(world, march, conflict, authority, gateway, world.faction, "local_player", season)

func _init() -> void:
	fresh()
	var origin := world.army_position
	check(conflict.add_garrison(world, supply, origin, force()), "initial garrison")
	var contribution := conflict.contribution_points
	for i in 5:
		check(conflict.add_garrison(world, supply, origin, force()), "repeat registration remains successful")
	check(conflict.contribution_points == contribution and conflict.garrison_count(origin) == 1, "registration cannot farm contribution")
	var full_tile := Vector2i(3, 10)
	for i in conflict.capacity_at(world, full_tile):
		conflict.add_garrison(world, supply, full_tile, force("ally%d" % i))
	check(not conflict.add_garrison(world, supply, full_tile, force()), "full destination rejects transfer")
	check(conflict.garrison_count(origin) == 1 and not conflict.find_force("player_local").is_empty(), "failed transfer preserves origin force")

	var order := command("march", Vector2i(4, 10))
	var initial_rations := world.rations
	check(bool(authority.submit_command(world, march, conflict, supply, order).get("accepted", false)), "march accepted")
	var spent_rations := world.rations
	check(spent_rations < initial_rations, "march charges rations")
	check(bool(authority.submit_command(world, march, conflict, supply, order).get("duplicate", false)) and world.rations == spent_rations, "duplicate march charges once")
	var conflicting_order := order.duplicate(true)
	conflicting_order["target"] = [5, 10]
	check(not bool(authority.submit_command(world, march, conflict, supply, conflicting_order).get("accepted", false)), "same ID different payload rejected")
	check(not bool(submit("register_garrison", origin).get("accepted", false)), "march cannot leave second origin garrison")
	var cancel := command("cancel_march")
	var cancelled := authority.submit_command(world, march, conflict, supply, cancel)
	check(bool(cancelled.get("accepted", false)) and not march.active and world.army_position == origin, "cancel restores origin")
	var after_cancel := world.rations
	authority.submit_command(world, march, conflict, supply, cancel)
	check(world.rations == after_cancel, "cancel refund issued once")
	check(conflict.contribution_points == contribution + conflict.capacity_at(world, full_tile) * 5, "cancel does not farm support points")

	fresh()
	var started := session.send("begin_march", {"target": [4, 10]}, [], 0)
	check(int(started.get("plan", {}).get("ration_cost", 0)) > 0, "UI start response includes original plan")
	var saved_march := march.export_state()
	march.import_state(saved_march)
	check(march.active and march.target == Vector2i(4, 10), "active march survives save restore")
	var high_water := march.elapsed_seconds
	march.advance_authoritative(march.authority_started_unix - 100.0, world)
	check(march.elapsed_seconds >= high_water, "march time does not reverse")
	authority.server_time_offset_seconds += march.remaining_seconds() + 1.0
	var arrival := session.catch_up_server([], 0)
	check(bool(arrival.get("ok", false)) and world.tile_owner(Vector2i(4, 10)) == world.faction, "offline march captures neutral exactly once")
	var capture_score := season.score_for(world.faction)
	var capture_count := world.captured_count
	session.catch_up_server([], 0)
	check(world.captured_count == capture_count and season.score_for(world.faction) == capture_score, "repeated catch-up does not duplicate captures")

	# A support destination fills while the force is travelling: abort safely.
	world._set_owner(Vector2i(5, 10), world.faction)
	var before_support := world.army_position
	check(bool(submit("support", Vector2i(5, 10)).get("accepted", false)), "support departure")
	for i in conflict.capacity_at(world, Vector2i(5, 10)):
		conflict.add_garrison(world, supply, Vector2i(5, 10), force("new_ally%d" % i))
	authority.server_time_offset_seconds += march.remaining_seconds() + 1.0
	var blocked := authority.catch_up_march(world, march, conflict, supply, resolver, "local_player")
	check(not bool(blocked.get("accepted", false)) and world.army_position == before_support and not march.active, "changed support capacity restores origin")

	fresh()
	check(bool(submit("march", Vector2i(4, 10)).get("accepted", false)), "route-loss departure")
	world._set_owner(Vector2i(3, 10), WorldWarState.FACTION_NEUTRAL)
	authority.server_time_offset_seconds += march.remaining_seconds() + 1.0
	var broken := authority.catch_up_march(world, march, conflict, supply, resolver, "local_player")
	check(not bool(broken.get("accepted", false)) and world.tile_owner(Vector2i(4, 10)) == WorldWarState.FACTION_NEUTRAL and world.army_position == Vector2i(2, 10), "severed march route prevents teleport conquest")

	# Defender wounds and dead units survive combat modifiers across attack waves.
	var weak: Array = [{"id": "weak", "hp": 1000, "max_hp": 1000, "attack": 1, "defense": 100}]
	var wounded: Array = [{"id": "defender", "hp": 1, "max_hp": 1000, "attack": 1, "defense": 100}]
	var battle := resolver.resolve(weak, wounded, 0, 1.18, 123)
	check(bool(battle.get("victory", false)) and int(battle.get("rounds", 99)) <= 2, "defense bonus does not fully heal wounded defenders")
	check(int(battle["defender_units"][0]["max_hp"]) == 1000 and int(battle["defender_units"][0]["defense"]) == 100, "combat modifiers do not permanently stack")
	wounded[0]["hp"] = 0
	check(int(resolver.resolve(weak, wounded, 0, 1.18, 123).get("defender_alive", 1)) == 0, "dead defenders never resurrect")
	world.record_army_wounds(force()["squad"], [])
	check(int(authority.trusted_force("local_player", world)["squad"][0]["hp"]) == 0, "party refresh preserves expedition casualties")
	world.apply_march_arrival(world.capital_for(world.faction), "move")
	check(int(authority.trusted_force("local_player", world)["squad"][0]["hp"]) == 1000, "capital return recovers casualties")

	fresh()
	for x in range(3, 6):
		world._set_owner(Vector2i(x, 10), world.faction)
	world._set_type(Vector2i(4, 10), "mine")
	world._set_type(Vector2i(5, 10), "ruins")
	world.advance_logistics(100000, supply)
	var first_income := world.advance_logistics(100060, supply)
	check(int(first_income.get("rations", 0)) == 7 and int(first_income.get("honor", 0)) == 1, "supplied mine and ruins produce resources")
	var earned := world.rations
	world.advance_logistics(99900, supply)
	world.advance_logistics(100060, supply)
	check(world.rations == earned, "clock rollback cannot duplicate logistics")
	world._set_owner(Vector2i(3, 10), WorldWarState.FACTION_NEUTRAL)
	var isolated_rates := world.logistics_rates(supply)
	check(is_equal_approx(float(isolated_rates["rations_per_minute"]), 3.25) and is_equal_approx(float(isolated_rates["honor_per_minute"]), 0.25), "supply cut reduces resource income to 25 percent")
	var capped := world.advance_logistics(100060 + 86400, supply)
	check(int(capped.get("seconds", 0)) == WorldWarState.MAX_LOGISTICS_SECONDS, "offline production capped at eight hours")
	var after_cap := world.rations
	world.advance_logistics(100060 + 86400, supply)
	check(world.rations == after_cap, "offline excess cannot be reclaimed")
	var restored_world := WorldWarState.new()
	restored_world.import_state(world.export_state())
	check(restored_world.campaign_honor == world.campaign_honor and restored_world.last_logistics_unix == world.last_logistics_unix, "production wallet and time watermark persist")

	fresh()
	season.record_capture(world.faction, "fort", "local_player", true, authority.server_now())
	season.active_end_unix = authority.server_now() - 1
	season.settlement_end_unix = authority.server_now() + 100
	check(season.refresh_phase(authority.server_now()) == "settlement", "season settlement begins")
	check(season.refresh_phase(season.start_unix) == "settlement", "clock rollback cannot reopen season")
	var claim := command("claim_season_reward")
	check(bool(authority.submit_command(world, march, conflict, supply, claim).get("accepted", false)), "season participation reward claim")
	var honor := world.campaign_honor
	var reward_rations := world.rations
	authority.submit_command(world, march, conflict, supply, claim)
	check(world.campaign_honor == honor and world.rations == reward_rations, "replayed claim credits once")
	var restored_season := WorldSeasonState.new()
	restored_season.import_state(season.export_state())
	check(restored_season.claim_reward(world, "local_player", authority.server_now()).is_empty(), "claim receipt survives restore")
	check(bool(submit("exchange_honor").get("accepted", false)) and world.rations == reward_rations + 200, "earned honor exchanges for usable march rations")
	var remaining_honor := world.campaign_honor
	authority.server_time_offset_seconds += 102.0
	check(bool(submit("next_season").get("accepted", false)) and season.season_id == "S002", "ended season advances through authority command")
	check(world.campaign_honor == remaining_honor and season.contribution_for("local_player") == 0 and conflict.garrison_count(world.army_position) == 0, "season rollover preserves honor and resets territory conflict")
	check(not bool(submit("next_season").get("accepted", false)), "active season cannot be reset twice")
	var snapshot := authority.build_snapshot(world, march, conflict)
	check(authority.verify_snapshot(snapshot), "full world snapshot digest verifies")
	var unsigned := snapshot.duplicate(true)
	unsigned.erase("snapshot_digest")
	check(not bool(session._apply_snapshot(unsigned).get("ok", false)), "unsigned snapshot rejected")

	# Both factions can finish a conquest + actual battle lifecycle with casualties.
	for faction_id in [WorldWarState.FACTION_AURELIA, WorldWarState.FACTION_NOXFERA]:
		fresh()
		world.initialize_new(faction_id)
		var champion: Array = [{"id": "champion", "max_hp": 10000, "hp": 10000, "attack": 2000, "defense": 20}]
		authority.register_trusted_party("local_player", world.faction, champion, 1000)
		var frontier := Vector2i(4, 10) if faction_id == WorldWarState.FACTION_AURELIA else Vector2i(15, 10)
		check(bool(submit("march", frontier).get("accepted", false)), "both-faction neutral departure")
		authority.server_time_offset_seconds += march.remaining_seconds() + 1.0
		check(bool(authority.catch_up_march(world, march, conflict, supply, resolver, "local_player").get("accepted", false)), "both-faction neutral arrival")
		var enemy_tile := frontier + (Vector2i.RIGHT if faction_id == WorldWarState.FACTION_AURELIA else Vector2i.LEFT)
		world._set_owner(enemy_tile, world.enemy_faction())
		check(bool(submit("march", enemy_tile).get("accepted", false)), "both-faction attack departure")
		authority.server_time_offset_seconds += march.remaining_seconds() + 1.0
		var victory := authority.catch_up_march(world, march, conflict, supply, resolver, "local_player")
		check(bool(victory.get("captured", false)) and world.army_position == enemy_tile, "both-faction battle changes actual ownership")
		var wound_ratio := float(world.army_wounds.get("champion", 1.0))
		check(wound_ratio > 0.0 and wound_ratio < 1.0 and world.army_fatigue > 0, "battle persists surviving wounded army and fatigue")
		check(not world.latest_battle_report().is_empty() and season.score_for(world.faction) > 3, "battle reports and season score linked")

	var malformed_authority := WorldAuthorityService.new()
	malformed_authority.import_state({"server_time_offset_seconds": [], "last_revision": {}, "processed_commands": {"bad": 7, "bad_numbers": {"revision": [], "refund": {}}}, "command_log": [9, {}]})
	check(malformed_authority.last_revision == 0 and malformed_authority.server_time_offset_seconds == 0.0 and not malformed_authority.processed_commands.has("bad"), "malformed authority cache and numeric fields are sanitized")

	# Malformed nested save data must leave a complete, playable grid.
	var malformed := world.export_state()
	malformed["cells"] = {"1:10": {"owner": [], "type": {}, "level": {}}}
	malformed["rations"] = {}
	malformed["army_wounds"] = {"hero": {}}
	restored_world.import_state(malformed)
	check(restored_world.cells.size() == WorldWarState.WIDTH * WorldWarState.HEIGHT and restored_world.tile_owner(WorldWarState.AURELIA_CAPITAL) == WorldWarState.FACTION_AURELIA, "malformed grid restored with sanctuary intact")
	var malformed_conflict := WorldConflictState.new()
	malformed_conflict.import_state({"tile_garrisons": {"2:10": [7, {"force_id": "bad", "faction": "aurelia", "squad": [{"hp": {}, "max_hp": []}]}]}, "rallies": {"bad": 5}, "total_supports": []})
	check(malformed_conflict.total_supports == 0, "malformed conflict scalars and force fields are sanitized")
	var malformed_march := WorldMarchState.new()
	malformed_march.import_state({"active": true, "duration_seconds": {}, "path": [[2, 10], [999, 10]], "faction": "aurelia", "action": "capture_neutral"})
	check(not malformed_march.active, "invalid saved march cannot become active")
	if failures.is_empty():
		print("v27_territory_lifecycle_smoke_test_ok checks=%d garrison=atomic command=once march=restore combat=wounds logistics=8h season=claim_rollover snapshot=guarded" % checks)
		quit(0)
	else:
		print("v27_territory_lifecycle_FAILED checks=%d failures=%s" % [checks, failures])
		quit(1)
