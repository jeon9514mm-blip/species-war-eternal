extends Control
## A single clipped, camera-projected canvas replaces per-hit decorative nodes.
## Reading intents never consumes RNG or causes damage/rewards.
const ATTACK = preload('res://scripts/hunting/HuntAttackDirector.gd')
const MAX_HITS := 12
const HIT_PARTICLES:=40
const SUB_PARTICLES:=20
const LEVEL_PARTICLES:=20
const TRAIL_DURATION:=.40
const MAX_ECHOES:=50
var dust: Array[Dictionary]=[]
var echoes: Array[Dictionary]=[]
var souls: Array[Dictionary]=[]
var terrain: Control
var hits: Array[Dictionary] = []
var loot_beams: Array[Dictionary]=[]
var celebrations: Array[Dictionary]=[]
var _soft_motes:=preload('res://scripts/presentation/BatchedMotes.gd').new()
func celebrate(point: Vector2,level_up: bool) -> void:
	if celebrations.size()>=4:celebrations.pop_front()
	celebrations.append({'point':point,'level_up':level_up,'age':0.0})
func loot(point: Vector2) -> void:
	if loot_beams.size()>=4:loot_beams.pop_front()
	loot_beams.append({'point':point,'age':0.0})

func footstep(point: Vector2) -> void:
	if dust.size()>=48:dust.pop_front()
	dust.append({'point':point,'age':0.0})
func soul(point: Vector2,hero: bool) -> void:
	if souls.size()>=16:souls.pop_front()
	souls.append({'point':point,'hero':hero,'age':0.0})
func afterimage(source: AnimatedSprite2D,point: Vector2,direction: Vector2) -> void:
	if not source.sprite_frames.has_animation(source.animation):return
	var texture: Texture2D=source.sprite_frames.get_frame_texture(source.animation,source.frame)
	for i in 5:
		if echoes.size()>=MAX_ECHOES:echoes.pop_front()
		echoes.append({'texture':texture,'point':point-direction*float(i+1)*.13,'height':terrain.HERO_HEIGHT,'flip':source.flip_h,'age':0.0})
func hit(point: Vector2, source: Vector2, tint: Color, critical: bool,height: float=.6) -> void:
	if not is_instance_valid(terrain.game) or not terrain.game.combat_effects_enabled: return
	if hits.size() >= MAX_HITS: hits.pop_front()
	hits.append({'point':point, 'source':source, 'tint':tint, 'critical':critical, 'height':height,'age':0.0})
	queue_redraw()

func _process(delta: float) -> void:
	if not is_instance_valid(terrain) or not is_instance_valid(terrain.game): return
	var game = terrain.game
	if not game.combat_effects_enabled:
		hits.clear();dust.clear();echoes.clear();souls.clear();loot_beams.clear();celebrations.clear();queue_redraw();return
	if terrain.visual_running():
		for item in hits: item.age += maxf(0,delta) * terrain.visual_speed()
		for i in range(hits.size()-1,-1,-1):
			if float(hits[i].age) >= .20: hits.remove_at(i)
	if terrain.visual_running():
		for collection in [dust,echoes,souls,loot_beams,celebrations]:
			for item in collection:item.age+=maxf(0,delta)*terrain.visual_speed()
			for i in range(collection.size()-1,-1,-1):
				if float(collection[i].age)>(.8 if collection==loot_beams else (TRAIL_DURATION if collection==echoes else .55)):collection.remove_at(i)
	queue_redraw()

func _draw() -> void:
	if not is_instance_valid(terrain) or not is_instance_valid(terrain.game): return
	var game = terrain.game
	if not game.combat_effects_enabled or game.challenge_session != null: return
	if not terrain.raid_mode and game.hunt_ai.state==AutoHuntController.State.RECOVERING:return
	for item in loot_beams:
		var point: Vector2=terrain.project_world(item.point);var alpha: float=(1-float(item.age)/.8)*.85
		var top:=point-Vector2(0,minf(220,terrain.size.y))
		draw_line(point,top,Color(Color('#c4a484'),alpha*.10),28,true)
		draw_line(point,top,Color(Color('#c4a484'),alpha*.30),12,true)
		draw_line(point,top,Color(Color('#fff0b8'),alpha),3,true)
		draw_arc(point,10,0,TAU,24,Color(Color('#c4a484'),alpha),1.5,true)
		for i in 6:
			var angle:=float(i)*TAU/6;var age: float=item.age
			draw_circle(point+Vector2.from_angle(angle)*age*22-Vector2(0,age*16),1.4*(1-age/.8),Color(Color('#c4a484'),alpha))
	_draw_hits()
	for item in celebrations:
		var phase: float=item.age/.55;var foot: Vector2=terrain.project_world(item.point)
		var sparks:=PackedVector2Array();sparks.resize(LEVEL_PARTICLES*2)
		for i in LEVEL_PARTICLES:
			var angle:=float(i)*TAU/LEVEL_PARTICLES
			var spot:=foot+Vector2.from_angle(angle)*(8+phase*24)-Vector2(0,phase*38)
			sparks[i*2]=spot;sparks[i*2+1]=spot+Vector2.from_angle(angle)*2.4*(1-phase)
		draw_multiline(sparks,Color(Color('#ffd700') if item.level_up else Color('#e8c99a'),(1-phase)*.8),2.0*(1-phase),true)
	if terrain.raid_mode:return
	for item in echoes:
		var age: float=item.age
		if age<0 or age>TRAIL_DURATION:continue
		var texture: Texture2D=item.texture
		var height: float=item.height*terrain.size.y/terrain.camera.size
		var extent:=Vector2(texture.get_width()/float(texture.get_height())*height,height)
		var foot: Vector2=terrain.project_world(item.point)
		var rect:=Rect2(foot-Vector2(extent.x*.5,extent.y),extent)
		if item.flip:rect.position.x+=rect.size.x;rect.size.x=-rect.size.x
		draw_texture_rect(texture,rect,false,Color(.70,.87,1.,.5*(1-age/TRAIL_DURATION)))
	_soft_motes.begin(48*3+16*8)
	for item in dust:
		var age: float=item.age/.55
		var foot: Vector2=terrain.project_world(item.point)
		for i in 3:
			var offset:=Vector2(float(i-1)*8,-age*9)
			_soft_motes.add(foot+offset,2+age*5,Color(.70,.67,.58,(1-age)*.10))
	for item in souls:
		var age: float=item.age/.55
		var foot: Vector2=terrain.project_world(item.point)
		for i in (8 if item.hero else 7):
			var angle:=float(i)*2.4
			var offset:=Vector2(cos(angle)*age*20,-age*(18+float(i%3)*8))
			_soft_motes.add(foot+offset,2*(1-age),Color(.61,.82,1.,(1-age)*.65))
	_soft_motes.draw(self)
	var alive: Array[String] = game._alive_hero_ids()
	var hero_indices: Dictionary={}
	for hero_index in game.deployed_heroes.size():hero_indices[str(game.deployed_heroes[hero_index].id)]=hero_index
	for hero_index in game.deployed_heroes.size():
		var hero: Dictionary=game.deployed_heroes[hero_index]
		var id := str(hero.id)
		var runtime: Dictionary = game.hero_skill_runtime.get(id,{})
		var remaining := float(runtime.get('windup',-1))
		var index := int(runtime.get('target_index',-1))
		if remaining < 0 or str(runtime.get('prepared_action','')) != 'basic' or not game._can_attack_enemy(id,index): continue
		var phase := clampf(1.0 - remaining/maxf(.01,float(runtime.get('attack_windup_duration',.15))),0,1)
		if hero_index<0 or hero_index>=game.hero_map_sprites.size() or index>=game.enemy_wave_sprites.size():continue
		var hero_source: AnimatedSprite2D=game.hero_map_sprites[hero_index]
		var enemy_source: AnimatedSprite2D=game.enemy_wave_sprites[index]
		var start: Vector2 = terrain.project_world(terrain.display_world(hero_source,game._hero_field_position(id)),terrain._actor_height(hero_source,true)*.52)
		var finish: Vector2 = terrain.project_world(terrain.display_world(enemy_source,game.roaming_hunt.enemy_position(index)),terrain._actor_height(enemy_source,false)*.5)
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
		var hero_index: int=hero_indices.get(id,-1)
		if index>=game.enemy_wave_sprites.size() or hero_index<0 or hero_index>=game.hero_map_sprites.size():continue
		var start: Vector2 = terrain.project_world(terrain.display_world(game.enemy_wave_sprites[index],game.roaming_hunt.enemy_position(index)))
		var finish: Vector2 = terrain.project_world(terrain.display_world(game.hero_map_sprites[hero_index],game._hero_field_position(id)))
		var phase := clampf(1-float(enemy.get('attack_remaining',0))/ATTACK.ENEMY_WINDUP,0,1)
		var direction := (finish-start).normalized()
		var side := direction.orthogonal()*6
		var tint := Color('#ffb253') if bool(enemy.get('elite',false)) else Color('#f07765')
		var tip := start+direction*clampf(start.distance_to(finish),12,32)
		draw_colored_polygon(PackedVector2Array([start+side,start-side,tip]),Color(tint,.12+phase*.25))
		draw_line(start,tip,Color(tint,.35+phase*.5),1.5,true)
func _draw_hits() -> void:
	for item in hits:
		var point: Vector2 = terrain.project_world(item.point,float(item.height)*.5)
		var source: Vector2 = terrain.project_world(item.source,terrain.HERO_HEIGHT*.5)
		var age := float(item.age)/.20
		var tint := Color(Color(item.tint),1-age)
		var angle := (point-source).angle()
		var radius := (16 if bool(item.critical) else 10)*1.8*(1+age*.65)
		var count:=HIT_PARTICLES
		var rays:=PackedVector2Array();rays.resize(count*2)
		for i in count:
			var ray := Vector2.from_angle(angle+float(i)*TAU/count+sin(float(i)*2.4)*.14*age)
			var speed:=.75+.25*sin(float(i)*1.7)
			rays[i*2]=point+ray*radius*.35*speed;rays[i*2+1]=point+ray*radius*speed
		# Forty deterministic particle paths use a single batched canvas command.
		draw_multiline(rays,tint,2 if bool(item.critical) else 1.5,true)
		if bool(item.critical):
			var secondary:=PackedVector2Array();secondary.resize(SUB_PARTICLES*2)
			for i in SUB_PARTICLES:
				var ray:=Vector2.from_angle(float(i)*TAU/SUB_PARTICLES+age*.8)
				var offset:=ray*radius*(.55+age*.8)-Vector2(0,age*12)
				secondary[i*2]=point+offset;secondary[i*2+1]=point+offset+ray*3*(1-age)
			draw_multiline(secondary,Color(Color('#ffd700'),(1-age)*.8),1.2,true)
		draw_circle(point,2*(1-age),Color(Color('#d8d5cc'),(1-age)*.6))
		if float(item.age)<.18:
			var impact: float=1-float(item.age)/.18
			var ring_radius: float=(8+float(item.age)*100)*1.8
			draw_arc(point,ring_radius,0,TAU,24,Color(tint,impact*.50),8,true)
			draw_arc(point,ring_radius*.72,0,TAU,24,Color(1,1,1,impact*.60),3,true)
			draw_arc(point,ring_radius,0,TAU,24,Color(1,1,1,impact*.90),4,true)
		if source.distance_to(point)>1:
			var toward:=(point-source).normalized()
			draw_line(point-toward*22,point+toward*8,Color(1,1,1,(1-age)*.8),4,true)
