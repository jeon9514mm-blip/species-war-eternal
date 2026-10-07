extends RefCounted
## Shared world coordinates for raid movement, visible warnings and damage.
## v74 adds cone/cross/double-lane footprints so each regional boss can rotate
## patterns without visual and simulation geometry drifting apart.
const FLOOR := Rect2(214.0, 280.0, 610.0, 206.0)
const ENTRY := Vector2(635.0, 397.0)

static func hero_entry(slot: int) -> Vector2:
	return Vector2(330.0 + float(slot % 5) * 52.0, 330.0 + float(slot / 5) * 104.0)

static func spread_destinations(goals: Dictionary, danger: Dictionary = {}, fixed: Dictionary = {}) -> Dictionary:
	# Resolve role/rally crowding in simulation coordinates, never visual offsets.
	var result: Dictionary=goals.duplicate()
	var ids: Array=result.keys();ids.sort()
	for iteration in 24:
		for i in ids.size():
			for j in range(i+1,ids.size()):
				var a: Vector2=result[ids[i]];var b: Vector2=result[ids[j]]
				var away:=(a-b)*Vector2(1,.65);var distance:=away.length()
				var clearance:=110.0 if fixed.has(ids[i]) or fixed.has(ids[j]) else 85.0
				if distance>=clearance:continue
				if distance<.01:away=Vector2.from_angle(float(absi((str(ids[i])+str(ids[j])).hash())%6283)/1000.0)
				else:away/=distance
				var shift:=away*(clearance-distance)/Vector2(1,.65)
				if not fixed.has(ids[i]) and not fixed.has(ids[j]):shift*=.5
				for pair in [[ids[i],a,a+shift],[ids[j],b,b-shift]]:
					if fixed.has(pair[0]):continue
					var candidate:=clamp_to_floor(pair[2])
					# A chosen safe escape must stay outside the damage footprint.
					if danger.is_empty() or contains(danger,pair[1]) or not contains(danger,candidate):result[pair[0]]=candidate
	return result

static func advance_positions(positions: Dictionary, goals: Dictionary, speeds: Dictionary, boss_position: Vector2, delta: float, danger: Dictionary = {}) -> void:
	# Paths to separated goals can cross. Resolve the actual feet too, with
	# the boss fixed and safe escape positions outside active warnings.
	var actual: Dictionary={}
	for id in goals:
		var current: Vector2=positions[id]
		actual[id]=clamp_to_floor(current.move_toward(goals[id],delta*float(speeds[id])))
	actual['@boss']=boss_position
	actual=spread_destinations(actual,danger,{'@boss':true})
	for id in goals:positions[id]=actual[id]

static func clamp_to_floor(point: Vector2) -> Vector2:
	return Vector2(clampf(point.x, FLOOR.position.x + 12.0, FLOOR.end.x - 12.0), clampf(point.y, FLOOR.position.y + 10.0, FLOOR.end.y - 10.0))

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
