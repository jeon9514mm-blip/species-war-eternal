extends RefCounted
## Reserve destinations as well as bodies. Casts stay fixed; walkers yield.
const SPACING := 1.12
const BODY=preload('res://scripts/hunting/HuntBodyCollision.gd')
const ANGLES := [0.0,.45,-.45,.90,-.90,1.35,-1.35,1.8,-1.8,2.25,-2.25,2.7,-2.7,PI]
static func choose(director, id: String, start: Vector2, target: int, desired: Vector2, state: Dictionary, states: Dictionary, bodies: Dictionary, reserved: Dictionary, enemies: Array, points: Array[Vector2], runtimes: Dictionary) -> Vector2:
	var enemy: Vector2=points[target]
	var profile: Dictionary=director.movement_profiles.get(id,{})
	var melee: bool=profile.get('melee',true)
	var reach: float=director._decisions.spatial_range(int(state.get('range',1)))
	# Leave travel room for a moving enemy during the committed attack windup.
	var safe_reach: float=maxf(.12,reach-(.08 if melee else .24))
	# A melee destination inside body clearance cannot become an attack stance.
	var radius: float=minf(safe_reach,maxf(BODY.CONTACT_CLEARANCE+.06,desired.distance_to(enemy))) if melee else safe_reach
	var settled: bool=start.distance_to(enemy)<=safe_reach and BODY.body_distance(start,enemy)>=BODY.CONTACT_CLEARANCE
	var movement_proc: bool=bool(profile.get('moving',false)) and start.distance_to(desired)>.15
	for other in bodies:
		if other!=id and int(states.get(other,{}).get('hp',0))>0 and BODY.body_distance(start,bodies[other])<BODY.HERO_CLEARANCE:settled=false
	for i in points.size():
		if i>=enemies.size() or int(enemies[i].get('hp',0))<=0:continue
		if BODY.body_distance(start,points[i])<BODY.CONTACT_CLEARANCE:settled=false
		if not melee and start.distance_to(points[i])<1.10:settled=false
	# Hold a legal firing position instead of continually chasing a rotating slot.
	# Movement-triggered kits and threatened back-line heroes still reposition.
	if settled and not movement_proc:
		director.hunt_slots[id]={'target':target,'offset':start-enemy}
		director.combat_goals[id]={'target':target,'goal':start}
		return start
	var axis: Vector2=(desired-enemy).normalized()
	if axis.length_squared()<.01:axis=Vector2.from_angle(float(posmod(id.hash(),6283))*.001)
	var candidates: Array[Vector2]=[]
	if start.distance_to(enemy)<=safe_reach:candidates.append(start)
	if desired.distance_to(enemy)<=safe_reach:candidates.append(desired)
	var memory: Dictionary=director.hunt_slots.get(id,{})
	var previous: Vector2=enemy+Vector2(memory.get('offset',Vector2.ZERO))
	if int(memory.get('target',-1))==target and previous.distance_to(enemy)<=safe_reach:candidates.append(previous)
	for angle in ANGLES:candidates.append(enemy+axis.rotated(angle)*radius)
	var best:=desired
	var best_score:=INF
	for candidate in candidates:
		if not director._point_walkable(candidate) or not director._clear_path(candidate,enemy):continue
		if start.distance_to(enemy)<reach+1.0 and not director._clear_path(start,candidate):continue
		var score: float=start.distance_to(candidate)*.18+candidate.distance_to(desired)*(.42 if melee else .12)
		# Contact from the side leaves the enemy's face and the hero's body visible.
		var contact_overlap:=maxf(0,BODY.CONTACT_CLEARANCE-BODY.body_distance(candidate,enemy))
		score+=contact_overlap*contact_overlap*30.0
		for other in bodies:
			if other==id or int(states.get(other,{}).get('hp',0))<=0:continue
			var fixed: bool=float(runtimes.get(other,{}).get('windup',-1))>=0
			var overlap:=maxf(0,SPACING-BODY.body_distance(candidate,bodies[other]))
			score+=overlap*overlap*(12.0 if fixed else 6.0)
			var occupied: Vector2=reserved.get(other,bodies[other])
			var goal_overlap:=maxf(0,SPACING-BODY.body_distance(candidate,occupied))
			score+=goal_overlap*goal_overlap*10.0
		if not melee:
			for i in points.size():
				if i>=enemies.size() or int(enemies[i].get('hp',0))<=0:continue
				var threatening: bool=str(enemies[i].get('attack_intent',''))==id
				var danger:=maxf(0,(1.28 if threatening else 1.10)-candidate.distance_to(points[i]))
				score+=danger*danger*(18.0 if threatening else 10.0)
			score+=maxf(0,reach-.22-candidate.distance_to(enemy))*2.0
		if candidate==previous and int(memory.get('target',-1))==target:score-=.16
		if candidate==start:score-=.08
		if score<best_score:best=candidate;best_score=score
	director.hunt_slots[id]={'target':target,'offset':best-enemy}
	director.combat_goals[id]={'target':target,'goal':best}
	return best
