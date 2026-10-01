extends "res://scripts/V83UpgradeTestBase.gd"
const L=preload("res://scripts/RaidContributionLedger.gd")
const A=preload("res://scripts/RaidReportArchive.gd")
func _init() -> void: _run.call_deferred()
func fixture(faction: String) -> Dictionary:
	var roster: Array=ROSTER.roster(faction).slice(0,3);var states: Dictionary={}
	for i in roster.size(): states[roster[i].id]={"slot":i,"hp":100,"max_hp":100}
	var ledger=L.new();ledger.begin(7,roster,states,{"faction":faction,"zone":"gray_meadow"})
	var id: String=roster[0].id
	for pair in [["boss_damage",40],["guard_damage",20],["add_damage",10],["healing_given",8],["shield_given",20],["interrupts",1]]: ledger.add(7,id,pair[0],pair[1])
	ledger.add(7,"$support","boss_damage",15);ledger.add(7,"$unknown","boss_damage",5)
	var result: Dictionary=ledger.finish(7,"victory",10,states);result.stamp="integrity-"+faction
	return result
func _run() -> void:
	for faction: String in ["aurelia","noxfera"]:
		var original: Dictionary=fixture(faction)
		check(not A.clean(original).is_empty(),"producer report accepted")
		check(not A.clean(JSON.parse_string(JSON.stringify(original))).is_empty(),"JSON numeric conversion accepted")
		for kind: String in ["actor_damage","total_damage","channel_total","dps","alive","fraction","nonfinite"]:
			var r: Dictionary=original.duplicate(true)
			match kind:
				"actor_damage": r.actors[0].damage+=1
				"total_damage": r.total_damage+=1
				"channel_total": r.totals.boss_damage+=1
				"dps": r.actors[0].dps+=3.0
				"alive": r.alive=0
				"fraction": r.serial=7.25
				"nonfinite": r.actors[0].dps=INF
			check(A.clean(r).is_empty(),"inconsistent report rejected "+faction+kind)
		var roster: Array=ROSTER.roster(faction).slice(0,1)
		var id: String=roster[0].id;var states: Dictionary={id:{"slot":0,"hp":100,"max_hp":100}}
		var ledger=L.new();ledger.begin(8,roster,states,{"faction":faction,"zone":"gray_meadow"})
		for key: String in ["boss_damage","guard_damage","add_damage"]:ledger.add(8,id,key,L.CAP)
		var huge: Dictionary=ledger.finish(8,"victory",0.01,states);huge.stamp="huge"+faction
		check(huge.total_damage==L.CAP*3 and not A.clean(huge).is_empty(),"all three capped channels form a valid aggregate")
		var path: String="user://integrity-"+faction+".json"
		check(A.append(path,original),"archive initial write")
		check(A.append(path,original) and A.load_reports(path).size()==1,"identical receipt idempotent")
		var conflict: Dictionary=original.duplicate(true);conflict.actors[0].boss_damage+=10;conflict.actors[0].damage+=10;conflict.actors[0].dps+=1;conflict.totals.boss_damage+=10;conflict.total_damage+=10
		var bytes: PackedByteArray=FileAccess.get_file_as_bytes(path)
		check(not A.append(path,conflict) and FileAccess.get_file_as_bytes(path)==bytes,"same stamp with conflicting payload rejected without overwriting")
		var corrupt: Dictionary=original.duplicate(true);corrupt.total_damage+=100
		var f:=FileAccess.open(path,FileAccess.WRITE);f.store_string(JSON.stringify({"version":1,"reports":[corrupt,original]}));f.close()
		var loaded: Array=A.load_reports(path)
		check(loaded.size()==1 and loaded[0].total_damage==90,"invalid record skipped while valid neighbor retained")

		for duration: float in [1.0/30.0,10.0/3.0,PI,1.2345678901234567]:
			var fractional: Dictionary=original.duplicate(true)
			fractional.stamp="fractional-"+faction+str(duration);fractional.elapsed=duration
			for row: Dictionary in fractional.actors: row.dps=float(row.damage)/duration
			var fractional_path: String="user://"+fractional.stamp+".json"
			check(A.append(fractional_path,fractional) and A.append(fractional_path,fractional),"new full-precision float receipt remains idempotent")
			var legacy:=FileAccess.open(fractional_path,FileAccess.WRITE)
			legacy.store_string(JSON.stringify({"version":1,"reports":[fractional]}));legacy.close()
			var legacy_bytes: PackedByteArray=FileAccess.get_file_as_bytes(fractional_path)
			check(A.append(fractional_path,fractional) and FileAccess.get_file_as_bytes(fractional_path)==legacy_bytes,"legacy default-precision receipt accepted without rewrite")
			var wrong_time: Dictionary=fractional.duplicate(true);wrong_time.elapsed*=1.01
			for row: Dictionary in wrong_time.actors: row.dps=float(row.damage)/float(wrong_time.elapsed)
			check(not A.append(fractional_path,wrong_time),"same stamp with materially different elapsed time rejected")
	done("v8361_archive_integrity")
