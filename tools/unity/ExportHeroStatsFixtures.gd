extends SceneTree
const ROSTER=preload("res://scripts/heroes/HeroRosterCatalog.gd")
const GEAR=preload("res://scripts/equipment/EquipmentRules.gd")

func _initialize() -> void:
	var source=FileAccess.get_file_as_string("res://scripts/app/Main.gd")
	var adapter="""extends Node
const HERO_ROSTER=preload("res://scripts/heroes/HeroRosterCatalog.gd")
const _HERO_PROGRESS=preload("res://scripts/heroes/HeroProgressionService.gd")
const GEAR=preload("res://scripts/equipment/EquipmentRules.gd")
const GUARDIANS=preload("res://scripts/heroes/GuardianCatalog.gd")
const _GUARDIAN_PROGRESS=preload("res://scripts/heroes/GuardianProgressionService.gd")
const FORMATIONS=preload("res://scripts/combat/BattleFormation.gd")
const EQUIPMENT_SLOTS=["weapon","armor","accessory"]
const MAX_HERO_LEVEL=100
const MAX_EQUIPMENT_LEVEL=10
var hero_identity_catalog=preload("res://scripts/heroes/HeroIdentityCatalog.gd").new()
var selected_faction="aurelia"
var formation_id="balanced"
var idle_stage=100
var deployed_heroes=[]
var hero_progress={}
var hero_skill_tree={}
var hero_ascension={}
var hero_equipment={}
var hero_equipment_rarity={}
var hero_equipment_names={}
var hero_equipment_sets={}
var hero_equipment_items={}
var guardian_equipped=""
var guardian_collection={}
var long_term_goals={}
func _hero_roster_for_faction(): return HERO_ROSTER.roster(selected_faction)
func _valid_growth_hero(id): return _HERO_PROGRESS.valid_growth_hero(self,id)
func _get_hero_progress(id): return _HERO_PROGRESS.get_hero_progress(self,id)
func _skill_tree_total_points(id): return _HERO_PROGRESS.skill_tree_total_points(self,id)
func _hero_ascension_rank(id): return _HERO_PROGRESS.hero_ascension_rank(self,id)
func _hero_base_grade_index(id): return _HERO_PROGRESS.hero_base_grade_index(self,id)
func _hero_grade(id): return _HERO_PROGRESS.hero_grade(self,id)
func _gear_item(item,id="",slot=""): return preload("res://scripts/equipment/EquipmentCommandService.gd").gear_item(self,item,id,slot)
func payload():
	var ids=[]
	for hero in deployed_heroes:ids.append(hero.id)
	return {"selected_faction":selected_faction,"formation_id":formation_id,"deployed_hero_ids":ids,"hero_progress":hero_progress.duplicate(true),"hero_skill_tree":hero_skill_tree.duplicate(true),"hero_ascension":hero_ascension.duplicate(true),"hero_equipment":hero_equipment.duplicate(true),"hero_equipment_rarity":hero_equipment_rarity.duplicate(true),"hero_equipment_names":hero_equipment_names.duplicate(true),"hero_equipment_sets":hero_equipment_sets.duplicate(true),"hero_equipment_items":hero_equipment_items.duplicate(true),"guardian_equipped":guardian_equipped,"guardian_collection":guardian_collection.duplicate(true),"long_term_goals":long_term_goals.duplicate(true),"future_unknown":{"keep":true}}
"""
	for function in ["_calculate_party_synergy","_hero_skill_profile","_get_skill_tree","_get_hero_equipment","_get_hero_equipment_rarity","_get_hero_equipment_names","_get_hero_equipment_sets","_equipment_set_profile","_equipment_power","_normalize_inventory_item","_item_power","_rarity_multiplier","_equipment_slot_name","_formation_row_for_slot","_hero_attack_range","_guardian_ensure_starter","_pet_profile","_guardian_bonus","_hero_grade_multiplier","_goal_hp_multiplier","_effective_combat_level","_hero_combat_stats"]:
		var start=source.find("func "+function+"(");assert(start>=0);var end=source.find("\nfunc ",start+1)
		adapter+="\n"+source.substr(start,(end if end>=0 else source.length())-start)+"\n"
	var script=GDScript.new();script.source_code=adapter
	if script.reload()!=OK:push_error("Hero stats production adapter failed");quit(1);return
	var cases=[];var guardian_ids=preload("res://scripts/heroes/GuardianCatalog.gd").DEFINITIONS.keys()
	for id in ROSTER.HEROES:
		for variant in range(12):
			var host=script.new();host.selected_faction=str(ROSTER.HEROES[id].faction)
			host.deployed_heroes=ROSTER.roster(host.selected_faction).slice(0,10)
			var exists=false
			for hero in host.deployed_heroes:if hero.id==id:exists=true
			if not exists:host.deployed_heroes[0]=ROSTER.HEROES[id].duplicate(true);host.deployed_heroes[0]["id"]=id
			host.hero_progress[id]={"level":[1,20,60,100][variant%4],"xp":0}
			host.hero_skill_tree[id]={"offense":variant%11,"survival":(variant*3)%11,"utility":(variant*7)%11}
			host.hero_ascension[id]=variant%4;host.formation_id=["balanced","assault","bulwark","volley"][variant%4]
			var equipped={};var levels={};var rarities={};var sets={};var names={}
			for slot in GEAR.SLOTS:
				levels[slot]=1+variant%10;rarities[slot]=GEAR.RARITIES[variant%3];sets[slot]=GEAR.SETS[variant%GEAR.SETS.size()];names[slot]="스탯 검수 장비"
				var options=[{"stat":"attack_pct","value":6},{"stat":"hp_pct","value":8},{"stat":"defense","value":4}] if variant%4!=3 else [{"stat":"haste_pct","value":3},{"stat":"ultimate_pct","value":5},{"stat":"attack_pct","value":6}]
				equipped[slot]=GEAR.normalize({"id":"stats_"+id+"_"+slot,"slot":slot,"level":levels[slot],"rarity":rarities[slot],"name":names[slot],"set":sets[slot],"affixes":options,"bound":true})
			host.hero_equipment[id]=levels;host.hero_equipment_rarity[id]=rarities;host.hero_equipment_sets[id]=sets;host.hero_equipment_names[id]=names;host.hero_equipment_items[id]=equipped
			host.guardian_equipped=guardian_ids[variant%guardian_ids.size()];host.guardian_collection[host.guardian_equipped]={"copies":[1,4,7][variant%3]}
			var discovered={};var count=[0,5,10,15][variant%4]
			for hero in ROSTER.roster(host.selected_faction).slice(0,count):discovered[hero.id]=true
			host.long_term_goals={"factions":{host.selected_faction:{"discovered":discovered,"achievements":{"collection_5":count>=5,"collection_10":count>=10,"collection_15":count>=15}}}}
			host._guardian_ensure_starter();host._get_skill_tree(id)
			for slot in GEAR.SLOTS:host._gear_item("",id,slot)
			var before=host.payload();var synergy=host._calculate_party_synergy();var expected=host._hero_combat_stats(id,variant%10,float(synergy.hp_multiplier))
			cases.append({"hero":id,"slot":variant%10,"before":before,"synergy":synergy,"expected":expected});host.free()
	var file=FileAccess.open("res://Unity/Assets/Game/Editor/Fixtures/hero-stat-fixtures.json",FileAccess.WRITE)
	if file==null:quit(1);return
	file.store_string(JSON.stringify({"source":"Main._hero_combat_stats with production progression, equipment, formation, guardian and collection helpers","cases":cases},"\t"));file.close()
	print("ETERNAL_HERO_STATS_FIXTURES_EXPORTED ",cases.size());quit(0)
