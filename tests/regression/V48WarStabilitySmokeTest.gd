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
		push_error("V48 territory: " + label)

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
	_run.call_deferred()
func _run() -> void:
	for faction_id in [WorldWarState.FACTION_AURELIA,WorldWarState.FACTION_NOXFERA]:
		fresh()
		world.initialize_new(faction_id)
		authority.register_trusted_party('local_player',faction_id,force()['squad'],1000)
		session.bind(world,march,conflict,authority,gateway,faction_id,'local_player',season)
		world.rations=0
		world.army_wounds={'hero':0.0}
		world.army_fatigue=95
		var result:=session.send('return_capital',{},[],0)
		check(bool(result.get('ok',false)) and march.active and march.action=='forced_retreat',faction_id+': army without rations can retreat to recover')
		if march.active:
			authority.server_time_offset_seconds+=march.remaining_seconds()+1
			session.catch_up_server([],0)
			check(world.army_position==world.capital_for(faction_id) and world.army_wounds.is_empty(),faction_id+': free retreat reaches capital and heals')
			check(world.rations>=0 and world.army_fatigue<WorldWarState.COMBAT_FATIGUE_LIMIT,faction_id+': retreat retains fatigue recovery and no negative rations')
	fresh()
	world.army_wounds={'hero':0.0}
	var rations_before:=world.rations
	var registered:=submit('register_garrison',world.army_position)
	check(not bool(registered.get('accepted',false)) and conflict.garrison_count(world.army_position)==0,'wiped army cannot occupy a garrison slot')
	check(conflict.contribution_points==0,'wiped army cannot gain support contribution')
	var supported:=submit('support',Vector2i(3,10))
	check(not bool(supported.get('accepted',false)) and not march.active and world.rations==rations_before,'wiped army cannot spend rations on support departure')
	fresh()
	var old_force:=force()
	check(conflict.add_garrison(world,supply,world.army_position,old_force),'initial live garrison registers')
	var points:=conflict.contribution_points
	var updated:=old_force.duplicate(true)
	updated['squad'][0]['hp']=400
	updated['squad'][0]['attack']=220
	check(conflict.add_garrison(world,supply,world.army_position,updated),'same force can refresh its garrison')
	var stored:=conflict.find_force('player_local')
	check(int(stored['squad'][0]['hp'])==400 and int(stored['squad'][0]['attack'])==220,'garrison refresh updates actual units')
	check(conflict.garrison_count(world.army_position)==1 and conflict.contribution_points==points,'garrison refresh neither duplicates troops nor farms points')
	fresh()
	world.army_position=Vector2i(10,5)
	world._set_owner(world.army_position,world.faction)
	world._set_owner(Vector2i(11,5),world.enemy_faction())
	check(not supply.is_supply_connected(world,world.army_position,world.faction),'fixture army is isolated')
	check(world.can_attack_enemy_tile(world.faction,Vector2i(11,5)),'fixture enemy is outside protected territory')
	var rallied:=session.send('rally',{'target':[11,5]},[],0)
	check(not bool(rallied.get('ok',false)) and not march.active,'rally cannot bypass the supply restriction of solo attacks')
	check(conflict.rallies.is_empty(),'rejected isolated rally leaves no abandoned participants')
	fresh()
	world._set_owner(Vector2i(4,10),world.faction)
	world.army_position=Vector2i(4,10)
	world._set_owner(Vector2i(5,10),world.enemy_faction())
	var prepared:=authority.prepare_rally(world,conflict,resolver,Vector2i(5,10),'local_player')
	check(bool(prepared.get('accepted',false)),'connected army can prepare a rally')
	world._set_owner(Vector2i(3,10),WorldWarState.FACTION_NEUTRAL)
	var order:=command('rally_march',Vector2i(5,10))
	order['context_id']=prepared.get('rally_id','')
	var before_departure:=world.rations
	var revision_before:=authority.last_revision
	var rejected:=authority.submit_command(world,march,conflict,supply,order)
	check(not bool(rejected.get('accepted',false)) and str(rejected.get('reason',''))=='보급 단절','supply is checked again after rally preparation')
	check(not march.active and world.rations==before_departure,'failed rally leaves army and rations intact')
	check(authority.last_revision>revision_before,'failed rally cleanup publishes a new revision')
	var has_local:=false
	for rally in conflict.rallies.values():
		for participant in rally.get('participants',[]):
			if str(participant.get('force_id',''))=='player_local': has_local=true
	check(not has_local,'failed rally removes the reserved local participant')
	fresh()
	world._set_owner(Vector2i(4,10),world.enemy_faction())
	prepared=authority.prepare_rally(world,conflict,resolver,Vector2i(4,10),'local_player')
	check(bool(prepared.get('accepted',false)),'second rally fixture prepares')
	world._set_owner(Vector2i(4,10),world.faction)
	order=command('rally_march',Vector2i(4,10))
	order['context_id']=prepared.get('rally_id','')
	before_departure=world.rations
	rejected=authority.submit_command(world,march,conflict,supply,order)
	check(not bool(rejected.get('accepted',false)) and not march.active and world.rations==before_departure,'ownership change cannot turn rally attack into a paid friendly march')
	fresh()
	var arrived_before:=world.army_position
	check(bool(submit('march',Vector2i(4,10)).get('accepted',false)),'time-input fixture starts')
	var elapsed_before:=march.elapsed_seconds
	for invalid in [INF,NAN,-INF]:
		var bad:=march.advance(invalid,world)
		check(not bool(bad.get('arrived',false)) and march.active and march.elapsed_seconds==elapsed_before and world.army_position==arrived_before,'invalid delta cannot complete or poison a march')
		march.advance_authoritative(invalid,world)
		check(march.active and march.elapsed_seconds==elapsed_before,'invalid authority clock leaves active march intact')
	print('V48WarStabilitySmokeTest: ',checks,' checks, ',failures.size(),' failures')
	quit(0 if failures.is_empty() else 1)
