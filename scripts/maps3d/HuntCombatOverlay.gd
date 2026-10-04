extends Control
## A single clipped, camera-projected canvas replaces per-hit decorative nodes.
## Reading intents never consumes RNG or causes damage/rewards.
const ATTACK = preload('res://scripts/HuntAttackDirector.gd')
const MAX_HITS := 32
var terrain: Control
var hits: Array[Dictionary] = []

func hit(point: Vector2, source: Vector2, tint: Color, critical: bool) -> void:
	if not is_instance_valid(terrain.game) or not terrain.game.combat_effects_enabled: return
	if hits.size() >= MAX_HITS: hits.pop_front()
	hits.append({'point':point, 'source':source, 'tint':tint, 'critical':critical, 'age':0.0})
	queue_redraw()

func _process(delta: float) -> void:
	if not is_instance_valid(terrain) or not is_instance_valid(terrain.game): return
	var game = terrain.game
	if not game.combat_effects_enabled:
		hits.clear(); queue_redraw(); return
	if terrain.visual_running():
		for item in hits: item.age += maxf(0,delta) * terrain.visual_speed()
		for i in range(hits.size()-1,-1,-1):
			if float(hits[i].age) >= .20: hits.remove_at(i)
	queue_redraw()

func _draw() -> void:
	if not is_instance_valid(terrain) or not is_instance_valid(terrain.game): return
	var game = terrain.game
	if not game.combat_effects_enabled or game.challenge_session != null: return
	if game.hunt_ai.state==AutoHuntController.State.RECOVERING:return
	var alive: Array[String] = game._alive_hero_ids()
	for hero in game.deployed_heroes:
		var id := str(hero.id)
		var runtime: Dictionary = game.hero_skill_runtime.get(id,{})
		var remaining := float(runtime.get('windup',-1))
		var index := int(runtime.get('target_index',-1))
		if remaining < 0 or str(runtime.get('prepared_action','')) != 'basic' or not game._can_attack_enemy(id,index): continue
		var phase := clampf(1.0 - remaining/maxf(.01,float(runtime.get('attack_windup_duration',.15))),0,1)
		var start: Vector2 = terrain.project_world(game._hero_field_position(id),terrain.HERO_HEIGHT*.52)
		var finish: Vector2 = terrain.project_world(game.roaming_hunt.enemy_position(index),terrain.ENEMY_HEIGHT*.5)
		var tint: Color = game._hero_accent_color(id)
		if int(game.hero_battle_state[id].get('range',1)) > 1:
			# Release late in anticipation, arrive exactly when the simulation hits.
			var travel := clampf((phase-.30)/.70,0,1)
			if travel <= 0: continue
			var tip := start.lerp(finish,travel)
			var tail := start.lerp(finish,maxf(0,travel-.22))
			draw_line(tail,tip,Color(tint,.8),3,true)
			draw_circle(tip,3.5,Color('#fff7db'))
		else:
			var direction := (finish-start).angle()
			var radius := clampf(start.distance_to(finish)*.75,12,30)
			if phase > .28:
				var end := direction-1.0+phase*2.0
				draw_arc(start,radius,end-.80,end,12,Color(tint,phase*.8),2.5,true)
	for index in game.enemy_wave.size():
		var enemy: Dictionary = game.enemy_wave[index]
		if int(enemy.get('hp',0)) <= 0 or not enemy.has('attack_intent') or float(enemy.get('stun_seconds',0)) > 0: continue
		var id := str(enemy.attack_intent)
		if id not in alive: continue
		var start: Vector2 = terrain.project_world(game.roaming_hunt.enemy_position(index))
		var finish: Vector2 = terrain.project_world(game._hero_field_position(id))
		var phase := clampf(1-float(enemy.get('attack_remaining',0))/ATTACK.ENEMY_WINDUP,0,1)
		var direction := (finish-start).normalized()
		var side := direction.orthogonal()*6
		var tint := Color('#ffb253') if bool(enemy.get('elite',false)) else Color('#f07765')
		var tip := start+direction*clampf(start.distance_to(finish),12,32)
		draw_colored_polygon(PackedVector2Array([start+side,start-side,tip]),Color(tint,.12+phase*.25))
		draw_line(start,tip,Color(tint,.35+phase*.5),1.5,true)
	for item in hits:
		var point: Vector2 = terrain.project_world(item.point,terrain.ENEMY_HEIGHT*.5)
		var source: Vector2 = terrain.project_world(item.source,terrain.HERO_HEIGHT*.5)
		var age := float(item.age)/.20
		var tint := Color(Color(item.tint),1-age)
		var angle := (point-source).angle()
		var radius := (14 if bool(item.critical) else 9)*(1+age*.65)
		for i in 4:
			var ray := Vector2.from_angle(angle+PI*.25+i*PI*.5)
			draw_line(point+ray*radius*.35,point+ray*radius,tint,2 if bool(item.critical) else 1.5,true)
		draw_circle(point,3*(1-age),Color(Color('#fff2cb'),1-age))
