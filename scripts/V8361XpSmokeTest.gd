extends "res://scripts/V83UpgradeTestBase.gd"
const XP = preload("res://scripts/HeroProgressionService.gd")
class XpHost extends Node:
	const MAX_HERO_LEVEL: int = 100
	var deployed_heroes: Array = []
	var allowed: Array = []
	var selected_faction: String = "aurelia"
	var hero_progress: Dictionary = {}
	var hero_level_event: String = ""
	var refreshes: int = 0
	func _hero_roster_for_faction() -> Array: return allowed
	func _valid_growth_hero(id: String) -> bool: return XP.valid_growth_hero(self,id)
	func _get_hero_progress(id: String) -> Dictionary: return XP.get_hero_progress(self,id)
	func _hero_xp_to_next(level: int) -> int: return XP.hero_xp_to_next(self,level)
	func _hero_short_name(id: String) -> String: return id
	func _refresh_growth_runtime() -> void: refreshes += 1
func _init() -> void: _run.call_deferred()
func host(faction: String, count: int) -> XpHost:
	var h := XpHost.new()
	h.selected_faction = faction
	h.allowed = ROSTER.roster(faction)
	h.deployed_heroes = h.allowed.slice(0,count)
	for hero in h.allowed: h.hero_progress[hero.id] = {"level":1,"xp":0}
	return h
func capacity(progress: Dictionary) -> int:
	var value: int = 0
	for level in range(int(progress.level),100): value += 100+(level-1)*75
	return maxi(0,value-int(progress.xp))
func _run() -> void:
	for faction: String in ["aurelia","noxfera"]:
		var h := host(faction,2)
		var a: String = h.deployed_heroes[0].id
		var b: String = h.deployed_heroes[1].id
		h.hero_progress[a]={"level":99,"xp":7449}
		XP.grant_hero_xp(h,100)
		check(h.hero_progress[a]=={"level":100,"xp":0},"cap-boundary actor consumes its last XP "+faction)
		check(h.hero_progress[b]=={"level":1,"xp":99},"49 overflow XP redistributed instead of lost "+faction)
		check(h.refreshes==1,"one growth refresh after whole allocation")
		h.free()
		h=host(faction,3)
		a=h.deployed_heroes[0].id;b=h.deployed_heroes[1].id
		var c: String=h.deployed_heroes[2].id
		h.hero_progress[a]={"level":99,"xp":7449};h.hero_progress[b]={"level":99,"xp":7448}
		XP.grant_hero_xp(h,9)
		check(h.hero_progress[c].xp==6 and h.hero_progress[a].level==100 and h.hero_progress[b].level==100,"two simultaneous cap overflows redistributed")
		h.free()
		h=host(faction,10)
		XP.grant_hero_xp(h,3)
		var sum: int=0
		for hero in h.deployed_heroes: sum+=int(h.hero_progress[hero.id].xp)
		check(sum==3,"three XP across ten heroes conserves pool")
		var before: Dictionary=h.hero_progress.duplicate(true)
		XP.grant_hero_xp(h,0);XP.grant_hero_xp(h,-1)
		check(h.hero_progress==before,"nonpositive rewards inert")
		h.free()
		h=host(faction,2);a=h.deployed_heroes[0].id;b=h.deployed_heroes[1].id
		h.hero_progress[a]={"level":100,"xp":0}
		h.deployed_heroes.append(h.deployed_heroes[1])
		var foreign: Dictionary=ROSTER.roster("noxfera" if faction=="aurelia" else "aurelia")[0]
		h.deployed_heroes.append(foreign);h.hero_progress[foreign.id]={"level":1,"xp":0}
		XP.grant_hero_xp(h,25)
		check(h.hero_progress[b].xp==25 and h.hero_progress[foreign.id].xp==0,"unique valid nonmax heroes only")
		h.hero_progress[b]={"level":99,"xp":7449}
		XP.grant_hero_xp(h,100)
		check(h.hero_progress[b].level==100 and h.hero_progress[b].xp==0,"all-max remainder not minted as XP")
		check(h.hero_level_event.contains("99"),"all-max unused pool disclosed")
		h.free()
		var rng:=RandomNumberGenerator.new();rng.seed=8361001
		for trial in 240:
			h=host(faction,1+trial%10)
			var ids: Array[String]=[];var initial_capacity: int=0
			for hero in h.deployed_heroes:
				var level: int=rng.randi_range(1,100)
				var residual: int=rng.randi_range(0,99+(level-1)*75) if level<100 else 0
				h.hero_progress[hero.id]={"level":level,"xp":residual};ids.append(hero.id)
				initial_capacity+=capacity(h.hero_progress[hero.id])
			var reward: int=[1,3,99,1000,100000000,100000001][trial%6]
			XP.grant_hero_xp(h,reward)
			var final_capacity: int=0;var valid: bool=true
			for id in ids:
				var p: Dictionary=h.hero_progress[id];final_capacity+=capacity(p)
				valid=valid and p.level>=1 and p.level<=100 and p.xp>=0 and (p.xp==0 if p.level==100 else p.xp<h._hero_xp_to_next(p.level))
			check(initial_capacity-final_capacity==mini(initial_capacity,mini(reward,100000000)),"allocation conservation "+faction+str(trial))
			check(valid,"legal per-hero growth bounds "+faction+str(trial))
			h.free()
	done("v8361_xp")
