extends SceneTree
const Progress = preload("res://scripts/heroes/HeroProgressionService.gd")
const Rewards = preload("res://scripts/progression/RewardClaimService.gd")
const Roster = preload("res://scripts/heroes/HeroRosterCatalog.gd")
class Host extends Node:
	const MAX_HERO_LEVEL = 100
	var selected_faction = "aurelia"
	var hero_progress = {}
	var hero_skill_tree = {}
	var hero_ascension = {}
	var hero_shards = {}
	var hero_breakthrough = {}
	var deployed_heroes = []
	var wallet_gold = 20000
	var wallet_xp = 0
	var wallet_gems = 0
	var unclaimed_gold = 100
	var unclaimed_xp = 200
	var idle_chest_gold = 50
	var idle_chest_xp = 75
	var daily_reward_claimed_day = ""
	var rewarded_ad_day = ""
	var rewarded_ad_claimed_count = 0
	var today = "2026-10-09"
	var _save_blocked_for_newer_version = false
	var hero_level_event = ""
	var active_screen = "combat"
	var combat_labels = {}
	func _valid_growth_hero(id): return Progress.valid_growth_hero(self,id)
	func _get_hero_progress(id): return Progress.get_hero_progress(self,id)
	func _hero_xp_to_next(level): return Progress.hero_xp_to_next(self,level)
	func _hero_short_name(id): return str(Roster.HEROES[id].name).get_slice(" ",0)
	func _refresh_growth_runtime(): pass
	func _save_idle_state(): pass
	func _show_toast(_text): pass
	func _record_first_session_action(_action): pass
	func _update_hero_progress_label(): pass
	func _build_growth_screen(): pass
	func _get_skill_tree(id): return Progress.get_skill_tree(self,id)
	func _skill_tree_total_points(id): return Progress.skill_tree_total_points(self,id)
	func _skill_tree_available_points(id): return Progress.skill_tree_available_points(self,id)
	func _skill_tree_spent(id): return Progress.skill_tree_spent(self,id)
	func _hero_roster_for_faction(): return Roster.roster(selected_faction)
	func _hero_base_grade_index(id): return Progress.hero_base_grade_index(self,id)
	func _hero_ascension_rank(id): return Progress.hero_ascension_rank(self,id)
	func _ascension_requirement(id): return Progress.ascension_requirement(self,id)
	func _hero_grade(id): return Progress.hero_grade(self,id)
	func _hero_breakthrough_rank(id): return Progress.hero_breakthrough_rank(self,id)
	func _hero_shard_count(id): return Progress.hero_shard_count(self,id)
	func _breakthrough_cost(rank): return Progress.breakthrough_cost(self,rank)
	func _today_key(): return today
	func _update_reward_labels(): pass
	func _update_stage_label(): pass
	func payload():
		var ids = []
		for hero in deployed_heroes: ids.append(hero.id)
		return {"selected_faction":selected_faction,"deployed_hero_ids":ids,"hero_progress":hero_progress.duplicate(true),"hero_skill_tree":hero_skill_tree.duplicate(true),"hero_ascension":hero_ascension.duplicate(true),"hero_shards":hero_shards.duplicate(true),"hero_breakthrough":hero_breakthrough.duplicate(true),"wallet_gold":wallet_gold,"wallet_xp":wallet_xp,"wallet_gems":wallet_gems,"unclaimed_gold":unclaimed_gold,"unclaimed_xp":unclaimed_xp,"idle_chest_gold":idle_chest_gold,"idle_chest_xp":idle_chest_xp,"daily_reward_claimed_day":daily_reward_claimed_day,"rewarded_ad_day":rewarded_ad_day,"rewarded_ad_claimed_count":rewarded_ad_claimed_count,"future_unknown":{"preserve":[1,2,3]}}
func _initialize():
	var cases = []
	var ids = []
	for hero in Roster.roster("aurelia"): ids.append(str(hero.id))
	for level in [1,20,99,100]:
		for amount in [1,9,107,1000,1000000,100000000,1000000000]:
			var host = Host.new()
			for index in 10:
				var id = ids[index]
				host.deployed_heroes.append({"id":id})
				host.hero_progress[id] = {"level":level,"xp":0 if level==100 else (Progress.hero_xp_to_next(host,level)-10 if index%3==0 else index*3)}
			var before = host.payload()
			Progress.grant_hero_xp(host,amount)
			cases.append({"command":"xp","amount":amount,"before":before,"after":host.payload()});host.free()
	var mixed = Host.new()
	for index in 10:
		mixed.deployed_heroes.append({"id":ids[index]})
		mixed.hero_progress[ids[index]]={"level":99 if index<5 else 1,"xp":Progress.hero_xp_to_next(mixed,99)-1 if index<5 else 0}
	mixed.deployed_heroes.append({"id":ids[0]});mixed.deployed_heroes.append({"id":"unknown"})
	var before_mixed=mixed.payload();Progress.grant_hero_xp(mixed,1000000)
	cases.append({"command":"xp","amount":1000000,"before":before_mixed,"after":mixed.payload()});mixed.free()
	for hero_id in ids:
		for asc in [0,1,2,3]:
			var host=Host.new();host.hero_progress[hero_id]={"level":30,"xp":0};host.hero_ascension[hero_id]=asc
			var before=host.payload();var ok=Progress.try_ascend_hero(host,hero_id)
			cases.append({"command":"ascend","hero":hero_id,"before":before,"after":host.payload(),"ok":ok,"grade":Progress.hero_grade(host,hero_id)});host.free()
	for level in [1,4,20,100]:
		for branch in ["offense","survival","utility"]:
			var host=Host.new();host.hero_progress[ids[0]]={"level":level,"xp":0};host.hero_skill_tree[ids[0]]={"offense":2,"survival":3,"utility":1}
			var before=host.payload();Progress.upgrade_skill_tree(host,ids[0],branch)
			cases.append({"command":"research","hero":ids[0],"branch":branch,"before":before,"after":host.payload()});host.free()
	for rank in [0,1,4,5]:
		for shards in [0,20,1000]:
			var host=Host.new();host.hero_breakthrough[ids[0]]=rank;host.hero_shards[ids[0]]=shards
			var before=host.payload();var ok=Progress.try_breakthrough(host,ids[0])
			cases.append({"command":"breakthrough","hero":ids[0],"before":before,"after":host.payload(),"ok":ok});host.free()
	for previous in ["","2026-10-08","2026-10-09","2026-10-10"]:
		var host=Host.new();host.daily_reward_claimed_day=previous;var before=host.payload();var button=Button.new();var label=Label.new()
		Rewards.claim_daily_reward(host,button,label);cases.append({"command":"daily","day":host.today,"before":before,"after":host.payload()});button.free();label.free();host.free()
	for previous in ["","2026-10-08","2026-10-09","2026-10-10"]:
		for count in [0,2,3]:
			var host=Host.new();host.rewarded_ad_day=previous;host.rewarded_ad_claimed_count=count;var before=host.payload();var button=Button.new();var label=Label.new()
			Rewards.claim_rewarded_ad(host,button,label);cases.append({"command":"support","day":host.today,"before":before,"after":host.payload()});button.free();label.free();host.free()
	var claim=Host.new();var before_claim=claim.payload();Rewards.claim_rewards(claim)
	cases.append({"command":"claim","before":before_claim,"after":claim.payload()});claim.free()
	var report={"sources":["scripts/heroes/HeroProgressionService.gd","scripts/progression/RewardClaimService.gd"],"cases":cases,"note":"Production services with an isolated no-save host. Original user data, combat, UI input and persistent paths are not accessed."}
	var output=FileAccess.open("res://Unity/Assets/Game/Editor/Fixtures/progression-command-fixtures.json",FileAccess.WRITE);output.store_string(JSON.stringify(report,"\t"));output.close()
	print("ETERNAL_PROGRESSION_ORACLE_OK ",cases.size()," cases");quit()
