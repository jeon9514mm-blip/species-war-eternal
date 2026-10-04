extends SceneTree
const HOST=preload("res://tools/EconomySimulationHost.gd")
var checks:=0
var failures: Array[String]=[]
var rows: Array[Dictionary]=[]
func _init() -> void:run.call_deferred()
func check(ok: bool,note: String) -> void:
	checks+=1
	if not ok:failures.append(note);push_error(note)
func run() -> void:
	for faction: String in ["aurelia","noxfera"]:
		for zone_id: String in ["gray_meadow","forgotten_mine","moonrest_forest"]:
			for fixture_seed in [3401,3402,3403]:
				var main=HOST.new();root.add_child(main);main.boot(faction,fixture_seed)
				main.gear_auto_equip=false
				var zone: Dictionary=main._zone_data()[zone_id]
				var rarities: Dictionary={"없음":0,"일반":0,"희귀":0,"전설":0};var slots: Dictionary={};var roles: Dictionary={}
				for roll in 1000:
					var item: Dictionary=main._roll_equipment_drop(zone)
					if item.is_empty():rarities["없음"]+=1
					else:
						rarities[str(item.rarity)]+=1;slots[str(item.slot)]=int(slots.get(str(item.slot),0))+1
						roles[str(item.hunt_role)]=int(roles.get(str(item.hunt_role),0))+1
					main.loot_inventory.clear();main.equipment_overflow.clear()
				var difficulty: int=int(zone.difficulty)
				var legendary: float=.03+difficulty*.01;var rare: float=.12+difficulty*.01
				check(absf(float(rarities["전설"])/1000.0-legendary)<.035,"legendary frequency in seeded tolerance")
				check(absf(float(rarities["희귀"])/1000.0-rare)<.045,"rare frequency in seeded tolerance")
				check(slots.size()==3 and roles.size()==main.GEAR.HUNT_ROLES.size(),"all slots and roles can drop in each region/faction")
				check(int(rarities["없음"])+int(rarities["일반"])+int(rarities["희귀"])+int(rarities["전설"])==1000,"each roll has exactly one outcome")
				rows.append({"faction":faction,"zone":zone_id,"seed":fixture_seed,"rolls":1000,"rarities":rarities,"slots":slots,"roles":roles,"guardian_drop_bonus":main._guardian_bonus("item_drop")})
				main.free();await process_frame
	var report: Dictionary={"rolls":18000,"checks":checks,"failures":failures,"rows":rows}
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="):FileAccess.open(argument.trim_prefix("--report="),FileAccess.WRITE).store_string(JSON.stringify(report,"  ")+"\n")
	print("LOOT_ECONOMY_AUDIT checks=%d failures=%s"%[checks,JSON.stringify(failures)])
	quit(0 if failures.is_empty() else 1)
