extends SceneTree
## Integration across faction banks, a global season, and persistent snapshots.
var checks:=0
var failures: Array[String]=[]
func _init() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:failures.append(label);push_error('V51 session: '+label)
func run() -> void:
	var main=preload('res://scenes/Main.tscn').instantiate()
	main.save_state_path='user://v51-faction-season.json'
	root.add_child(main);await process_frame
	main.set_physics_process(false);main._offline_checked=true
	main.world_season_state.ensure_started(main.world_authority.server_now())
	var now: int=main.world_authority.server_now()
	main._select_faction('aurelia')
	main.faction_war_state._set_owner(Vector2i(4,10),'aurelia')
	main.faction_war_state.rations=3333
	main.faction_war_state.campaign_honor=71
	main.faction_war_state.captured_count=9
	main.faction_war_state.army_wounds={'leonhardt':.4}
	main.faction_war_state.battle_stance='assault'
	main.faction_march_state.begin(main.faction_war_state,Vector2i(4,10))
	var old_route: Array=main.faction_march_state.path.duplicate()
	main.faction_conflict_state.support_awards={'old_support':true}
	main._select_faction('noxfera')
	main.faction_war_state.rations=4444
	main.faction_war_state.campaign_honor=92
	main._select_faction('aurelia')
	check(main.faction_march_state.active and main.faction_march_state.path==old_route and main.faction_war_state.captured_count==9,'same-season switch preserves active march and captured land')
	main._select_faction('noxfera')
	check(main.faction_war_state.rations==4444,'same-season switch preserves independent rations')
	main.world_season_state.active_end_unix=now-2
	main.world_season_state.settlement_end_unix=now-1
	check(main.world_season_state.begin_next_season(main.faction_war_state,main.faction_conflict_state,main.faction_march_state,'noxfera',now),'next season starts for active faction')
	main._save_idle_state()
	main._select_faction('aurelia')
	check(main.faction_war_state.rations==WorldWarState.STARTING_RATIONS,'inactive faction resets seasonal rations')
	check(main.faction_war_state.tile_owner(Vector2i(4,10))=='neutral' and main.faction_war_state.captured_count==0,'old territory cannot reappear in new season')
	check(not main.faction_march_state.active and main.faction_march_state.path.is_empty(),'old season march cannot arrive in new season')
	check(main.faction_conflict_state.support_awards.is_empty(),'old support receipts and conflict state reset')
	check(main.faction_war_state.army_wounds.is_empty() and main.faction_war_state.battle_stance=='balanced','season clears wounds and selected tactic consistently')
	check(main.faction_war_state.campaign_honor==71,'inactive faction retains earned permanent honor')
	main._select_faction('noxfera')
	check(main.faction_war_state.campaign_honor==92 and main.faction_war_state.rations==800,'active faction honor and seasonal reset remain intact')
	main._save_idle_state();main.free()
	var restored=preload('res://scenes/Main.tscn').instantiate()
	restored.save_state_path='user://v51-faction-season.json'
	root.add_child(restored);await process_frame;restored.set_physics_process(false)
	check(restored.world_season_state.season_number==2 and restored.faction_war_state.campaign_honor==92,'load restores season before reading faction bank')
	restored._select_faction('aurelia')
	check(restored.faction_war_state.captured_count==0 and restored.faction_war_state.campaign_honor==71,'new-season reset survives save/reload and faction switching')
	var saved: Dictionary=restored.save_store.read_save(restored.save_state_path)['data']
	for bank in saved['faction_world_snapshots'].values():bank.erase('season_number')
	saved['faction_world_snapshots']['aurelia']['war']['rations']=2345
	check(restored.save_store.write_save('user://v51-legacy-faction-season.json',saved).get('ok',false),'legacy untagged fixture saved')
	restored.free()
	var legacy=preload('res://scenes/Main.tscn').instantiate()
	legacy.save_state_path='user://v51-legacy-faction-season.json'
	root.add_child(legacy);await process_frame;legacy.set_physics_process(false)
	legacy._select_faction('aurelia')
	check(legacy.faction_war_state.rations==2345,'untagged legacy bank is assigned saved season without destructive reset')
	check(int(legacy.faction_world_snapshots['aurelia'].get('season_number',0))==2,'legacy bank is stamped for subsequent season changes')
	legacy.free()
	print('V51SessionIntegritySmokeTest: ',checks,' checks, ',failures.size(),' failures')
	quit(0 if failures.is_empty() else 1)
