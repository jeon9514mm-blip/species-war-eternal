extends SceneTree

func _initialize() -> void:
	var director = preload("res://scripts/hunting/PartyMovementDirector.gd").new()
	var rows: Array=[]
	for role in ["탱커","딜러","서포터","컨트롤러"]:
		for style in ["balanced","protector","controller","control","aggressive","finisher","sustain","support"]:
			for melee in [false,true]:
				for attack_range in [1,2,3]:
					rows.append({"role":role,"style":style,"melee":melee,"range":attack_range,"expected":director._preferred_standoff(role,style,melee,attack_range)})
	var layout: Array=[]
	var source=FileAccess.get_file_as_string("res://scripts/app/Main.gd")
	var adapter="extends RefCounted\nconst HERO_ROSTER=preload(\"res://scripts/heroes/HeroRosterCatalog.gd\")\n"
	for function in ["_formation_row_for_slot","_hero_attack_range"]:
		var start=source.find("func "+function+"(");assert(start>=0);var end=source.find("\nfunc ",start+1)
		adapter+="\n"+source.substr(start,(end if end>=0 else source.length())-start)+"\n"
	var script=GDScript.new();script.source_code=adapter
	if script.reload()!=OK:quit(1);return
	var host=script.new()
	for id in preload("res://scripts/heroes/HeroRosterCatalog.gd").HEROES:
		var hero=preload("res://scripts/heroes/HeroRosterCatalog.gd").HEROES[id]
		for slot in range(10):
			var row=host._formation_row_for_slot(slot)
			layout.append({"hero":id,"slot":slot,"row":row,"range":host._hero_attack_range(id,str(hero.get("role_group","딜러")),row)})
	var path="res://Unity/Assets/Game/Editor/Fixtures/movement-standoff-fixtures.json"
	var file=FileAccess.open(path,FileAccess.WRITE)
	if file==null:
		push_error("Could not write repository movement fixtures.");quit(1);return
	file.store_string(JSON.stringify({"source":"PartyMovementDirector._preferred_standoff and Main formation/range functions","cases":rows,"layout":layout},"  "))
	file.close()
	print("ETERNAL_MOVEMENT_FIXTURES_EXPORTED ",rows.size())
	quit(0)
