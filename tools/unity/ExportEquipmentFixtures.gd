extends SceneTree
const GEAR=preload("res://scripts/equipment/EquipmentRules.gd")
const COMMANDS=preload("res://scripts/equipment/EquipmentCommandService.gd")
func _initialize():
	var cases=[]
	var number=0
	for slot in GEAR.SLOTS:
		for rarity in GEAR.RARITIES:
			for level in [0,1,4,10,99]:
				var raw={"id":"fixture_%d"%number,"slot":slot,"rarity":rarity,"level":level,"origin":"hunt","set":"月の不正セット","affixes":[{"stat":"attack_pct","value":99},{"stat":"attack_pct","value":2},{"stat":"hp_pct","value":5},{"stat":"defense","value":3}]}
				cases.append({"type":"normalize","raw":raw,"expected":GEAR.normalize(raw)});number+=1
	for family in GEAR.FAMILIES:
		var raw={"id":"proposal_"+family,"rarity":"전설","affixes":[{"stat":"defense","value":2}],"proposal":{"family":family,"options":[{"stat":"attack_pct","value":6},{"stat":"hp_pct","value":8},{"stat":"haste_pct","value":3},{"stat":"ultimate_pct","value":5}]}}
		cases.append({"type":"normalize","raw":raw,"expected":GEAR.normalize(raw)})
	for value in [1,3,8,99]:
		var raw={"id":"crystal_%d"%value,"item_type":"option_crystal","stored_option":{"stat":"hp_pct","value":value,"trade_count":1}}
		cases.append({"type":"normalize","raw":raw,"expected":GEAR.normalize(raw)})
	for raw in [{"id":"bad-slot","slot":"boots"},{"id":"bad-type","item_type":"coin"},{"id":"invalid-crystal","item_type":"option_crystal"},{"id":"bool-level","level":true,"locked":"true","bound":false}]:
		cases.append({"type":"normalize","raw":raw,"expected":GEAR.normalize(raw)})
	for weapon in GEAR.SETS:
		for armor in GEAR.SETS:
			for accessory in GEAR.SETS:
				var sets={"weapon":weapon,"armor":armor,"accessory":accessory}
				cases.append({"type":"sets","raw":sets,"expected":GEAR.set_profile(sets)})
	var text=FileAccess.get_file_as_string("res://scripts/app/Main.gd")
	var adapter="""extends Node
const GEAR=preload("res://scripts/equipment/EquipmentRules.gd")
const EQUIPMENT_SLOTS=["weapon","armor","accessory"]
const MAX_EQUIPMENT_LEVEL=10
var selected_faction="aurelia"
var _save_blocked_for_newer_version=false
var wallet_gold=10000
var loot_inventory=[]
var hero_equipment={}
var hero_equipment_rarity={}
var hero_equipment_names={}
var hero_equipment_sets={}
var hero_equipment_items={}
func _valid_growth_hero(id): return str(preload("res://scripts/heroes/HeroRosterCatalog.gd").hero(id).get("faction",""))==selected_faction
func _hero_role_group(id): return str(preload("res://scripts/heroes/HeroRosterCatalog.gd").hero(id).get("role_group",""))
func _hero_short_name(id): return id
func _gear_role_matches(item,id): return preload("res://scripts/equipment/EquipmentCommandService.gd").gear_role_matches(self,item,id)
func _gear_inventory_index(id): return preload("res://scripts/equipment/EquipmentCommandService.gd").gear_inventory_index(self,id)
func _gear_item(item,id="",slot=""): return preload("res://scripts/equipment/EquipmentCommandService.gd").gear_item(self,item,id,slot)
func _gear_update_item(item,id="",slot=""): return preload("res://scripts/equipment/EquipmentCommandService.gd").gear_update_item(self,item,id,slot)
func _equip_item_direct(index,id): return preload("res://scripts/equipment/EquipmentCommandService.gd").equip_item_direct(self,index,id)
func _refresh_growth_runtime(): pass
func _update_equipment_card(_id): pass
func _record_first_session_action(_action): pass
func _save_idle_state(): pass
func _presentation_event(_event): pass
func payload():
	return {"selected_faction":selected_faction,"wallet_gold":wallet_gold,"loot_inventory":loot_inventory.duplicate(true),"hero_equipment":hero_equipment.duplicate(true),"hero_equipment_rarity":hero_equipment_rarity.duplicate(true),"hero_equipment_names":hero_equipment_names.duplicate(true),"hero_equipment_sets":hero_equipment_sets.duplicate(true),"hero_equipment_items":hero_equipment_items.duplicate(true),"future_unknown":{"keep":true}}
"""
	for function in ["_get_hero_equipment","_get_hero_equipment_rarity","_get_hero_equipment_names","_get_hero_equipment_sets","_equipment_slot_name","_rarity_multiplier","_rarity_rank","_equipment_power","_item_power","_equipment_upgrade_cost","_inventory_upgrade_cost","_inventory_salvage_value","_normalize_inventory_item","_inventory_action_valid"]:
		var start=text.find("func "+function+"(");assert(start>=0);var end=text.find("\nfunc ",start+1)
		adapter+="\n"+text.substr(start,(end if end>=0 else text.length())-start)+"\n"
	var script=GDScript.new();script.source_code=adapter
	if script.reload()!=OK:push_error("Equipment production adapter failed");quit(1);return
	for command in ["equip","enhance","decompose"]:
		for level in [1,9,10]:
			for rarity in GEAR.RARITIES:
				for role in ["","dealer","defender","support"]:
					var host=script.new()
					for slot in GEAR.SLOTS:host._gear_item("","leonhardt",slot)
					var raw={"id":"command-fixture","slot":"weapon","level":level,"rarity":rarity,"origin":"hunt","set":"개척자","hunt_role":role}
					host.loot_inventory.append(GEAR.normalize(raw))
					var before=host.payload();var result={}
					if command=="equip":result=COMMANDS.gear_equip_item(host,"command-fixture","leonhardt")
					elif command=="enhance":result=COMMANDS.gear_enhance_item(host,"command-fixture")
					else:result=COMMANDS.gear_decompose_item(host,"command-fixture",true)
					cases.append({"type":"command","command":command,"item":"command-fixture","hero":"leonhardt","before":before,"after":host.payload(),"ok":result.get("ok",false)});host.free()
	for slot in GEAR.SLOTS:
		for gold in [0,10000]:
			var host=script.new();host.wallet_gold=gold
			for s in GEAR.SLOTS:host._gear_item("","leonhardt",s)
			var item=host._gear_item("","leonhardt",slot);var before=host.payload()
			var result=COMMANDS.gear_enhance_item(host,item.id,"leonhardt",slot)
			cases.append({"type":"command","command":"enhance_equipped","item":item.id,"hero":"leonhardt","slot":slot,"before":before,"after":host.payload(),"ok":result.get("ok",false)});host.free()
	var report={"sources":["scripts/equipment/EquipmentRules.gd","scripts/equipment/EquipmentCommandService.gd","scripts/app/Main.gd selected equipment functions"],"cases":cases,"note":"Isolated production adapter, no Main scene or player saves."}
	var output=FileAccess.open("res://Unity/Assets/Game/Editor/Fixtures/equipment-rule-fixtures.json",FileAccess.WRITE);output.store_string(JSON.stringify(report,"\t"));output.close()
	print("ETERNAL_EQUIPMENT_ORACLE_OK ",cases.size()," cases");quit()
