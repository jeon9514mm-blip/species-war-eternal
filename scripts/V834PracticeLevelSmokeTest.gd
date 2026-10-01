extends "res://scripts/V83UpgradeTestBase.gd"
const LEVELS = preload("res://scripts/PracticeLevelRules.gd")
const LEDGER = preload("res://scripts/ChallengeCombatLedger.gd")
func _init() -> void: _run.call_deferred()
func _run() -> void:
	for faction: String in ["aurelia","noxfera"]:
		var main = await make_main(faction,10)
		var ids: Array = main._deployed_hero_ids()
		for i in ids.size(): main.hero_progress[ids[i]] = {"level":4+i*3,"xp": i+3}
		var mentor: String = ROSTER.roster(faction)[12]["id"]
		main.hero_progress[mentor] = {"level":60,"xp":5}
		main._open_practice_screen(); await settle(); main._save_idle_state()
		check(LEVELS.ceiling(main)==60,"same faction benched hero defines ceiling")
		var foreign: String=ROSTER.roster("noxfera" if faction=="aurelia" else "aurelia")[0]["id"]
		main.hero_progress[foreign]={"level":100,"xp":0}
		check(LEVELS.ceiling(main)==60,"foreign hero never raises ceiling")
		for level: int in [-1,0,61,101]: check(LEVELS.plan(main,"matched",level).is_empty(),"invalid level rejected "+str(level))
		check(LEVELS.plan(main,"invented",10).is_empty(),"unknown level mode rejected")
		var before: Dictionary=economic(main)
		var stats: Dictionary={}
		for id: String in ids: stats[id]=main._hero_combat_stats(id)
		check(main._start_practice("daily",1,"gold_rush",{},"matched",60),"matched starts without spending allowance")
		var session=main.challenge_session
		var disk: PackedByteArray=FileAccess.get_file_as_bytes(main.save_state_path)
		for id: String in ids:
			check(main._effective_combat_level(id)==60,"battle effective level is matched "+id)
			check(main._get_hero_progress(id)==before.hero_progress[id],"actual progress never rewritten "+id)
			check(main.hero_battle_state[id].max_hp>stats[id].max_hp,"matched stats initialized for real AI "+id)
			check(main._skill_tree_total_points(id)==clampi(int((int(before.hero_progress[id].level)-1)/3.0),0,30),"no artificial research budget "+id)
		main._application_suspended=true
		main._advance_auto_hunt(0.25); main._save_idle_state()
		check(session.elapsed==0.0 and disk==FileAccess.get_file_as_bytes(main.save_state_path),"suspended practice cannot advance or save override")
		main._application_suspended=false
		for i in 30: main._advance_auto_hunt(1.0/30.0)
		main._build_lobby_screen(); await settle()
		check(not main.has_meta("practice_level_override"),"leaving clears level override")
		var after: Dictionary = economic(main)
		for key in before:
			if before[key] != after[key]: print("DIFF ",key, "\nBEFORE=", JSON.stringify(before[key]), "\nAFTER=",JSON.stringify(after[key]))
			check(before[key]==after[key],"leaving restores "+key)
		for id: String in ids:
			check(main._effective_combat_level(id)==int(before.hero_progress[id].level),"ordinary level restored "+id)
			check(main._hero_combat_stats(id)==stats[id],"ordinary combat stats unchanged "+id)
		main._save_idle_state()
		var saved: Dictionary=main.save_store.read_save(main.save_state_path).data
		check(not saved.has("practice_level_override") and saved.hero_progress==JSON.parse_string(JSON.stringify(before.hero_progress)),"disk has no practice levels")
		main._load_idle_state()
		check(not main.has_meta("practice_level_override") and main.hero_progress==before.hero_progress,"reload sees actual progression")
		var report: Dictionary={"practice":true,"mode":"daily","variant":"gold_rush","entry":{"faction":faction,"zone":"gray_meadow","run_index":0}}
		var actual_key: String=LEDGER.comparison_key(report)
		report.entry.level_mode="matched";report.entry.match_level=60
		var matched_key: String=LEDGER.comparison_key(report)
		check(actual_key!=matched_key,"actual and matched reports segregated")
		report.entry.match_level=30
		check(LEDGER.comparison_key(report)!=matched_key,"different matching levels segregated")
		report.entry.match_level=60
		check(LEDGER.comparison_key(report)==matched_key,"same matching setup supports comparison")
		main._open_practice_screen(); await settle()
		var old: Dictionary=PRACTICE.context(main)
		main.hero_progress[ids[0]].level+=1
		check(not main._start_practice("daily",1,"gold_rush",old,"matched",60),"old growth context rejects entry")
		main.idle_stage=1
		check(LEVELS.plan(main,"matched",60).is_empty(),"unlocked state revalidated at entry")
		await dispose(main)
	done("v834_practice_level")
