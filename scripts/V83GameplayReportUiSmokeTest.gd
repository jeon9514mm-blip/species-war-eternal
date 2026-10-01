extends SceneTree
## Settlement/history fixtures and actual UI nodes. Not an AI battle test.
const SESSION=preload("res://scripts/ChallengeBattleSession.gd")
const DRIVER=preload("res://scripts/ChallengeBattleDirector.gd")
const DAILY=preload("res://scripts/DailyDungeonBattleRules.gd")
const CATALOG=preload("res://scripts/HeroRosterCatalog.gd")
const LEDGER=preload("res://scripts/ChallengeCombatLedger.gd")
class ReportHost extends Node:
	var hero_battle_state: Dictionary={}
var checks: int=0
var failures: Array[String]=[]
func check(ok: bool,note: String) -> void:
	checks+=1
	if not ok:failures.append(note);push_error(note)
func _init() -> void:_run.call_deferred()
func settle() -> void:
	for frame in 8:await process_frame
func _run() -> void:
	var settlement_only: Node=Node.new()
	var blank=SESSION.new()
	blank.begin(99,DAILY.plan("gold_rush"),{})
	blank.defeat("timeout")
	DRIVER.publish_report(settlement_only,blank)
	check(not settlement_only.has_meta("last_challenge_report"),"no battle observations: report never requires HP state or affects settlement")
	settlement_only.free()
	var roster: Array=CATALOG.roster("aurelia");roster.resize(10)
	var fake=ReportHost.new()
	var ids: Array[String]=[]
	for i in roster.size():
		var h: Dictionary=roster[i];ids.append(str(h.id))
		fake.hero_battle_state[h.id]={"hp":100,"max_hp":100,"slot":i,"role_group":h.role_group}
	for serial in range(1,10):
		var session=SESSION.new()
		session.begin(serial,DAILY.plan("gold_rush"),{"day":"2026-10-01","run_index":0,"faction":"aurelia","zone":"gray_meadow","hero_ids":ids})
		session.combat_ledger.begin(roster,fake.hero_battle_state,true,true)
		session.combat_ledger.begin_wave(serial,[{"id":"target","hp":1000}])
		session.combat_ledger.damage(serial,"target",1000,1000-serial*10,serial%10,false)
		session.elapsed=60;session.defeat("timeout")
		DRIVER.publish_report(fake,session)
		var report: Dictionary=fake.get_meta("last_challenge_report",{})
		check(report.serial==serial and report.total_damage==serial*10,"fresh observed session")
		if serial>1:check(int(report.get("previous",{}).get("serial",-1))==serial-1,"same difficulty previous attempt")
		check(fake.get_meta("challenge_report_history",[]).size()==mini(serial,6),"bounded history")
	var a: Dictionary={"mode":"weekly","entry":{"week":"2026-40","faction":"aurelia","zone":"gray_meadow","run_index":0}}
	var b: Dictionary=a.duplicate(true);b.entry.run_index=4
	check(LEDGER.comparison_key(a)==LEDGER.comparison_key(b),"weekly equal encounter unaffected by quota index")
	var snapshot: Dictionary=fake.get_meta("last_challenge_report",{}).duplicate(true)
	fake.free()
	for scene_path in ["res://scenes/PortraitMain.tscn","res://scenes/Main.tscn"]:
		root.content_scale_size=Vector2i(720,1280);root.size=Vector2i(720,1280)
		var main=load(scene_path).instantiate()
		main.save_state_path="user://v83-report-ui-"+str(checks)+".json"
		root.add_child(main);await settle()
		main.set_process(false);main.set_physics_process(false);main._offline_checked=true
		main.selected_faction="aurelia";main.idle_stage=100;main.party_slot_legacy_cap=10
		main._restore_deployed_heroes(ids)
		main.set_meta("last_challenge_report",snapshot.duplicate(true))
		main.set_meta("content_meta_tab","daily")
		main._build_meta_hub_screen();await settle()
		var opener=main.find_child("ChallengeReportOpen",true,false)
		check(opener!=null,"entry on "+scene_path)
		if opener!=null:opener.emit_signal("pressed")
		await settle()
		check(main.active_screen=="challenge_report","both UI paths render same report")
		check(main.find_child("ChallengeReportComparison",true,false)!=null,"previous attempt comparison displayed")
		var scroll: ScrollContainer=main.find_child("PortraitContentScroll",true,false)
		check(scroll!=null and scroll.get_v_scroll_bar().max_value>scroll.size.y,"ten rows scroll, not clipped")
		if scroll!=null:
			scroll.scroll_vertical=int(scroll.get_v_scroll_bar().max_value);await settle()
			var final_row: Node=main.find_child("ChallengeActorGrowth_"+str(snapshot.actors[-1].id),true,false)
			check(final_row!=null and scroll.get_global_rect().intersects(final_row.get_global_rect()),"last actor button reachable by scroll")
			scroll.scroll_vertical=0;await settle()
		var before: Array=[main.wallet_gold,main.wallet_gems,main.daily_dungeon_runs,main.tower_floor,main.weekly_trial_runs,main.deployed_heroes.duplicate(true)]
		main._challenge_report_action("growth",int(snapshot.serial),"not_a_member")
		check(main.active_screen=="challenge_report","invalid hero action refused")
		main._challenge_report_action("formation",int(snapshot.serial)-1)
		check(main.active_screen=="challenge_report","stale serial refused")
		check(before==[main.wallet_gold,main.wallet_gems,main.daily_dungeon_runs,main.tower_floor,main.weekly_trial_runs,main.deployed_heroes],"view/action checks do not spend or edit party")
		# Optional real GPU rendering of this explicitly synthetic layout fixture.
		var out: String=OS.get_environment("V83_REPORT_CAPTURE")
		if not out.is_empty() and scene_path.contains("Portrait"):
			await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().save_png(out)==OK,"actual rendered layout fixture captured")
		var back=main.find_child("ChallengeReportBack",true,false)
		if back!=null:back.emit_signal("pressed")
		await settle()
		check(main.active_screen=="meta_hub" and main.get_meta("content_meta_tab","")=="daily","back returns same content")
		if main.presentation_runtime!=null:main.presentation_runtime.audio.shutdown()
		await create_timer(0.5).timeout;main.free();await create_timer(0.35).timeout
	print("v83_gameplay_report_ui checks=%d failures=%s"%[checks,JSON.stringify(failures)])
	quit(0 if failures.is_empty() else 1)
