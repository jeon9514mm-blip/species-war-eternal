extends RefCounted
class_name WorldFrontlineRules
## Adapted SLG staging/recovery, no new map art, offline raids or timers.
const FATIGUE_STEP: int = 20
const WOUND_STEP: float = 0.15
static func rest_quote(world: WorldWarState, march: WorldMarchState, supply: WorldSupplyNetwork, squad: Array) -> Dictionary:
	var result: Dictionary={"ok":false,"reason":"","cost":0,"fatigue_drop":0,"wounds":{},"key":""}
	if world==null or march==null or supply==null:result.reason="월드 상태 없음";return result
	if march.active:result.reason="이미 행군 중";return result
	var pos: Vector2i=world.army_position
	if world.tile_owner(pos)!=world.faction or world.tile_type(pos) not in ["fort","citadel"]:result.reason="보급 연결된 아군 요새·대성에서 정비 가능";return result
	if not supply.is_supply_connected(world,pos,world.faction):result.reason="보급 단절";return result
	var drop: int=mini(FATIGUE_STEP,world.army_fatigue)
	var wounds: Dictionary={};var before: Dictionary={};var restored: float=0.0
	for unit in squad.slice(0,10):
		if not unit is Dictionary:continue
		var id: String=str(unit.get("id",""))
		if id.is_empty() or before.has(id):continue
		var old: float=clampf(float(world.army_wounds.get(id,1.0)),0.0,1.0)
		before[id]=old
		if old<1.0:
			wounds[id]=minf(1.0,old+WOUND_STEP)
			restored+=float(wounds[id])-old
	if before.is_empty():result.reason="편성 필요";return result
	if drop==0 and wounds.is_empty():result.reason="이미 정비 완료";return result
	var cost: int=40+drop*2+int(ceil(restored*100.0-0.000001))
	result.merge({"cost":cost,"fatigue_drop":drop,"wounds":wounds,"restored":restored},true)
	# Resources can regenerate while reading; exact wounds/position/force must not change.
	result.key=JSON.stringify([world.faction,[pos.x,pos.y],world.tile_type(pos),world.army_fatigue,before,squad]).sha256_text()
	if world.rations<cost:result.reason="군량 부족";return result
	result.ok=true
	return result
static func nearby_bases(world: WorldWarState, march: WorldMarchState, supply: WorldSupplyNetwork) -> Array:
	var results: Array=[]
	if world==null or march==null or supply==null or march.active:return results
	var connected: Dictionary=supply.connected_keys(world,world.faction)
	for key in connected:
		var pos: Vector2i=Vector2i(int(str(key).split(":")[0]),int(str(key).split(":")[1]))
		if pos==world.army_position or world.tile_type(pos) not in ["fort","citadel","capital"]:continue
		var plan: Dictionary=march.plan(world,pos)
		if plan.is_empty():continue
		results.append({"target":pos,"kind":world.tile_type(pos),"plan":plan,"affordable":world.rations>=int(plan.ration_cost)})
	results.sort_custom(func(a: Dictionary,b: Dictionary)->bool:
		if a.affordable!=b.affordable:return a.affordable
		return int(a.plan.distance)<int(b.plan.distance) if a.plan.distance!=b.plan.distance else str(a.target)<str(b.target))
	return results.slice(0,4)
static func return_reserve(world: WorldWarState, march: WorldMarchState, target: Vector2i) -> Dictionary:
	if world==null or march==null:return {}
	var plan: Dictionary=march.plan(world,target)
	if plan.is_empty():return {}
	# Reverse of the quoted friendly route after a hypothetical successful capture.
	# It is a reserve to the current origin, not a guaranteed path to the capital.
	var cost: int=int(plan.ration_cost)
	return {"outbound":cost,"return":cost,"remaining":world.rations-cost,"shortfall":maxi(0,2*cost-world.rations),"origin":world.army_position}
