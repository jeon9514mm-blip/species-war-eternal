extends "res://scripts/V83UpgradeTestBase.gd"
const F=preload("res://scripts/WorldFrontlineRules.gd")
func _init() -> void: _run.call_deferred()
func _run() -> void:
	var w:=WorldWarState.new();var m:=WorldMarchState.new();var s:=WorldSupplyNetwork.new()
	for mask in range(7):
		var world: WorldWarState=w if mask&1 else null
		var march: WorldMarchState=m if mask&2 else null
		var supply: WorldSupplyNetwork=s if mask&4 else null
		var before: Dictionary=w.export_state().duplicate(true)
		var bases: Variant=F.nearby_bases(world,march,supply)
		check(bases is Array and bases.is_empty(),"missing dependency safely returns empty candidates mask="+str(mask))
		check(w.export_state()==before,"missing dependencies do not mutate world")
		var quote: Dictionary=F.rest_quote(world,march,supply,[])
		check(not quote.ok and quote.cost==0,"missing dependency cannot charge rest cost")
	for mask in range(3):
		var world: WorldWarState=w if mask&1 else null
		var march: WorldMarchState=m if mask&2 else null
		var reserve: Variant=F.return_reserve(world,march,Vector2i.ZERO)
		check(reserve is Dictionary and reserve.is_empty(),"missing reserve dependency returns empty quote mask="+str(mask))
	m.active=true
	check(F.nearby_bases(w,m,s).is_empty(),"in-transit army cannot select staging base")
	done("v8361_frontline_null")
