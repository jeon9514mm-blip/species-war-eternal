extends SceneTree
## Independent oracle: these expectations execute original production functions.
func _initialize() -> void:
	var data := {"schema":1,"skills":[],"growth":[]}
	var catalog=preload("res://scripts/heroes/HeroRosterCatalog.gd")
	var rules=preload("res://scripts/heroes/HeroCombatRules.gd")
	for id in catalog.HEROES:
		for slot in ["passive","a1","a2","ultimate"]:
			var p: Dictionary=catalog.skill(id,slot)
			for hp in [0,100,350,1000]:
				data.skills.append({"id":id,"slot":slot,"hp":hp,
					"damage":rules.hit_damage(p,200,{"hp":hp,"max_hp":1000,"elite":true}),
					"heal":rules.heal_amount(p,{"hp":hp,"max_hp":1000}),
					"lifesteal":rules.lifesteal_amount(p,{"hp":hp,"max_hp":1000},137)})
	var economy=preload("res://scripts/progression/GrowthEconomyRules.gd")
	for level in [1,2,20,21,50,100]:
		data.growth.append({"level":level,"xp_cost":economy.xp_cost(level,100)})
	for stage in [1,25,26,100,10000]:
		var reward: Dictionary=economy.stage_chest(stage)
		reward["stage"]=stage; data.growth.append(reward)
	var path="res://Unity/Assets/Game/Resources/Eternal/rule-fixtures.json"
	var file=FileAccess.open(path,FileAccess.WRITE)
	if file==null:quit(1);return
	file.store_string(JSON.stringify(data,"  "));file.close()
	print("UNITY_ORIGINAL_RULE_FIXTURES_OK: ",data.skills.size()," skill cases")
	quit(0)
