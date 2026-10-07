extends RefCounted
## Ordinary-hunt body clearance. Casts and stunned actors are fixed obstacles.
const HERO_CLEARANCE:=1.14
const ENEMY_CLEARANCE:=1.12
const CONTACT_CLEARANCE:=.76
const EPSILON:=.002
const DEPTH_SCALE:=.52
static func body_vector(vector: Vector2) -> Vector2:
	# Camera compresses ground depth; reserve room for the upright painting.
	return Vector2(vector.x,vector.y*DEPTH_SCALE)
static func body_distance(left: Vector2,right: Vector2) -> float:
	return body_vector(left-right).length()
static func clearance(left: Dictionary,right: Dictionary) -> float:
	var scale: float=maxf(float(left.get('pixel_scale',0)),float(right.get('pixel_scale',0)))
	if scale>0:return (38.4 if left.hero!=right.hero else (66.0 if left.hero else 20.0))*scale
	return CONTACT_CLEARANCE if left.hero!=right.hero else (HERO_CLEARANCE if left.hero else ENEMY_CLEARANCE)
static func pixel_scale(main) -> float:
	var field: Control=main.combat_labels.get('terrain')
	if is_instance_valid(field) and field.has_method('actor_world_height') and field.size.y>0:return (field._rest_camera_size if field._rest_camera_size>0 else field.camera.size)/field.size.y
	return 0.0
static func actors(main) -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	for id in main._alive_hero_ids():
		result.append({'hero':true,'id':id,'position':main._hero_field_position(id),'walked':float(main.party_movement.distance_walked.get(id,0)),'fixed':float(main.hero_skill_runtime.get(id,{}).get('windup',-1))>=0})
	for index in main.enemy_wave.size():
		var enemy: Dictionary=main.enemy_wave[index]
		if int(enemy.get('hp',0))<=0:continue
		result.append({'hero':false,'id':index,'position':main.roaming_hunt.enemy_position(index),'fixed':enemy.has('attack_intent') or float(enemy.get('stun_seconds',0))>0 or float(enemy.get('hunt_recovery',0))>0})
	var units:=pixel_scale(main)
	for body in result:body.pixel_scale=units
	return result
static func can_commit(main,hero: bool,id) -> bool:
	if main.challenge_session!=null or not main.party_movement.independent_hunt:return true
	# The same clearance rule without allocating every actor record per caster.
	var point: Vector2=main._hero_field_position(str(id)) if hero else main.roaming_hunt.enemy_position(int(id))
	var units:=pixel_scale(main)
	var hero_radius:=((66. if hero else 38.4)*units if units>0 else (HERO_CLEARANCE if hero else CONTACT_CLEARANCE))-EPSILON
	var enemy_radius:=((38.4 if hero else 20.)*units if units>0 else (CONTACT_CLEARANCE if hero else ENEMY_CLEARANCE))-EPSILON
	for other_id in main._alive_hero_ids():
		if (hero and str(id)==str(other_id)) or int(main.hero_battle_state[other_id].get('hp',0))<=0:continue
		if body_vector(point-main._hero_field_position(str(other_id))).length_squared()<hero_radius*hero_radius:return false
	for i in main.enemy_wave.size():
		if (not hero and i==int(id)) or int(main.enemy_wave[i].get('hp',0))<=0:continue
		if body_vector(point-main.roaming_hunt.enemy_position(i)).length_squared()<enemy_radius*enemy_radius:return false
	return true
static func move(main,actor: Dictionary,push: Vector2) -> bool:
	if actor.fixed:return false
	var start: Vector2=actor.position
	for angle in [0.0,.45,-.45,.9,-.9,1.35,-1.35,1.8,-1.8]:
		var goal: Vector2=start+push.rotated(angle)
		if actor.hero:
			goal=main.party_movement.clamp_hunt_position(str(actor.id),goal,main.expedition_position)
		if not main.field_navigation.is_walkable(goal) or not main.field_navigation.has_clear_path(start,goal):continue
		if goal.distance_to(start)<.00001:continue
		actor.position=goal
		return true
	return false
static func clear(bodies: Array[Dictionary]) -> bool:
	for a in bodies.size():
		for b in range(a+1,bodies.size()):
			if body_distance(bodies[a].position,bodies[b].position)<clearance(bodies[a],bodies[b])-EPSILON:return false
	return true
static func resolve(main,delta: float,previous_bodies: Array[Dictionary]=[]) -> void:
	if main.challenge_session!=null or not main.party_movement.independent_hunt or delta<=0:return
	var bodies:=actors(main)
	# Small frame-to-frame corrections converge before any new attack is committed.
	for iteration in 8:
		var changed:=false
		for a in bodies.size():
			for b in range(a+1,bodies.size()):
				var left: Dictionary=bodies[a];var right: Dictionary=bodies[b]
				var vector: Vector2=body_vector(left.position-right.position)
				var required:=clearance(left,right)
				if vector.length_squared()>=(required-EPSILON)*(required-EPSILON) or (left.fixed and right.fixed):continue
				var distance: float=vector.length()
				var direction: Vector2=vector/distance if distance>.0001 else Vector2.from_angle(float(posmod((str(left.id)+':'+str(right.id)).hash(),6283))*.001)
				direction.y/=DEPTH_SCALE
				var overlap:=required-distance+.001
				var left_share:=0.0 if left.fixed else (1.0 if right.fixed else .5)
				var right_share:=0.0 if right.fixed else (1.0 if left.fixed else .5)
				var left_moved:=move(main,left,direction*overlap*left_share)
				var right_moved:=move(main,right,-direction*overlap*right_share)
				if not left_moved and right_share>0: right_moved=move(main,right,-direction*overlap) or right_moved
				if not right_moved and left_share>0:left_moved=move(main,left,direction*overlap) or left_moved
				changed=changed or left_moved or right_moved
		if not changed:break
	# At a rock or pursuit boundary, use a short clear side step rather than
	# repeatedly projecting the same outward push back onto the boundary.
	for actor in bodies:
		if actor.fixed:continue
		var crowded:=false
		for other in bodies:
			if actor==other:continue
			if body_distance(actor.position,other.position)<clearance(actor,other)-.01:crowded=true;break
		if not crowded:continue
		var start: Vector2=actor.position
		var found:=false
		for radius in [.06,.12,maxf(.18,delta*1.95),.30,.45]:
			for i in 24:
				var goal: Vector2=start+Vector2.from_angle(i*TAU/24)*radius
				if actor.hero:goal=main.party_movement.clamp_hunt_position(str(actor.id),goal,main.expedition_position)
				if not main.field_navigation.is_walkable(goal) or not main.field_navigation.has_clear_path(start,goal):continue
				var clear:=true
				for other in bodies:
					if actor!=other and body_distance(goal,other.position)<clearance(actor,other)-EPSILON:clear=false;break
				if clear:actor.position=goal;found=true;break
			if found:break
	# A crowded pocket must not cancel every actor's pursuit across the field.
	# Begin from the clear snapshot and accept each legal local move separately.
	var blocked_ids: Dictionary={}
	if not clear(bodies) and previous_bodies.size()==bodies.size() and clear(previous_bodies):
		var compatible:=true
		for i in bodies.size():
			if bodies[i].hero!=previous_bodies[i].hero or bodies[i].id!=previous_bodies[i].id or (bodies[i].fixed and bodies[i].position!=previous_bodies[i].position):compatible=false;break
		if compatible:
			var proposed: Array[Vector2]=[]
			for i in bodies.size():
				proposed.append(bodies[i].position)
				bodies[i].position=previous_bodies[i].position
			for offset in bodies.size():
				var i:=posmod(offset+main.combat_tick_count,bodies.size())
				var legal:=true
				for j in bodies.size():
					if i!=j and body_distance(proposed[i],bodies[j].position)<clearance(bodies[i],bodies[j])-EPSILON:legal=false;break
				if legal:bodies[i].position=proposed[i]
				else:blocked_ids[str(bodies[i].hero)+':'+str(bodies[i].id)]=true
	for actor in bodies:
		if actor.hero:
			var id:=str(actor.id)
			var blocked_frame:=blocked_ids.has('true:'+id)
			var before: Vector2=main.party_movement.positions[id]
			main.party_movement.positions[id]=actor.position
			if blocked_frame:main.party_movement.velocities[id]=Vector2.ZERO
			else:main.party_movement.velocities[id]+=Vector2(actor.position-before)/delta
			main.party_movement.distance_walked[id]=float(actor.walked)+before.distance_to(actor.position)
			if blocked_frame:
				for previous in previous_bodies:
					if previous.hero and previous.id==id:main.party_movement.distance_walked[id]=float(previous.walked);break
		else:main.roaming_hunt.enemy_positions[int(actor.id)]=actor.position
static func overlapping(main) -> Dictionary:
	var bodies:=actors(main);var counts: Dictionary={'hero_hero':0,'enemy_enemy':0,'hero_enemy':0,'pairs':0}
	for a in bodies.size():
		for b in range(a+1,bodies.size()):
			counts.pairs+=1
			if body_distance(bodies[a].position,bodies[b].position)>=clearance(bodies[a],bodies[b])-.01:continue
			var key: String='hero_enemy' if bodies[a].hero!=bodies[b].hero else ('hero_hero' if bodies[a].hero else 'enemy_enemy')
			counts[key]+=1
	return counts
