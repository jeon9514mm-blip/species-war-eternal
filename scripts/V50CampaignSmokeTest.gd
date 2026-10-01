extends SceneTree
var checks:=0
var failures: Array[String]=[]
var world: WorldWarState
var march: WorldMarchState
var conflict: WorldConflictState
var authority: WorldAuthorityService
var season: WorldSeasonState
var session: WorldWarClientSession
var supply:=WorldSupplyNetwork.new()
var resolver:=WorldBattleResolver.new()
const TARGET:=Vector2i(4,10)
func _init() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:failures.append(label);push_error('V50 campaign: '+label)
func squad(strong:=true) -> Array:
	var result: Array=[]
	for i in (10 if strong else 1):result.append({'id':'hero_'+str(i),'name':'영웅','role':'딜러','row':'전열','max_hp':10000 if strong else 200,'hp':10000 if strong else 200,'attack':1000 if strong else 120,'defense':100 if strong else 0})
	return result
func fresh(strong:=true, faction_id:='aurelia') -> void:
	world=WorldWarState.new();world.initialize_new(faction_id)
	march=WorldMarchState.new();conflict=WorldConflictState.new();authority=WorldAuthorityService.new();season=WorldSeasonState.new()
	authority.bind_season(season)
	authority.register_trusted_party('local_player',faction_id,squad(strong),5000 if strong else 500)
	session=WorldWarClientSession.new();session.bind(world,march,conflict,authority,WorldServerGateway.new(),faction_id,'local_player',season)
	world.cells[world._key(TARGET)]['type']='fort';world.cells[world._key(TARGET)]['guard_level']=1
func arrive() -> Dictionary:
	authority.server_time_offset_seconds+=march.remaining_seconds()+1
	return session.catch_up_server([],0)
func send(kind: String, payload:={}) -> Dictionary:return session.send(kind,payload,[],0)
func hp(units: Array) -> int:
	var total:=0
	for unit in units:total+=int(unit.get('hp',0))
	return total
func run() -> void:
	for faction_id in ['aurelia','noxfera']:
		fresh(true,faction_id)
		check(world.cells.size()==1600,'expanded map has 1600 cells '+faction_id)
		check(world.capital_for('aurelia')==Vector2i(1,10) and world.capital_for('noxfera')==Vector2i(18,10),'capitals retain save coordinates')
		var legacy:=world.export_state()
		legacy['world_version']=4;legacy.erase('battle_stance')
		for key in legacy['cells'].keys():
			var pair:=str(key).split(':')
			if int(pair[0])>=20 or int(pair[1])>=20:legacy['cells'].erase(key)
			else:legacy['cells'][key].erase('guard_level')
		legacy['army_wounds']={'hero_0':.42};legacy['rations']=1234;legacy['campaign_honor']=77
		var restored:=WorldWarState.new();restored.import_state(legacy)
		check(restored.cells.size()==1600 and restored.army_position==world.army_position,'legacy map grows without moving army')
		for key in legacy['cells']:
			check(restored.cells[key]['owner']==legacy['cells'][key]['owner'] and restored.cells[key]['type']==legacy['cells'][key]['type'],'old territory ownership and type '+str(key))
		check(restored.army_wounds==legacy['army_wounds'] and restored.rations==1234 and restored.campaign_honor==77,'migration preserves economy and wounds')
		check(restored.neutral_guard_level(Vector2i(4,5))==0 and restored.neutral_guard_level(Vector2i(24,25))==3,'legacy territory does not gain surprise guards; added province does')
		check(restored.battle_stance=='balanced','legacy tactics default balanced')
		restored.battle_stance='assault';restored.army_position=Vector2i(35,35);restored._set_owner(restored.army_position,faction_id)
		var exported:=restored.export_state();var second:=WorldWarState.new();second.import_state(exported)
		check(second.export_state()==exported,'expanded coordinates and tactics survive complete save round trip')
	fresh()
	var before:=world.export_state();var conflicts_before:=conflict.export_state()
	var scout:=WorldCampaignRules.scout(world,conflict,TARGET,5000,squad())
	check(int(scout['defender_strength'])>0 and int(scout['guard_level'])==1,'neutral scout reports real guards')
	check(before==world.export_state() and conflicts_before==conflict.export_state(),'scouting does not seed or heal troops, or change economy')
	check(not world.capture_neutral(TARGET) and not world.apply_march_arrival(TARGET,'capture_neutral'),'guarded tiles cannot bypass battle via direct capture')
	check(not send('set_stance',{'stance':'cheat'}).get('ok',false) and world.battle_stance=='balanced','invalid tactics rejected')
	check(send('set_stance',{'stance':'assault'}).get('ok',false) and world.battle_stance=='assault','tactic accepted through authority')
	var order:=session._command('set_stance',Vector2i(-1,-1),'guard')
	var first:=authority.submit_command(world,march,conflict,supply,order)
	var revision:=authority.last_revision
	var duplicate:=authority.submit_command(world,march,conflict,supply,order)
	check(first.get('accepted',false) and duplicate.get('accepted',false) and authority.last_revision==revision,'replayed tactic does not mutate twice')
	session.resync_from_server()
	var funds:=world.rations
	var planned:=march.plan(world,TARGET)
	check(send('begin_march',{'target':[4,10]}).get('ok',false) and march.active,'guarded frontier can be ordered')
	check(world.rations==funds-int(planned['ration_cost']) and world.tile_owner(TARGET)=='neutral','only march cost charged before arrival')
	check(not send('set_stance',{'stance':'assault'}).get('ok',false) and world.battle_stance=='guard','tactic locked during march')
	var battle:=arrive()
	check(battle.get('ok',false) and battle.get('captured',false) and world.tile_owner(TARGET)==world.faction,'authoritative victory captures neutral fort')
	check(not world.latest_battle_report().get('timeline',[]).is_empty() and world.latest_battle_report().get('stance','')=='guard','report stores actual combat rounds and selected tactic')
	check(world.army_position==TARGET and conflict.garrison_count(TARGET)==1 and world.garrison_at(TARGET).is_empty(),'victory registers survivors at captured fort')
	var captures:=world.captured_count;var score:=season.score_for(world.faction);var reports:=world.battle_reports.size()
	session.catch_up_server([],0)
	check(world.captured_count==captures and season.score_for(world.faction)==score and world.battle_reports.size()==reports,'repeated arrival cannot duplicate rewards or report')
	fresh(false)
	var original_guard_hp:=hp(WorldCampaignRules.neutral_guardians(world,TARGET))
	var origin:=world.army_position
	send('begin_march',{'target':[4,10]});battle=arrive()
	check(battle.get('ok',false) and not battle.get('captured',true) and world.tile_owner(TARGET)=='neutral','weak army loses without claiming fort')
	check(world.army_position==origin and world.army_wounds.get('hero_0',1.0)<1.0,'loss returns army and retains wounds')
	var remaining:=WorldCampaignRules.neutral_guardians(world,TARGET)
	check(hp(remaining)>0 and hp(remaining)<original_guard_hp,'defender losses persist after failed attack')
	var wounded_save:=world.export_state();var restored_wounds:=WorldWarState.new();restored_wounds.import_state(wounded_save)
	check(hp(WorldCampaignRules.neutral_guardians(restored_wounds,TARGET))==hp(remaining),'neutral defender wounds persist across save load')
	check(season.score_for(world.faction)==0 and world.captured_count==0,'defeat grants no capture rewards')
	fresh();world.army_fatigue=WorldWarState.COMBAT_FATIGUE_LIMIT
	funds=world.rations
	check(not send('begin_march',{'target':[4,10]}).get('ok',false) and world.rations==funds,'fatigue blocks neutral combat before charging')
	for change in ['season','owner','supply']:
		fresh();send('begin_march',{'target':[4,10]})
		if change=='season':season.active_end_unix=authority.server_now()-1
		elif change=='owner':world._set_owner(TARGET,world.enemy_faction())
		else:world._set_owner(Vector2i(3,10),'neutral')
		battle=arrive()
		check(not battle.get('ok',true) and not march.active and world.captured_count==0,'arrival revalidates '+change)
		check(world.battle_reports.is_empty() and season.score_for(world.faction)==0,'changed '+change+' does not run battle or award points')
	for mission in ['begin_march','rally']:
		fresh();world._set_owner(TARGET,world.enemy_faction())
		send('set_stance',{'stance':'assault'})
		check(send(mission,{'target':[4,10]}).get('ok',false),'enemy '+mission+' can depart')
		battle=arrive()
		var report:=world.latest_battle_report()
		var summaries: Array=report.get('battle_summaries',[])
		if mission=='rally' and not summaries.is_empty():summaries=summaries[0].get('battle_summaries',[])
		check(battle.get('ok',false) and not summaries.is_empty(),'enemy '+mission+' reports resolved engagement')
		if not summaries.is_empty():check(summaries[0].get('stance','')=='assault' and not summaries[0].get('timeline',[]).is_empty(),'selected tactic and actual turns survive '+mission+' attack queue')
	var attacker:=squad(false);var defender:=squad(false);attacker[0]['max_hp']=5000;attacker[0]['hp']=5000;defender[0]['max_hp']=5000;defender[0]['hp']=5000
	var originals:=attacker.duplicate(true)
	var balanced:=resolver.resolve(attacker,defender,0,1.0,88,'balanced')
	var assault:=resolver.resolve(attacker,defender,0,1.0,88,'assault')
	check(assault['timeline'][0]['attacker_damage']>balanced['timeline'][0]['attacker_damage'],'assault changes actual combat damage')
	for stance: String in WorldCampaignRules.STANCES:
		var result:=resolver.resolve(attacker,defender,40,1.18,88,stance)
		check(attacker==originals and int(result['attacker_units'][0]['attack'])==120 and int(result['attacker_units'][0]['max_hp'])==5000,'transient modifiers never mutate hero base stats '+stance)
		check(result['timeline'].size()==result['rounds'] and result['timeline'][-1]['attacker_hp']==result['attacker_hp'],'timeline matches battle totals '+stance)
	print('V50CampaignSmokeTest: ',checks,' checks, ',failures.size(),' failures')
	quit(0 if failures.is_empty() else 1)
