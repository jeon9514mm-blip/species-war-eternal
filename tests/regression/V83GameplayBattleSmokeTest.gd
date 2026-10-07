extends SceneTree
const HOST=preload("res://tests/support/V83GameplayBattleHost.gd")
const CATALOG=preload("res://scripts/heroes/HeroRosterCatalog.gd")
var checks: int=0
var failures: Array[String]=[]
func _init() -> void: _run.call_deferred()
func check(ok: bool, note: String) -> void:
	checks+=1
	if not ok: failures.append(note);push_error(note)
func settle() -> void:
	for frame in 5: await process_frame
func _run() -> void:
	root.content_scale_size=Vector2i(720,1280);root.size=Vector2i(720,1280)
	for faction in ["aurelia","noxfera"]:
		var main=HOST.new()
		main.save_state_path="user://v83-gameplay-"+faction+".json"
		root.add_child(main);await settle()
		main.set_process(false);main.set_physics_process(false)
		main._offline_checked=true;main.selected_faction=faction;main.current_zone_id="gray_meadow"
		main.idle_stage=100;main.party_slot_legacy_cap=10
		var ids: Array[String]=[]
		for hero in CATALOG.roster(faction):
			if ids.size()<10: ids.append(str(hero.id))
		main._restore_deployed_heroes(ids)
		for id in ids:main.hero_progress[id]={"level":60,"xp":0}
		main.combat_effects_enabled=false;main.sound_effects_enabled=false;main.battle_speed=1.0
		main.daily_dungeon_day=main._today_key();main.daily_dungeon_runs=0
		main.wallet_gold=100;main.wallet_gems=10;main.skill_auto=true;main.ultimate_auto=true
		main._build_meta_hub_screen();await settle()
		check(main.find_child("ChallengePartyRoles",true,false)!=null,"preflight roles "+faction)
		check(main._run_daily_dungeon("gold_rush"),"actual 10-hero daily entry "+faction)
		check(main.deployed_heroes.size()==10,"actual full party not synthetic slots")
		var session=main.challenge_session
		var ids_seen: Dictionary={}
		var ticks: int=0
		while main.challenge_session!=null and ticks<1900:
			for enemy in main.enemy_wave:ids_seen[enemy.id]=true
			main._advance_auto_hunt(1.0/30.0)
			ticks+=1
			if ticks%30==0:await process_frame
		check(main.challenge_session==null,"battle ended naturally")
		var report: Dictionary=main.get_meta("last_challenge_report",{})
		check(not report.is_empty() and report.actors.size()==10,"ten actor report published")
		check(report.get("reason","")=="waves_cleared" and main.daily_dungeon_runs==1,"leveled fixture actual clear")
		check(ids_seen.size()==18,"all three six-enemy waves used")
		check(main.wallet_gold==1050,"exact existing first daily reward")
		check(report.get("total_damage",-1)==main.audit_damage and main.audit_damage>0,"report vs independent actual HP trace")
		var sum_damage: int=int(report.get("support_damage",0))+int(report.get("unknown_damage",0))
		for row in report.get("actors",[]):
			check(row.damage==main.audit_sources.get(row.slot,0),"independent damage "+str(row.id))
			check(row.damage_taken==main.audit_taken.get(row.id,0),"independent incoming "+str(row.id))
			check(row.healing_received==main.audit_healing.get(row.id,0),"independent received healing "+str(row.id))
			sum_damage+=int(row.damage)
		check(sum_damage==report.total_damage,"actor and guardian shares conserve total")
		check(report.support_damage==main.audit_sources.get(-1,0),"guardian never assigned to first hero")
		check(is_equal_approx(float(report.dps),float(report.total_damage)/float(report.elapsed)),"DPS uses actual duration")
		var before: String=JSON.stringify(report)
		main.CHALLENGE_DRIVER.publish_report(main,session)
		check(JSON.stringify(main.get_meta("last_challenge_report",{}))==before,"duplicate publication idempotent")
		check(main.get_meta("challenge_report_history",[]).size()==1,"single history entry")
		await settle()
		var button=main.find_child("ChallengeReportOpen",true,false)
		check(button!=null,"actual result leads to analysis")
		if button!=null:button.emit_signal("pressed")
		await settle()
		check(main.active_screen=="challenge_report" and main.find_child("ChallengeReportSummary",true,false)!=null,"analysis screen opens")
		for id in ids:check(main.find_child("ChallengeActor_"+id,true,false)!=null,"report row reachable "+id)
		var growth=main.find_child("ChallengeActorGrowth_"+ids[4],true,false)
		if growth!=null:growth.emit_signal("pressed")
		await settle()
		check(main.active_screen=="growth" and main.get_meta("growth_hero_id","")==ids[4],"report routes precise hero to growth")
		check(main.wallet_gold==1050 and main.wallet_gems==10,"navigation spends nothing")
		main._open_challenge_report(int(report.serial));await settle()
		main._challenge_report_action("formation",int(report.serial))
		await settle()
		check(main.active_screen=="hero_select" and str(main.content_party_context.get("kind",""))=="meta","formation retains content-return route")
		main.selected_faction="noxfera" if faction=="aurelia" else "aurelia"
		var screen: String=main.active_screen
		main._open_challenge_report(int(report.serial));await settle()
		check(main.active_screen==screen,"foreign faction cannot open old report")
		main.selected_faction=faction
		main._build_meta_hub_screen();await settle()
		# Starting another encounter then leaving does not fabricate a success.
		check(main._run_daily_dungeon("survival"),"new actual session for cancel test")
		main._build_lobby_screen();await settle()
		var cancelled: Dictionary=main.get_meta("last_challenge_report",{})
		check(cancelled.get("reason","")=="left_screen" and not cancelled.has("previous"),"cancel report not compared to clears")
		check(main.daily_dungeon_runs==1 and main.wallet_gold==1050,"cancel grants nothing")
		main._open_challenge_report(int(report.serial));await settle()
		check(main.active_screen=="lobby","old report callback cannot open newer result")
		check(main.get_meta("challenge_report_history",[]).size()==1,"cancel not stored as performance history")
		if main.presentation_runtime!=null:main.presentation_runtime.audio.shutdown()
		await create_timer(0.5).timeout
		session=null;main.free();await create_timer(0.35).timeout
	print("v83_gameplay_battle checks=%d failures=%s"%[checks,JSON.stringify(failures)])
	quit(0 if failures.is_empty() else 1)
