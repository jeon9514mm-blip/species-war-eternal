extends RefCounted
## Local steering on legal ground. Casts, stuns and real attack reach remain fixed.
const SEPARATION_PX:=25.0
const ALIGNMENT:=.15
const COHESION:=.08
const AVOID_PX:=40.0
const BEHAVIOR_MIN:=1.0
const BEHAVIOR_MAX:=8.0
const SOUND_CHANCE:=.50
const PERSONALITIES: Array[String]=['coward','curious','lazy','playful']
static func advance(main,delta: float) -> void:
	if main.challenge_session!=null or main.active_screen!='combat' or not main.combat_running:return
	var field: Control=main.combat_labels.get('terrain')
	if not is_instance_valid(field) or not field.has_method('actor_world_height') or field.size.y<1:return
	var units: float=field.camera.size/field.size.y
	var positions: Array=main.roaming_hunt.enemy_positions.duplicate()
	for index in mini(main.enemy_wave.size(),positions.size()):
		var enemy: Dictionary=main.enemy_wave[index]
		if int(enemy.get('hp',0))<=0 or enemy.has('attack_intent') or float(enemy.get('stun_seconds',0))>0 or float(enemy.get('hunt_recovery',0))>0:continue
		var timer: float=maxf(0,float(enemy.get('flock_timer',0))-delta)
		if timer<=0:
			var serial:=int(enemy.get('flock_serial',0))+1
			var local_rng:=RandomNumberGenerator.new();local_rng.seed=absi((str(main.hunt_ai.encounter_id)+':'+str(index)+':'+str(serial)).hash())
			enemy.flock_personality=PERSONALITIES[local_rng.randi_range(0,3)];enemy.flock_serial=serial
			timer=local_rng.randf_range(BEHAVIOR_MIN,BEHAVIOR_MAX)
			if local_rng.randf()<SOUND_CHANCE and main.sound_effects_enabled:
				var cue: String='monster_'+str({'coward':'cautious','curious':'pack','lazy':'bold','playful':'flanker'}[enemy.flock_personality])
				if is_instance_valid(main.presentation_runtime) and is_instance_valid(main.presentation_runtime.audio):main.presentation_runtime.audio.play_positional(cue,field,Vector2(positions[index]))
		enemy.flock_timer=timer
		var start: Vector2=positions[index];var separation:=Vector2.ZERO;var average:=Vector2.ZERO;var alignment:=Vector2.ZERO;var neighbors:=0
		for other in positions.size():
			if other==index or other>=main.enemy_wave.size() or int(main.enemy_wave[other].get('hp',0))<=0:continue
			var away: Vector2=start-Vector2(positions[other]);var distance:=away.length()
			if distance<SEPARATION_PX*units and distance>.0001:separation+=away.normalized()*(SEPARATION_PX*units-distance)
			if distance<100*units:
				average+=Vector2(positions[other]);alignment+=Vector2(main.enemy_wave[other].get('flock_velocity',Vector2.ZERO));neighbors+=1
		var steering:=separation
		if neighbors>0:steering+=alignment/neighbors*ALIGNMENT+(average/neighbors-start)*COHESION
		var target: String=str(enemy.get('target_id',''))
		if target in main._alive_hero_ids():
			var away: Vector2=start-main._hero_field_position(target)
			# Once inside legal attack reach, do not create perpetual orbiting.
			if away.length()<=main._enemy_attack_range(enemy):continue
			var personality: String=enemy.get('flock_personality','curious')
			if personality=='coward' and float(enemy.hp)/maxf(1,float(enemy.max_hp))<.3 and away.length()<AVOID_PX*units:steering+=away.normalized()*.35
			elif personality=='playful':steering+=away.normalized().orthogonal()*sin(float(enemy.flock_timer)*2)*.18
			elif personality=='curious':steering-=away.normalized()*.08
			elif personality=='lazy':steering=steering*.3+away.normalized()*.12
		var step: Vector2=steering.limit_length(.70)*maxf(0,delta)
		var goal: Vector2=main.field_navigation.clamp_to_walkable(start+step)
		if main.field_navigation.has_clear_path(start,goal):
			main.roaming_hunt.enemy_positions[index]=goal;enemy.flock_velocity=step/maxf(.0001,delta)
