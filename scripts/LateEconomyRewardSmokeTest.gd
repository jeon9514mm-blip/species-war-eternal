extends SceneTree
const HOST=preload("res://tools/EconomySimulationHost.gd")
const RULES=preload("res://scripts/GrowthEconomyRules.gd")
const FIELD=preload("res://scripts/HuntFieldService.gd")
var checks:=0
var failures: Array[String]=[]
class Probe extends "res://tools/EconomySimulationHost.gd":
	var award: Dictionary={}
	func _on_hunt_reward(gold: int,xp: int,drops: Array[Dictionary],cleared: bool,chest_gold:=0,chest_xp:=0) -> void:
		award={"gold":gold,"xp":xp,"cleared":cleared,"chest_gold":chest_gold,"chest_xp":chest_xp}
		super._on_hunt_reward(gold,xp,drops,cleared,chest_gold,chest_xp)
func _init() -> void:run.call_deferred()
func check(ok: bool,note: String) -> void:
	checks+=1
	if not ok:failures.append(note);push_error(note)
func run() -> void:
	var fixtures: Dictionary={1:[300,125,43],25:[1500,725,115],26:[1550,750,118],29:[1600,775,121],125:[2000,975,145],425:[2500,1225,175]}
	for stage in fixtures:
		var reward: Dictionary=RULES.stage_chest(stage);var expected: Array=fixtures[stage]
		check([reward.gold,reward.xp,reward.rations]==expected,"independent milestone reward "+str(stage))
	for stage in range(1,26):
		var reward: Dictionary=RULES.stage_chest(stage)
		check(reward.gold==250+stage*50 and reward.xp==100+stage*25 and reward.rations==40+stage*3,"first 25 milestones retain existing payouts")
	var last: Dictionary=RULES.stage_chest(25)
	for stage in range(26,10001,17):
		var reward: Dictionary=RULES.stage_chest(stage)
		check(reward.gold>=last.gold and reward.xp>=last.xp and reward.rations>=last.rations,"late rewards grow monotonically without runaway payouts")
		last=reward
	check(RULES.stage_chest(10000).gold<6500 and RULES.stage_chest(10000).xp<3300,"late field rewards stay within explicit economy budgets")
	for faction: String in ["aurelia","noxfera"]:
		var main=Probe.new();root.add_child(main);main.boot(faction,7101)
		main.idle_stage=125;main.idle_stage_kills=9
		var corps: Array=[{"hp":0,"max_hp":10,"habitat_pack":0}]
		var gold_before: int=main.wallet_gold
		FIELD.settle_corps(main,corps,{})
		check(main.idle_stage==126 and main.idle_stage_kills==0 and main.award.cleared,"online late-stage crossing settles one chest")
		check(main.award.chest_gold==main._guardian_reward(2000,"online_gold") and main.award.chest_xp==main._guardian_reward(975,"online_xp"),"online chest uses shared budget with guardian modifiers")
		check(main.wallet_gold-gold_before==int(main.award.gold)+int(main.award.chest_gold),"online wallet conserves ordinary and chest rewards")
		var estimator:=IdleHuntEstimator.new()
		var offline: Dictionary=estimator.estimate(3600,main._calculate_party_power(),1,main._current_zone(),125,9,10,{"seconds_per_pack":3600})
		check(offline.stage_clears==1 and offline.chest_gold==2000 and offline.chest_xp==975,"offline late-stage chest has the same base payout")
		var full: Dictionary=estimator.estimate(28800,main._calculate_party_power(),1,main._current_zone(),125,0,10,{"seconds_per_pack":60})
		check(full.stage_clears==5 and full.chest_gold==10022 and full.chest_xp==4885,"capped offline receipt sums five exact milestones")
		main.idle_stage=10000;main.idle_stage_kills=9;FIELD.settle_corps(main,corps,{})
		check(main.idle_stage==10000 and not main.award.cleared and main.award.chest_gold==0 and main.award.gold>0,"online cap grants ordinary rewards without repeated chests")
		var cap: Dictionary=estimator.estimate(28800,main._calculate_party_power(),1,main._current_zone(),10000,9,10)
		check(cap.stage_clears==0 and cap.chest_gold==0 and cap.chest_xp==0,"offline cap cannot mint repeated milestone rewards")
		main.free();await process_frame
	print("LATE_ECONOMY_REWARD checks=%d failures=%s"%[checks,JSON.stringify(failures)])
	quit(0 if failures.is_empty() else 1)
