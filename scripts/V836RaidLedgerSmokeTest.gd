extends "res://scripts/V83UpgradeTestBase.gd"
const L=preload("res://scripts/RaidContributionLedger.gd")
const A=preload("res://scripts/RaidReportArchive.gd")
func _init()->void:_run.call_deferred()
func _run()->void:
	for faction: String in ["aurelia","noxfera"]:
		var roster: Array=ROSTER.roster(faction).slice(0,3)
		var states: Dictionary={}
		for i in roster.size():states[roster[i].id]={"slot":i,"hp":100,"max_hp":100}
		var id: String=roster[0].id
		var ledger=L.new();ledger.begin(7,roster,states,{"faction":faction,"zone":"gray_meadow"})
		ledger.add(6,id,"boss_damage",900);ledger.add(7,id,"boss_damage",40)
		ledger.add(7,id,"guard_damage",20);ledger.add(7,id,"add_damage",10)
		ledger.add(7,"$support","boss_damage",15);ledger.add(7,"bad_source","boss_damage",5)
		ledger.add(7,id,"boss_damage",-9);ledger.add(7,id,"invalid",99)
		ledger.incoming(7,id,100,60,12,1);ledger.healed(7,id,8)
		ledger.add(7,id,"healing_given",8);ledger.add(7,id,"shield_given",20)
		ledger.add(7,id,"interrupts",1)
		var report: Dictionary=ledger.finish(7,"victory",10,states);report.stamp=faction
		check(report.total_damage==90,"direct channel sum, source split, stale token, invalid/negative calls")
		check(report.actors[0].healing_received==8 and report.actors[0].damage_taken==40 and report.actors[0].shield_absorbed==12,"recipient values independent of provider")
		check(report.totals.healing_given==8 and report.totals.shield_given==20 and report.totals.interrupts==1,"provider contributions")
		ledger.add(7,id,"boss_damage",99)
		check(ledger.totals.boss_damage==60 and ledger.finish(7,"victory",10,states).is_empty(),"close and duplicate finish are inert")
		var path: String="user://ledger-"+faction+".json"
		check(A.append(path,report),"real disk archive write")
		check(A.load_reports(path).size()==1 and A.append(path,report) and A.load_reports(path).size()==1,"actual JSON restore and duplicate receipt")
		for i in 17:
			report.stamp=faction+str(i);check(A.append(path,report),"bounded history write "+str(i))
		check(A.load_reports(path).size()==12,"history capped across installation")
		var altered: Dictionary=report.duplicate(true);altered.actors[0].boss_damage=INF
		check(A.clean(altered).is_empty(),"nonfinite rejected")
		altered=report.duplicate(true);altered.entry.faction="noxfera" if faction=="aurelia" else "aurelia"
		check(A.clean(altered).is_empty(),"cross-faction actors rejected")
		check(not A.append("user://missing-parent/does-not-exist.json",report),"write failure explicit, no game data side effects")
		var corrupt:=FileAccess.open(path,FileAccess.WRITE);corrupt.store_string('{broken');corrupt.close()
		check(A.load_reports(path).is_empty(),"malformed archive tolerated")
	var main=await make_main("aurelia",10)
	check(not main.has_meta("raid_contribution"),"ordinary game has no raid ledger")
	var observer=preload("res://scripts/RaidContributionService.gd")
	check(not observer.active(main),"observer inert before any raid")
	observer.add(main,"leonhardt","boss_damage",12)
	observer.healed(main,"leonhardt",12)
	observer.incoming(main,"leonhardt",100,90,2)
	observer.finish(main,"cancelled")
	check(not main.has_meta("raid_contribution"),"non-raid observation creates no ledger or error")
	main.selected_raid_id="gray_meadow";main._build_raid_screen();await settle();main._start_raid();main.combat_timer.stop()
	var ids: Array=main._deployed_hero_ids();var target: String=ids[0];var healer: String=ids[1]
	main.hero_battle_state[target].hp=int(main.hero_battle_state[target].max_hp)-10
	var actual: int=main.HERO_KITS._credited_heal(main,target,99999,healer)
	check(actual==10 and main.get_meta("raid_contribution").actors[healer].healing_given==10,"overheal is not counted")
	main.HERO_KITS.shield(main,target,.10,4.0,healer)
	var before: int=main.get_meta("raid_contribution").actors[healer].shield_given
	main.HERO_KITS.shield(main,target,.05,4.0,healer)
	check(main.get_meta("raid_contribution").actors[healer].shield_given==before,"weaker refresh creates no fictitious shield")
	main.boss_telegraph_pending=true;main.raid_control_immunity=0.0;main.raid_break_gauge=0.0
	main._raid_apply_control(.2,healer)
	check(main.get_meta("raid_contribution").totals.interrupts==0,"partial gauge is not a successful interrupt")
	main._raid_apply_control(1.0,healer)
	check(main.get_meta("raid_contribution").actors[healer].interrupts==1 and not main.boss_telegraph_pending,"actual cancelled cast attributed to finisher")
	main._finish_raid("cancelled");await dispose(main)
	done("v836_raid_ledger")
