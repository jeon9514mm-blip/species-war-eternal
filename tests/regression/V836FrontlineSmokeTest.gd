extends "res://tests/support/V83UpgradeTestBase.gd"
const F=preload("res://scripts/world/WorldFrontlineRules.gd")
func _init()->void:_run.call_deferred()
func _run()->void:
	for faction: String in ["aurelia","noxfera"]:
		var main=await make_main(faction,10)
		main._build_faction_war_screen();await settle()
		var war: WorldWarScreen
		for child in main.content_root.get_children():
			if child is WorldWarScreen:war=child
		check(war!=null,"actual war screen")
		if war==null:await dispose(main);continue
		war.set_process(false)
		var w: WorldWarState=war.world_state;var m: WorldMarchState=war.march_state
		var fort: Vector2i=w.army_position+Vector2i(1 if faction=="aurelia" else -1,0)
		w.cells[w._key(fort)].owner=faction;w.cells[w._key(fort)].type="fort"
		w.army_fatigue=65;w.rations=10000
		for hero in main.deployed_heroes:w.army_wounds[hero.id]=.35
		var snapshot: Dictionary=w.export_state().duplicate(true)
		var bases: Array=F.nearby_bases(w,m,war.supply_network)
		check(not bases.is_empty() and w.export_state()==snapshot and not m.active,"staging read only")
		var plan: Dictionary=m.plan(w,fort);var reserve: Dictionary=F.return_reserve(w,m,fort)
		check(reserve.outbound==plan.ration_cost and reserve["return"]==plan.ration_cost,"reverse-route reserve uses real price")
		var response: Dictionary=war.client_session.send("begin_march",{"target":[fort.x,fort.y]},[],0)
		check(response.ok and m.active,"real friendly staging march")
		check(not F.rest_quote(w,m,war.supply_network,war.attacker_squad).ok,"no recovery in transit")
		war.client_session.advance_server(1.0,[],0)
		# Advance authoritative time, not teleport unit or invoke recovery directly.
		war.client_session.authority.server_time_offset_seconds+=m.remaining_seconds()+1.0
		war.client_session.catch_up_server([],0)
		check(w.army_position==fort and not m.active,"staging destination reached through authority")
		var force: Dictionary=war.client_session.authority.trusted_force(war.client_session.player_id,w)
		var q: Dictionary=F.rest_quote(w,m,war.supply_network,force.squad)
		check(q.ok and q.fatigue_drop==20 and q.wounds.size()==10,"connected fort recovery quote")
		check(war.conflict_state.add_garrison(w,war.supply_network,fort,force),"register actual pre-rest garrison")
		# Dedicated rally fixture checks this physical force is not duplicated after rest.
		var friendly: Dictionary=force.duplicate(true);friendly.force_id="npc_ally_rest_fixture"
		war.conflict_state.rallies["rest_fixture"]={"id":"rest_fixture","faction":faction,"target":[10,10],"leader_force_id":"player_local","participants":[force.duplicate(true),friendly]}
		w.last_logistics_unix=war.client_session.authority.server_now()
		var before_funds: int=w.rations
		var command: Dictionary=war.client_session._command("rest_army",fort,q.key)
		var a: WorldAuthorityService=war.client_session.authority
		var applied: Dictionary=a.submit_command(w,m,war.conflict_state,war.supply_network,command)
		check(applied.accepted and w.rations==before_funds-int(q.cost) and w.army_fatigue==45,"one exact charge and capped fatigue reduction")
		for id in q.wounds:check(is_equal_approx(float(w.army_wounds[id]),.5),"15 percentage-point bounded wound recovery "+id)
		check(war.conflict_state.find_force("player_local").is_empty(),"old garrison detached, no phantom full-health defender")
		check(war.conflict_state.rallies.rest_fixture.participants.size()==1 and war.conflict_state.rallies.rest_fixture.leader_force_id=="npc_ally_rest_fixture","detach only player rally entry; ally and leadership survive")
		var save_path: String="user://frontline-"+faction+".json"
		var saved:=FileAccess.open(save_path,FileAccess.WRITE)
		saved.store_string(JSON.stringify(w.export_state()));saved.close()
		var restored:=WorldWarState.new();restored.import_state(JSON.parse_string(FileAccess.get_file_as_string(save_path)))
		check(restored.rations==w.rations and restored.army_fatigue==w.army_fatigue and restored.army_position==fort,"actual disk restore preserves rest cost and destination")
		for id in q.wounds:check(is_equal_approx(float(restored.army_wounds[id]),float(w.army_wounds[id])),"disk restore wounded HP "+id)
		var after: Dictionary=w.export_state().duplicate(true)
		var duplicate: Dictionary=a.submit_command(w,m,war.conflict_state,war.supply_network,command)
		check(duplicate.get("duplicate",false) and w.export_state()==after,"same command cannot pay/heal twice")
		war.client_session.revision=a.last_revision
		var stale: Dictionary=a.submit_command(w,m,war.conflict_state,war.supply_network,war.client_session._command("rest_army",fort,q.key))
		check(not stale.accepted and w.export_state()==after,"new command cannot reuse obsolete quote")
		w.rations=0
		check(not F.rest_quote(w,m,war.supply_network,force.squad).ok,"insufficient rations")
		w.rations=10000;w.army_fatigue=0;w.army_wounds.clear()
		check(not F.rest_quote(w,m,war.supply_network,force.squad).ok,"no cost or healing at full condition")
		w.army_fatigue=20;w.cells[w._key(fort)].owner=w.enemy_faction()
		check(not F.rest_quote(w,m,war.supply_network,force.squad).ok,"enemy fort rejected")
		await dispose(main)
	done("v836_frontline")
