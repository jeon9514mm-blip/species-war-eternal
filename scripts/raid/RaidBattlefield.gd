extends RefCounted
## Shared world coordinates for raid movement, visible warnings and damage.
## v74 adds cone/cross/double-lane footprints so each regional boss can rotate
## patterns without visual and simulation geometry drifting apart.
const FLOOR := Rect2(214.0, 280.0, 610.0, 206.0)
const ENTRY := Vector2(635.0, 397.0)
const BOSS_MIN_Y := 380.0

static func hero_entry(slot: int) -> Vector2:
	return Vector2(340.0 + float(slot % 5) * 48.0, 338.0 + float(slot / 5) * 88.0)

static func spread_destinations(goals: Dictionary, danger: Dictionary = {}, fixed: Dictionary = {}, hero_clearance: float = 80.0, boss_clearance: float = 110.0, metric: Vector2 = Vector2(1,.65), attack_origin: Vector2 = Vector2(INF,INF)) -> Dictionary:
	# Resolve role/rally crowding in simulation coordinates, never visual offsets.
	var result: Dictionary=goals.duplicate()
	var ids: Array=result.keys();ids.sort()
	for iteration in 24:
		for i in ids.size():
			for j in range(i+1,ids.size()):
				var a: Vector2=result[ids[i]];var b: Vector2=result[ids[j]]
				var away:=(a-b)*metric;var distance:=away.length()
				var clearance:=boss_clearance if fixed.has(ids[i]) or fixed.has(ids[j]) else hero_clearance
				if distance>=clearance:continue
				if distance<.01:away=Vector2.from_angle(float(absi((str(ids[i])+str(ids[j])).hash())%6283)/1000.0)
				else:away/=distance
				var shift:=away*(clearance-distance)/metric
				if not fixed.has(ids[i]) and not fixed.has(ids[j]):shift*=.5
				var left:=clamp_to_floor(a+shift);var right:=clamp_to_floor(b-shift)
				# A floor boundary must not swallow half the separation impulse.
				# Give the remaining motion to the free neighbor, retaining warnings.
				if not fixed.has(ids[i]) and not fixed.has(ids[j]):
					right=clamp_to_floor(right-((a+shift)-left))
					left=clamp_to_floor(left-((b-shift)-clamp_to_floor(b-shift)))
				for pair in [[ids[i],a,left],[ids[j],b,right]]:
					if fixed.has(pair[0]):continue
					var candidate:=clamp_to_floor(pair[2])
					# A chosen safe escape must stay outside the damage footprint.
					if _attack_candidate(candidate,pair[1],attack_origin) and (danger.is_empty() or contains(danger,pair[1]) or not contains(danger,candidate)):result[pair[0]]=candidate
	# Resolve rare boundary jams by finding the nearest clear floor spot. This
	# supplies a walking goal. Only initial staging applies these points directly.
	for id in ids:
		if fixed.has(id):continue
		var current: Vector2=result[id];var crowded:=false
		for other in ids:
			if other==id:continue
			var required:=boss_clearance if fixed.has(other) else hero_clearance
			if ((current-Vector2(result[other]))*metric).length()<required-.05:crowded=true;break
		if not crowded:continue
		var found:=false
		for radius in [12.0,24.0,40.0,60.0,80.0,110.0,150.0,220.0,280.0,360.0]:
			for angle in 24:
				var candidate:=clamp_to_floor(current+Vector2.from_angle(TAU*float(angle)/24.0)*radius)
				if not _attack_candidate(candidate,current,attack_origin):continue
				if not danger.is_empty() and not contains(danger,current) and contains(danger,candidate):continue
				var clear:=true
				for other in ids:
					if other==id:continue
					var required:=boss_clearance if fixed.has(other) else hero_clearance
					if ((candidate-Vector2(result[other]))*metric).length()<required-.05:clear=false;break
				if clear:result[id]=candidate;found=true;break
			if found:break
	return result

static func _attack_candidate(candidate: Vector2, current: Vector2, origin: Vector2) -> bool:
	if not is_finite(origin.x):return true
	var distance:=candidate.distance_to(origin)
	# Automatic formation stays within the existing 335px attack range. A hero
	# returning from an explicit retreat can approach it without teleporting.
	return distance<=330.0 or (current.distance_to(origin)>330.0 and distance<current.distance_to(origin))

static func advance_positions(positions: Dictionary, goals: Dictionary, speeds: Dictionary, boss_position: Vector2, delta: float, danger: Dictionary = {}, hero_clearance: float = 80.0, boss_clearance: float = 110.0, metric: Vector2 = Vector2(1,.65), attack_origin: Vector2 = Vector2(INF,INF)) -> void:
	# A separated destination may be hundreds of pixels away. It is a walking
	# goal, never permission to apply the destination solver to live feet.
	if delta<=0.0 or not is_finite(delta):return
	var actual: Dictionary={}
	var budgets: Dictionary={}
	var center:=Vector2.ZERO;var goal_center:=Vector2.ZERO
	for id in goals:
		var speed: float=maxf(0.0,float(speeds.get(id,0.0)))
		budgets[id]=delta*speed if is_finite(speed) else 0.0
		actual[id]=positions[id];center+=Vector2(positions[id]);goal_center+=Vector2(goals[id])
	actual['@boss']=boss_position
	var ids: Array=goals.keys();ids.sort()
	# The leading member reserves its step first; following members may enter
	# that vacated space instead of freezing a tight parallel formation.
	var travel: Vector2=(goal_center-center).normalized()
	if travel.length_squared()>.01:
		ids.sort_custom(func(a: String,b: String) -> bool:
			var order: float=(Vector2(positions[a])-Vector2(positions[b])).dot(travel)
			return a<b if absf(order)<.001 else order>0.0)
	for id in ids:
		var current: Vector2=positions[id]
		var budget: float=budgets[id]
		if budget<=0.0:continue
		actual[id]=_walk_candidate(id,current,Vector2(goals[id]),budget,actual,danger,hero_clearance,boss_clearance,metric,attack_origin,positions)
	for id in ids:positions[id]=actual[id]

static func _swept_clear(id: String,current: Vector2,candidate: Vector2,neighbors: Dictionary,before: Dictionary,hero_clearance: float,boss_clearance: float,metric: Vector2) -> bool:
	# Check the full relative-motion segment against previously reserved steps.
	# Later members repeat this check when reserving their own movement.
	for other in neighbors:
		if other==id:continue
		var other_before: Vector2=before.get(other,neighbors[other])
		var start: Vector2=(current-other_before)*metric
		var velocity: Vector2=((candidate-current)-(Vector2(neighbors[other])-other_before))*metric
		var nearest:=clampf(-start.dot(velocity)/velocity.length_squared(),0.0,1.0) if velocity.length_squared()>.000001 else 0.0
		var required: float=(boss_clearance if other=='@boss' else hero_clearance)-.10
		var minimum: float=minf(required,start.length())-.001
		if (start+velocity*nearest).length()<minimum:return false
	return true

static func stage_positions(positions: Dictionary,boss_position: Vector2,hero_clearance: float,boss_clearance: float,metric: Vector2) -> void:
	# Called once under the entry curtain, before any live walking is shown.
	var staging: Dictionary=positions.duplicate();staging['@boss']=boss_position
	for id in positions:
		var offset: Vector2=Vector2(staging[id])-boss_position
		if offset.length()>330.0:staging[id]=clamp_to_floor(boss_position+offset.normalized()*330.0)
	staging=spread_destinations(staging,{}, {'@boss':true},hero_clearance,boss_clearance,metric,boss_position)
	for id in positions:positions[id]=staging[id]

static func _walk_candidate(id: String,current: Vector2,goal: Vector2,budget: float,neighbors: Dictionary,danger: Dictionary,hero_clearance: float,boss_clearance: float,metric: Vector2,attack_origin: Vector2,before: Dictionary) -> Vector2:
	var direction:=goal-current
	var penetration:=_penetration(id,current,neighbors,hero_clearance,boss_clearance,metric)
	if direction.length_squared()<.0001 and penetration<=.001:return current
	if direction.length_squared()<.0001:direction=current-Vector2(neighbors['@boss'])
	if direction.length_squared()<.0001:direction=Vector2.LEFT
	var travel:=minf(budget,maxf(direction.length(),.1));direction=direction.normalized()
	var best:=current;var best_score:=INF;var best_penetration:=penetration
	var found:=false
	# Local yield/slide samples keep crossings continuous and deterministic.
	# Use one clockwise preference: opposing actors choose opposite physical
	# sides, while a formation traveling together keeps a consistent flow.
	for angle: float in [0.0,.35,-.35,.7,-.7,1.05,-1.05,PI*.5,-PI*.5]:
		for fraction: float in [1.0,.5,.25]:
			var candidate:=clamp_to_floor(current+direction.rotated(angle)*travel*fraction)
			if not _attack_candidate(candidate,current,attack_origin):continue
			if not danger.is_empty() and not contains(danger,current) and contains(danger,candidate):continue
			if not _swept_clear(id,current,candidate,neighbors,before,hero_clearance,boss_clearance,metric):continue
			var candidate_penetration:=_penetration(id,candidate,neighbors,hero_clearance,boss_clearance,metric)
			# Once direct walking is blocked, commit to a real side step. Merely
			# minimizing distance picks tiny tangent steps and traps opposing heroes
			# in a contact equilibrium instead of letting either pass.
			var score:=candidate.distance_squared_to(goal)-candidate.distance_squared_to(current)*4.0+absf(angle)*.001
			if candidate_penetration<=.001:
				if angle==0.0 and fraction==1.0:return candidate
				if score<best_score:best=candidate;best_score=score;found=true
			elif not found and candidate_penetration<best_penetration-.0001:
				best=candidate;best_penetration=candidate_penetration
	return best

static func _penetration(id: String,point: Vector2,neighbors: Dictionary,hero_clearance: float,boss_clearance: float,metric: Vector2) -> float:
	var total:=0.0
	for other in neighbors:
		if other==id:continue
		var required:=boss_clearance if other=='@boss' else hero_clearance
		var overlap:=maxf(0.0,required-.05-((point-Vector2(neighbors[other]))*metric).length())
		total+=overlap*overlap
	return total

static func clamp_to_floor(point: Vector2) -> Vector2:
	return Vector2(clampf(point.x, FLOOR.position.x + 12.0, FLOOR.end.x - 12.0), clampf(point.y, FLOOR.position.y + 10.0, FLOOR.end.y - 10.0))

static func clamp_boss_to_floor(point: Vector2) -> Vector2:
	var result:=clamp_to_floor(point);result.y=maxf(BOSS_MIN_Y,result.y);return result

static func footprint(kind: String, origin: Vector2, marks: Array[Vector2], profile: Dictionary = {}) -> Dictionary:
	var center := marks[0] if not marks.is_empty() else origin - Vector2(150.0, 0.0)
	match kind:
		"front_blast", "rear_blast":
			var width := float(profile.get('width',142.0))
			return {"shape":"lane", "rect":Rect2(center.x - width * 0.5, FLOOR.position.y, width, FLOOR.size.y)}
		"double_lane":
			var width := float(profile.get('width',76.0))
			var gap := float(profile.get('gap',108.0))
			return {"shape":"rects", "rects":[Rect2(center.x-gap-width*.5,FLOOR.position.y,width,FLOOR.size.y),Rect2(center.x+gap-width*.5,FLOOR.position.y,width,FLOOR.size.y)]}
		"cross":
			var width := float(profile.get('width',80.0))
			return {"shape":"rects", "rects":[Rect2(center.x-width*.5,FLOOR.position.y,width,FLOOR.size.y),Rect2(FLOOR.position.x,center.y-width*.5,FLOOR.size.x,width)]}
		"cone":
			var direction := (center-origin).normalized()
			if direction.length_squared() < 0.01: direction=Vector2.LEFT
			return {"shape":"cone", "origin":origin, "direction":direction, "radius":float(profile.get('radius',290.0)), "half_angle":float(profile.get('half_angle',0.58))}
		"moon_mark":
			return {"shape":"marks", "centers":marks.duplicate(), "radius":float(profile.get('radius',54.0))}
		"earthquake":
			return {"shape":"ring", "center":origin, "inner":float(profile.get('inner',102.0)), "outer":float(profile.get('outer',230.0))}
		"curse":
			return {"shape":"circle", "center":origin, "radius":float(profile.get('radius',310.0))}
		_:
			return {"shape":"circle", "center":origin, "radius":float(profile.get('radius',260.0))}

static func contains(shape: Dictionary, point: Vector2) -> bool:
	match str(shape.get("shape", "")):
		"lane": return (shape["rect"] as Rect2).has_point(point)
		"rects":
			for rect_value in shape.get('rects',[]):
				if (rect_value as Rect2).has_point(point): return true
		"marks":
			for center: Vector2 in shape["centers"]:
				if point.distance_to(center) <= float(shape["radius"]): return true
		"ring":
			var distance := point.distance_to(shape["center"])
			return distance >= float(shape["inner"]) and distance <= float(shape["outer"])
		"circle": return point.distance_to(shape["center"]) <= float(shape["radius"])
		"cone":
			var offset: Vector2=point-(shape['origin'] as Vector2)
			if offset.length() > float(shape['radius']): return false
			if offset.length_squared() < 1.0: return true
			return absf((shape['direction'] as Vector2).angle_to(offset.normalized())) <= float(shape['half_angle'])
	return false

static func escape_position(shape: Dictionary, point: Vector2) -> Vector2:
	if not contains(shape, point): return point
	var best := point
	var shortest := INF
	for distance in [66.0, 116.0, 174.0, 236.0, 300.0]:
		for index in 16:
			var option := clamp_to_floor(point + Vector2.RIGHT.rotated(TAU * float(index) / 16.0) * distance)
			if not contains(shape, option) and point.distance_squared_to(option) < shortest:
				shortest = point.distance_squared_to(option)
				best = option
	# Large late-raid circles can leave only edge/corner safe space. Add explicit
	# arena anchors so the helper never misses a valid escape just because a
	# radial sample did not land on the narrow safe pocket.
	var anchors := [
		Vector2(FLOOR.position.x+12.0,FLOOR.position.y+10.0),
		Vector2(FLOOR.end.x-12.0,FLOOR.position.y+10.0),
		Vector2(FLOOR.position.x+12.0,FLOOR.end.y-10.0),
		Vector2(FLOOR.end.x-12.0,FLOOR.end.y-10.0),
		Vector2(FLOOR.position.x+12.0,FLOOR.get_center().y),
		Vector2(FLOOR.end.x-12.0,FLOOR.get_center().y),
	]
	for option: Vector2 in anchors:
		if not contains(shape,option) and point.distance_squared_to(option)<shortest:
			shortest=point.distance_squared_to(option);best=option
	return best
