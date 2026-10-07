extends "res://tests/support/V83UpgradeTestBase.gd"
func _init() -> void: _run.call_deferred()
func _run() -> void:
	for faction in ["aurelia", "noxfera"]:
		var main = await make_main(faction,10)
		# Actual AI, no HP erasing, fake clear, clock shortening or reward service stubs.
		var cases: Array = [["daily",1,"gold_rush"],["daily",3,"boss_hunt"],["tower",5,""]]
		if faction == "aurelia": cases.append(["daily",1,"survival"]); cases.append(["weekly",1,""])
		cases.append(["daily",1,"gold_rush"])
		for c: Array in cases:
			main._open_practice_screen(); await settle(); main._save_idle_state()
			var baseline: Dictionary = economic(main)
			var file_before: PackedByteArray = PackedByteArray()
			main.audit_damage = 0; main.audit_sources.clear(); main.audit_taken.clear(); main.audit_healing.clear()
			var bound: Dictionary = PRACTICE.context(main)
			check(main._start_practice(c[0],c[1],c[2],bound), "practice entry despite exhausted allowances " + faction+str(c))
			check(not main._start_practice(c[0],c[1],c[2],bound), "duplicate entry rejected")
			var session = main.challenge_session
			if session == null: continue
			# Entry commits a baseline once (including its wall-clock timestamp).
			# Freeze-check bytes AFTER that successful commit, not before entry.
			file_before = FileAccess.get_file_as_bytes(main.save_state_path)
			var old_elapsed: float = session.elapsed
			main.combat_running = false; main._advance_auto_hunt(0.25)
			check(session.elapsed == old_elapsed, "pause stops practice clock")
			main.combat_running = true
			var ticks: int = 0; var seen: Dictionary = {}
			while main.challenge_session != null and ticks < 2900:
				for enemy in main.enemy_wave: seen[str(enemy.id)] = true
				main._advance_auto_hunt(1.0/30.0); ticks += 1
				if ticks == 100:
					main._save_idle_state()
					check(FileAccess.get_file_as_bytes(main.save_state_path) == file_before, "practice cannot write transient state")
				if ticks % 30 == 0: await process_frame
			check(main.challenge_session == null and main.active_screen == "practice", "natural practice completion")
			var report: Dictionary = main.get_meta("last_challenge_report", {})
			check(report.get("practice",false) and report.get("total_damage",-1) == main.audit_damage and main.audit_damage>0, "report matches independently observed actual HP loss")
			check(report.get("reason","") in ["waves_cleared","survived","score_finished"], "leveled fixture completes actual objective")
			if c[0] == "weekly": check(is_equal_approx(session.elapsed,90.0), "actual full 90 game seconds")
			if c[2] == "survival": check(is_equal_approx(session.elapsed,60.0), "actual full survival minute")
			check(seen.size()>0 and report.get("actors",[]).size()==10, "10-hero actual encounter evidence")
			var after: Dictionary = economic(main)
			for key in baseline: check(baseline[key] == after[key], "no persistent mutation " +key+str(c)+faction)
			check(session.take_victory_receipt(session.serial).is_empty(), "no practice reward receipt")
			check(main.get_meta("challenge_report_history",[]).is_empty(), "practice never enters real record history")
			check(not bool(main.get_meta("practice_active",false)), "practice snapshot cleaned")
			await settle()
		var last: Dictionary = main.get_meta("last_challenge_report",{})
		check(last.has("previous"), "same practice scenario supports comparison")
		main._open_practice_screen(); await settle(); main._save_idle_state()
		var before_cancel: Dictionary = economic(main)
		var stale: Dictionary = PRACTICE.context(main)
		main._open_practice_screen(); await settle()
		check(not main._start_practice("daily",1,"gold_rush",stale), "old screen callback rejected")
		check(main._start_practice("weekly",1,""), "cancel scenario starts")
		for i in 30: main._advance_auto_hunt(1.0/30.0)
		main._build_lobby_screen(); await settle()
		check(main.challenge_session == null and before_cancel == economic(main), "leaving practice restores all economic state")
		await dispose(main)
	done("v83_practice_battle")
