extends "res://tests/support/V83UpgradeTestBase.gd"
const LEVELS=preload("res://scripts/progression/PracticeLevelRules.gd")
func _init() -> void: _run.call_deferred()
func _run() -> void:
	for faction: String in ["aurelia","noxfera"]:
		var main=await make_main(faction,10)
		var ids: Array=main._deployed_hero_ids()
		for i in ids.size(): main.hero_progress[ids[i]]={"level": 4+i*3,"xp":17}
		main.hero_progress[ROSTER.roster(faction)[12]["id"]]={"level":60,"xp":0}
		# Real mixed-level AI fixture, no forced HP/death/win or shortened timer.
		var cases: Array=[["daily",1,"gold_rush"],["daily",3,"boss_hunt"],["tower",5,""],["weekly",1,""],["daily",1,"survival"],["daily",1,"gold_rush"]]
		for c: Array in cases:
			main._open_practice_screen(); await settle();main._save_idle_state()
			var before: Dictionary=economic(main)
			main.audit_damage=0;main.audit_sources.clear();main.audit_taken.clear();main.audit_healing.clear()
			check(main._start_practice(c[0],c[1],c[2],PRACTICE.context(main),"matched",60),"start "+faction+str(c))
			var session=main.challenge_session
			if session==null: continue
			var disk: PackedByteArray=FileAccess.get_file_as_bytes(main.save_state_path)
			var ticks: int=0
			while main.challenge_session!=null and ticks<2900:
				main._advance_auto_hunt(1.0/30.0);ticks+=1
				if ticks==100:
					main._save_idle_state()
					check(disk==FileAccess.get_file_as_bytes(main.save_state_path),"mid-combat file immutable")
					check(main.hero_progress==before.hero_progress,"RAM actual levels immutable while AI runs")
				if ticks%30==0: await process_frame
			var report: Dictionary=main.get_meta("last_challenge_report",{})
			check(main.challenge_session==null and main.active_screen=="practice","normal practice result")
			check(report.get("reason","") in ["waves_cleared","survived","score_finished"],"natural completion "+faction+str(c))
			check(report.get("total_damage",-1)==main.audit_damage and main.audit_damage>0,"independent actual HP matches report")
			check(report.get("entry",{}).get("level_mode","")=="matched" and report.entry.match_level==60,"report labels matching level")
			if c[0]=="weekly":check(is_equal_approx(session.elapsed,90.0),"full 90 game seconds")
			if c[2]=="survival":check(is_equal_approx(session.elapsed,60.0),"full 60 game seconds")
			var after: Dictionary=economic(main)
			for field in before:check(before[field]==after[field],"persistent field conserved "+field+faction+str(c))
			check(not main.has_meta("practice_level_override") and not main.has_meta("practice_snapshot"),"no stale overlay after finish")
			check(main._effective_combat_level(ids[0])==4 and session.take_victory_receipt(session.serial).is_empty(),"actual level restored and no rewards")
			await settle()
		check(main.get_meta("last_challenge_report",{}).has("previous"),"same matched scenario compares")
		var actual: Dictionary=main.hero_progress.duplicate(true)
		main._load_idle_state()
		check(main.hero_progress==actual and not main.has_meta("practice_level_override"),"reload after simulations preserves original growth")
		await dispose(main)
	done("v834_matched_battle")
