extends "res://tests/support/V83UpgradeTestBase.gd"
const RULES = preload("res://scripts/combat/ChallengePatternRules.gd")
class ClockHost extends "res://tests/support/V83GameplayBattleHost.gd":
	var test_week: String = ""
	func _week_key() -> String:
		return super._week_key() if test_week.is_empty() else test_week
func _init() -> void: _run.call_deferred()
func _fixture(faction: String):
	root.content_scale_size = Vector2i(720,1280); root.size = Vector2i(720,1280)
	var main = ClockHost.new()
	main.save_state_path = "user://v835-patterns-"+faction+".json"
	root.add_child(main);main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);await settle()
	main.set_process(false);main.set_physics_process(false);main._offline_checked=true
	main.selected_faction=faction;main.current_zone_id="gray_meadow";main.idle_stage=100;main.party_slot_legacy_cap=10
	var ids: Array[String] = []
	for hero in ROSTER.roster(faction):
		if ids.size()<10:ids.append(str(hero.id))
	main._restore_deployed_heroes(ids)
	for id in ids:main.hero_progress[id]={"level":60,"xp":0}
	main.combat_effects_enabled=false;main.sound_effects_enabled=false;main.battle_speed=1.0
	main.skill_auto=true;main.ultimate_auto=true
	main.daily_dungeon_day=main._today_key();main.daily_dungeon_runs=3
	main.weekly_content_key=main._week_key();main.weekly_trial_runs=5
	main.tower_floor=13;main.tower_best_floor=12;main.wallet_gold=10000;main.wallet_gems=100
	main._build_lobby_screen();await settle();main._save_idle_state()
	return main
func _run() -> void:
	var observations: Array = []
	for faction: String in ["aurelia","noxfera"]:
		var main = await _fixture(faction)
		# Actual hero AI. Synthetic clock selects all three weekly rotations,
		# never skips the 90 game seconds or changes HP/skills to force victory.
		var cases: Array = [["tower",10,""],["tower",11,""],["tower",12,""],["weekly",1,"2961"],["weekly",1,"2962"],["weekly",1,"2963"]]
		for c in cases:
			main.test_week = str(c[2]); main.weekly_content_key=main._week_key()
			main._open_practice_screen();await settle();main._save_idle_state()
			var before: Dictionary = economic(main)
			main.audit_damage=0;main.audit_raw_damage=0;main.audit_sources.clear()
			check(main._start_practice(str(c[0]),int(c[1]),"",PRACTICE.context(main)),"start "+faction+str(c))
			var session: ChallengeBattleSession = main.challenge_session
			if session == null: continue
			var disk: PackedByteArray = FileAccess.get_file_as_bytes(main.save_state_path)
			var ticks: int = 0; var patterns_seen: int = 0; var last_wave: int = -1
			var cast_ticks: int = 0; var healers_seen: int = 0
			while main.challenge_session!=null and ticks<2900:
				if session.active_wave_token != last_wave and RULES.active(session):
					last_wave = session.active_wave_token; patterns_seen += 1
					var total: int = 0
					for index in main.enemy_wave.size():
						var enemy: Dictionary = main.enemy_wave[index]
						total += int(enemy["max_hp"])
						if enemy.get("challenge_pattern_role","")=="healer": healers_seen+=1
						var pos: Vector2 = main.roaming_hunt.enemy_position(index)
						check(main.roaming_hunt.field_navigation.is_walkable(pos),"pattern spawn walkable")
					if c[0]=="weekly":
						var original: Dictionary = preload("res://scripts/progression/WeeklyAbyssBattleRules.gd").enemy_stats(main.test_week,session.cleared_waves)
						check(total==int(original["hp"])*2,"weekly original HP budget preserved")
				for enemy in main.enemy_wave:
					if float(enemy.get("pattern_cast_remaining",0.0))>0:cast_ticks+=1
				main._advance_auto_hunt(1.0/30.0); ticks+=1
				if ticks==80:
					main.combat_running=false
					var paused: Array=main.enemy_wave.duplicate(true)
					var timer: float=session.elapsed
					main._advance_auto_hunt(1.0)
					check(paused==main.enemy_wave and session.elapsed==timer,"pause all pattern and HP state")
					main.combat_running=true
					main._save_idle_state();check(disk==FileAccess.get_file_as_bytes(main.save_state_path),"practice cannot persist temporary states")
				if ticks%30==0: await process_frame
			var report: Dictionary=main.get_meta("last_challenge_report",{})
			check(main.challenge_session==null and main.active_screen=="practice","natural battle returned")
			check(report.get("reason","") in ["waves_cleared","score_finished"],"natural completion "+faction+str(c))
			check(patterns_seen>0,"new pattern actually spawned "+str(c))
			check(report.get("total_damage",-1)==main.audit_damage and main.audit_damage>0,"independent effective HP equals report")
			check(report.get("pattern",{})==session.pattern,"pattern identity in report")
			if c[0]=="weekly":check(is_equal_approx(session.elapsed,90.0) and session.damage_score==main.audit_damage,"full duration and effective score")
			var after: Dictionary=economic(main)
			for field in before:check(before[field]==after[field],"practice state conserved "+field)
			check(session.take_victory_receipt(session.serial).is_empty(),"practice no receipt")
			observations.append({"faction":faction,"case":c,"reason":report.get("reason",""),"elapsed":session.elapsed,"pattern":session.pattern,"pattern_waves":patterns_seen,"healers_seen":healers_seen,"cast_ticks":cast_ticks,"metrics":session.pattern_metrics,"effective_hp":main.audit_damage,"raw_hp":main.audit_raw_damage})
			await settle()
		await dispose(main)
	print("v835_natural_observations="+JSON.stringify(observations))
	done("v835_pattern_battle")
