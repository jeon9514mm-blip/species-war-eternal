extends SceneTree
const ROSTER=preload("res://scripts/heroes/HeroRosterCatalog.gd")
const GEAR=preload("res://scripts/equipment/EquipmentRules.gd")
const COMMANDS=preload("res://scripts/equipment/EquipmentCommandService.gd")

func _initialize():
	var main=FileAccess.get_file_as_string("res://scripts/app/Main.gd")
	var adapter="""extends Node
const HERO_ROSTER=preload("res://scripts/heroes/HeroRosterCatalog.gd")
const PROGRESS=preload("res://scripts/heroes/HeroProgressionService.gd")
const COMMANDS=preload("res://scripts/equipment/EquipmentCommandService.gd")
const GEAR=preload("res://scripts/equipment/EquipmentRules.gd")
const EQUIPMENT_SLOTS=["weapon","armor","accessory"]
const MAX_EQUIPMENT_LEVEL=10
const MAX_HERO_LEVEL=100
var selected_faction="aurelia"
var _save_blocked_for_newer_version=false
var wallet_gold=10000
var loot_inventory=[]
var hero_equipment={}
var hero_equipment_rarity={}
var hero_equipment_names={}
var hero_equipment_sets={}
var hero_equipment_items={}
var hero_progress={}
var hero_skill_tree={}
var hero_breakthrough={}
var deployed_heroes=[]
var active_screen="combat"
var save_count=0
func _valid_growth_hero(id): return PROGRESS.valid_growth_hero(self,id)
func _get_hero_progress(id): return PROGRESS.get_hero_progress(self,id)
func _get_skill_tree(id): return PROGRESS.get_skill_tree(self,id)
func _skill_tree_total_points(id): return PROGRESS.skill_tree_total_points(self,id)
func _skill_tree_spent(id): return PROGRESS.skill_tree_spent(self,id)
func _hero_breakthrough_rank(id): return PROGRESS.hero_breakthrough_rank(self,id)
func _hero_roster_for_faction(): return HERO_ROSTER.roster(selected_faction)
func _hero_role_group(id): return str(HERO_ROSTER.hero(id).get("role_group",""))
func _hero_short_name(id): return id
func _gear_role_matches(item,id): return COMMANDS.gear_role_matches(self,item,id)
func _gear_inventory_index(id): return COMMANDS.gear_inventory_index(self,id)
func _gear_item(item,id="",slot=""): return COMMANDS.gear_item(self,item,id,slot)
func _gear_update_item(item,id="",slot=""): return COMMANDS.gear_update_item(self,item,id,slot)
func _equip_item_direct(index,id): return COMMANDS.equip_item_direct(self,index,id)
func _equipped_slot_power(id,slot): return COMMANDS.equipped_slot_power(self,id,slot)
func _automatic_equipment_gain(item,id): return COMMANDS.automatic_equipment_gain(self,item,id)
func _best_auto_equipment_target(item,roster): return COMMANDS.best_auto_equipment_target(self,item,roster)
func _refresh_growth_runtime(): pass
func _update_equipment_card(_id): pass
func _save_idle_state(): save_count+=1
func _show_toast(_text): pass
func _update_reward_labels(): pass
func _build_inventory_screen(): pass
func payload():
	var ids=[]
	for hero in deployed_heroes:ids.append(hero.id)
	return {"selected_faction":selected_faction,"deployed_hero_ids":ids,"wallet_gold":wallet_gold,"loot_inventory":loot_inventory.duplicate(true),"hero_equipment":hero_equipment.duplicate(true),"hero_equipment_rarity":hero_equipment_rarity.duplicate(true),"hero_equipment_names":hero_equipment_names.duplicate(true),"hero_equipment_sets":hero_equipment_sets.duplicate(true),"hero_equipment_items":hero_equipment_items.duplicate(true),"hero_progress":hero_progress.duplicate(true),"hero_skill_tree":hero_skill_tree.duplicate(true),"hero_breakthrough":hero_breakthrough.duplicate(true),"future_unknown":{"keep":true}}
"""
	for function in ["_get_hero_equipment","_get_hero_equipment_rarity","_get_hero_equipment_names","_get_hero_equipment_sets","_equipment_slot_name","_rarity_multiplier","_equipment_power","_item_power","_normalize_inventory_item","_equipment_set_profile","_inventory_action_valid"]:
		var start=main.find("func "+function+"(");assert(start>=0);var end=main.find("\nfunc ",start+1)
		adapter+="\n"+main.substr(start,(end if end>=0 else main.length())-start)+"\n"
	var script=GDScript.new();script.source_code=adapter
	if script.reload()!=OK:push_error("Auto equipment production adapter failed");quit(1);return
	var cases=[]
	for id in ROSTER.HEROES:
		for slot in GEAR.SLOTS:
			for variant in range(8):
				var host=script.new();host.selected_faction=str(ROSTER.HEROES[id].faction);host.deployed_heroes=[ROSTER.hero(id)]
				prepare(host,id,variant)
				var raw={"id":"gain_fixture","slot":slot,"level":8,"rarity":"전설","set":"월광","origin":"hunt","hunt_role":["","dealer","defender","support"][variant%4]}
				if variant==4:raw.locked=true
				if variant==5:raw.origin="raid"
				if variant==6:raw.affixes=[{"stat":"attack_pct","value":5}]
				if variant==7:raw.proposal={"family":"assault","options":[{"stat":"attack_pct","value":4}]}
				var item=GEAR.normalize(raw);var before=host.payload();var gain=COMMANDS.automatic_equipment_gain(host,item,id)
				cases.append({"type":"gain","hero":id,"item":item,"before":before,"gain":gain});host.free()
	for faction in ["aurelia","noxfera"]:
		for variant in range(12):
			var host=script.new();host.selected_faction=faction;host.deployed_heroes=ROSTER.roster(faction).slice(0,10)
			for hero in host.deployed_heroes:prepare(host,hero.id,variant)
			for index in range(15):
				var raw={"id":"auto_%d"%index,"slot":GEAR.SLOTS[index%3],"level":1+(index+variant)%10,"rarity":GEAR.RARITIES[index%3],"set":GEAR.SETS[(index+variant)%GEAR.SETS.size()],"origin":"hunt","hunt_role":["","dealer","defender","support"][index%4]}
				if index==11:raw.locked=true
				if index==12:raw.origin="raid"
				if index==13:raw.affixes=[{"stat":"hp_pct","value":8}]
				if index==14:raw= {"id":"option_fixture","item_type":"option_crystal","stored_option":{"stat":"attack_pct","value":6}}
				host.loot_inventory.append(GEAR.normalize(raw))
			var before=host.payload();var targets=[]
			for item in host.loot_inventory:targets.append(COMMANDS.best_auto_equipment_target(host,item,host.deployed_heroes))
			# Query helpers normalize already prepared records but never save.
			COMMANDS.recommend_equip_all(host)
			cases.append({"type":"recommend","before":before,"targets":targets,"after":host.payload(),"save_count":host.save_count});host.free()
	var file=FileAccess.open("res://Unity/Assets/Game/Editor/Fixtures/auto-equipment-fixtures.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"source":"EquipmentCommandService automatic gain, best target and full recommend passes with production progression/set helpers","cases":cases},"\t"));file.close()
	print("ETERNAL_AUTO_EQUIPMENT_ORACLE_OK ",cases.size());quit()

func prepare(host,id,variant):
	host.hero_progress[id]={"level":[1,20,60,100][variant%4],"xp":0}
	host.hero_skill_tree[id]={"offense":variant%5,"survival":variant%3,"utility":variant%2};host.hero_breakthrough[id]=variant%6
	host.hero_equipment[id]={"weapon":1+variant%4,"armor":1+variant%4,"accessory":1+variant%4}
	host.hero_equipment_sets[id]={"weapon":GEAR.SETS[variant%GEAR.SETS.size()],"armor":GEAR.SETS[variant%GEAR.SETS.size()],"accessory":GEAR.SETS[variant%GEAR.SETS.size()]}
	host._get_hero_progress(id);host._get_skill_tree(id)
	for slot in GEAR.SLOTS:host._gear_item("",id,slot)
