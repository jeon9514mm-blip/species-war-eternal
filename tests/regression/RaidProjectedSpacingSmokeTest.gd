extends 'res://tests/support/V83UpgradeTestBase.gd'
## Exercise production movement in the actual raid camera, rather than checking
## the spread helper's constants or arranging a separate screenshot formation.
const FIELD=preload('res://scripts/raid/RaidBattlefield.gd')
func _init() -> void:run.call_deferred()
func _battle_state(main) -> String:
	return JSON.stringify([main.hero_battle_state,main.hero_skill_runtime,main.raid_boss_hp,main.wallet_gold,main.wallet_gems,main.loot_rng.state])
func _gaps(main,field) -> Dictionary:
	var points: Array[Vector2]=[]
	var ids: Array=main._deployed_hero_ids()
	var distances: Array[float]=[]
	var boss_gap:=INF
	var farthest:=0.0
	var boss_point: Vector2=field.project_world(field.raid_to_world(main.raid_boss_position))
	for id in ids:
		var feet: Vector2=main.raid_positions[id]
		var point: Vector2=field.project_world(field.raid_to_world(feet))
		points.append(point)
		boss_gap=minf(boss_gap,point.distance_to(boss_point))
		farthest=maxf(farthest,feet.distance_to(main.raid_boss_position))
	for i in points.size():
		for j in range(i+1,points.size()):distances.append(points[i].distance_to(points[j]))
	distances.sort()
	return {'min':distances[0],'p10':distances[int(distances.size()*.1)],'median':distances[distances.size()/2],'boss_min':boss_gap,'farthest_attack_distance':farthest,'factor':field.raid_projection_factor()}
func run() -> void:
	for faction in ['aurelia','noxfera']:
		var main=await make_main(faction,10)
		root.content_scale_size=Vector2i(1280,720);root.size=Vector2i(1120,630)
		for zone in ['gray_meadow','forgotten_mine','moonrest_forest']:
			main.selected_raid_id=zone;main._build_raid_screen();await settle()
			main._start_raid();await settle()
			if is_instance_valid(main.combat_timer):main.combat_timer.stop()
			main.set_process(false);main.set_physics_process(false)
			var view=main.content_root.get_node('PortraitRaidView')
			var field=view.battlefield_3d
			view.set_process(false);field.set_process(false)
			field._process(0)
			var before:=_battle_state(main)
			var lowest:=INF
			for step in 120:
				main.raid_elapsed+=.05
				main._raid_move_actors(.05)
				view._process(.05);field._process(0)
				if step>=60:lowest=minf(lowest,float(_gaps(main,field).min))
			var label: String=faction+'/'+zone
			var gaps:=_gaps(main,field)
			gaps['lowest_after_3s']=lowest
			print('RAID_PROJECTED_SPACING '+label+' '+JSON.stringify(gaps))
			# A 64px minimum gives the fixed 86.4px painted bodies visible frontage.
			# Deliberate attack weapon intersections remain part of their animation.
			check(lowest>=64.0,label+' moving bodies keep at least 64 logical pixels between feet')
			check(float(gaps.p10)>=68.0,label+' lower tenth of settled body gaps avoids a dense cluster')
			check(float(gaps.boss_min)>=75.0,label+' fixed large boss does not swallow the nearest hero body')
			check(float(gaps.farthest_attack_distance)<=335.05,label+' all ten heroes remain able to attack instead of being parked out of range')
			for id in main._deployed_hero_ids():
				var point: Vector2=main.raid_positions[id]
				check(FIELD.FLOOR.has_point(point),label+' actual '+str(id)+' feet remain on walkable floor')
				var projected: Vector2=field.project_world(field.raid_to_world(point))
				var inverse: Vector2=field.world_to_raid(field.local_to_world(projected))
				check(inverse.distance_to(point)<.02,label+' actual '+str(id)+' feet and touch targeting agree')
				var actor: AnimatedSprite2D=view.hero_actors[id]
				check(actor.position.distance_to(point)<.02,label+' rendered '+str(id)+' follows actual combat feet')
				check(absf(field._actor_height(actor,true)*field.size.y/field.camera.size-86.4)<.0001,label+' '+str(id)+' keeps the requested original size')
			check(_battle_state(main)==before,label+' movement and crowd separation preserve HP cooldowns gauges economy and combat RNG')
			main.combat_effects_enabled=true
			field.mobile_camera.shake_age=1.0;field.mobile_camera.punch_age=1.0;field._process(0)
			var resting: Vector2=field.raid_clearances()
			var feet_before: Dictionary=main.raid_positions.duplicate()
			field.mobile_camera.punch_age=.05;field._process(0)
			check(field.raid_clearances().distance_to(resting)<.001,label+' a short zoom punch does not alter crowd spacing')
			check(main.raid_positions==feet_before and _battle_state(main)==before,label+' camera punch cannot teleport actual feet or change gameplay')
			for id in main._deployed_hero_ids():
				check(absf(field._actor_height(view.hero_actors[id],true)*field.size.y/field.camera.size-86.4)<.0001,label+' zoom punch keeps '+str(id)+' original size')
			main.combat_effects_enabled=false;main.raid_running=false
		await dispose(main)
	done('RAID_PROJECTED_SPACING')
