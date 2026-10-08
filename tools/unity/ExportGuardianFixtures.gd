extends SceneTree
const GUARDIANS=preload("res://scripts/heroes/GuardianCatalog.gd")
const SUMMON=preload("res://scripts/progression/SummonService.gd")
const PROGRESS=preload("res://scripts/heroes/GuardianProgressionService.gd")

func _initialize():
	var script=GDScript.new()
	script.source_code="""extends Node
const GUARDIANS=preload("res://scripts/heroes/GuardianCatalog.gd")
const PROGRESS=preload("res://scripts/heroes/GuardianProgressionService.gd")
const ROSTER=preload("res://scripts/heroes/HeroRosterCatalog.gd")
const MAX_PET_LEVEL=100
var _save_blocked_for_newer_version=false
var selected_faction="aurelia"
var wallet_gems=1000
var guardian_free_claimed=false
var guardian_mythic_pity=0
var guardian_legendary_pity=0
var guardian_collection={}
var guardian_equipped=""
var summon_pity=0
var hero_shards={}
var codex_seen={}
var pet_progress={}
var pet_runtime={}
var save_count=0
var loot_rng=RandomNumberGenerator.new()
func _guardian_ensure_starter():PROGRESS.guardian_ensure_starter(self)
func _hero_roster_for_faction():return ROSTER.roster(selected_faction)
func _hero_shard_count(id):return int(hero_shards.get(id,0))
func _save_idle_state():save_count+=1
func _show_toast(_text):pass
func _refresh_growth_runtime():pass
func _setup_pet_runtime():pass
func _pet_progress_key():return PROGRESS.pet_progress_key(self)
func _get_pet_progress():return PROGRESS.get_pet_progress(self)
func _pet_evolution_for_level(level):return PROGRESS.pet_evolution_for_level(self,level)
func _pet_xp_to_next(level):return PROGRESS.pet_xp_to_next(self,level)
func _pet_profile():return PROGRESS.pet_profile(self)
func _pet_evolution_name(level):return PROGRESS.pet_evolution_name(self,level)
func payload():return {"selected_faction":selected_faction,"wallet_gems":wallet_gems,"guardian_free_claimed":guardian_free_claimed,"guardian_mythic_pity":guardian_mythic_pity,"guardian_legendary_pity":guardian_legendary_pity,"guardian_collection":guardian_collection.duplicate(true),"guardian_equipped":guardian_equipped,"summon_pity":summon_pity,"hero_shards":hero_shards.duplicate(true),"codex_seen":codex_seen.duplicate(true),"pet_progress":pet_progress.duplicate(true),"future_unknown":{"keep":true}}
"""
	if script.reload()!=OK:push_error("Guardian production adapter failed");quit(1);return
	var cases=[]
	for faction in ["aurelia","noxfera"]:
		for claimed in [false,true]:
			for pity in [[0,0],[78,28],[79,29],[0,29],[79,0]]:
				for seed_value in range(30):
					var host=script.new();host.selected_faction=faction;host.guardian_free_claimed=claimed
					host.guardian_mythic_pity=pity[0];host.guardian_legendary_pity=pity[1];PROGRESS.guardian_ensure_starter(host)
					host.guardian_collection[GUARDIANS.starter(faction)].copies=[1,3,4,6,7,998,999][seed_value%7]
					host.loot_rng.seed=seed_value+9514;var tape_rng=RandomNumberGenerator.new();tape_rng.seed=seed_value+9514;var tape=[]
					if pity[0]<79 and pity[1]<29:tape.append(tape_rng.randi_range(1,100))
					tape.append(tape_rng.randi_range(0,1));var before=host.payload();var result=SUMMON.summon_guardian(host)
					cases.append({"type":"guardian","before":before,"after":host.payload(),"result":result,"random_tape":tape,"saves":host.save_count});host.free()
		for pity in [0,8,9]:
			for seed_value in range(60):
				var host=script.new();host.selected_faction=faction;PROGRESS.guardian_ensure_starter(host);host.summon_pity=pity
				host.loot_rng.seed=seed_value+555;var tape_rng=RandomNumberGenerator.new();tape_rng.seed=seed_value+555
				var tape=[tape_rng.randi_range(0,14)];var before=host.payload();var result=SUMMON.summon_once(host)
				cases.append({"type":"hero","before":before,"after":host.payload(),"result":result,"random_tape":tape,"saves":host.save_count});host.free()
		for level in [1,4,5,9,10,99,100]:
			for xp in [0,60+(level-1)*35-1,100000000]:
				for amount in [0,1,60,500,100000000]:
					var host=script.new();host.selected_faction=faction;PROGRESS.guardian_ensure_starter(host);host.pet_progress[faction]={"level":level,"xp":xp,"evolution":0};PROGRESS.get_pet_progress(host)
					var before=host.payload();var result=PROGRESS.grant_pet_xp(host,amount)
					cases.append({"type":"pet","amount":amount,"before":before,"after":host.payload(),"result":result});host.free()
	var file=FileAccess.open("res://checks/unity-migration-2026-10-08/guardian-original-fixtures.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"source":"Actual SummonService and GuardianProgressionService against an isolated host; Godot RNG outputs recorded as input tapes, not a claim of PCG stream migration","cases":cases},"\t"));file.close()
	print("ETERNAL_GUARDIAN_ORACLE_OK ",cases.size());quit()
