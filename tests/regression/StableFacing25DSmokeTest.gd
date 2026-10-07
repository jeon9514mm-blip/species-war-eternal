extends 'res://tests/support/V83UpgradeTestBase.gd'
const PAINT=preload('res://scripts/art/HuntFramePilot.gd')
func _init() -> void:run.call_deferred()
func run() -> void:
	var camera:=Camera3D.new();root.add_child(camera)
	var holder:=Node2D.new();root.add_child(holder)
	for id in ROSTER.HEROES:
		var source=HeroSpriteFactory.create_hero(id);holder.add_child(source)
		source.set_process(false);source.observe_game=false;source.hold_demo=true;source.speed_scale=1
		var pilot=PAINT.new();root.add_child(pilot);check(pilot.bind(source,true),str(id)+' binds')
		var point:=Vector2.ZERO
		for velocity in [Vector2(-.2,-2),Vector2(.2,-2),Vector2(-.2,2),Vector2(.2,2)]:
			source.play_walk(velocity)
			for tick in 24:
				point+=velocity.normalized()*.07
				pilot.present(camera,1.55,Color.WHITE,1.0/30,true,point,{},false)
			check(pilot.debug_snapshot().flip==(velocity.x<0),str(id)+' diagonal gaze follows horizontal movement '+str(velocity))
			var bounds: AABB=pilot.mesh.get_aabb()
			check(is_equal_approx(bounds.size.y*pilot.basis.y.length(),1.55),str(id)+' moving pose height stays fixed')
			source.play_idle('right')
		for direction in [Vector2.LEFT,Vector2.RIGHT]:
			source.play_idle('right');pilot.timeline.release('attack_1',.15)
			pilot.present(camera,1.55,Color.WHITE,0,true,point,{'facing_target':point+direction},false)
			check(pilot.debug_snapshot().flip==(direction.x<0),str(id)+' cast faces target despite source idle reset')
			check(is_equal_approx(pilot.debug_snapshot().phase,.44),str(id)+' facing preserves release boundary')
		var held: Dictionary=pilot.debug_snapshot()
		pilot.present(camera,1.55,Color.WHITE,.2,false,point,{'facing_target':point+Vector2.LEFT},false)
		check(pilot.debug_snapshot().flip==held.flip and pilot.debug_snapshot().frame==held.frame,str(id)+' pause freezes gaze and pose')
		for frame in 6:
			pilot._apply_frame(camera,1.55,Color.WHITE,'motion',frame)
			check(is_equal_approx(pilot.mesh.get_aabb().size.y*pilot.basis.y.length(),1.55),str(id)+' idle/walk pose '+str(frame)+' uniform height')
		pilot.free();source.free()
	holder.free();camera.free()
	var movement=preload('res://scripts/hunting/PartyMovementDirector.gd').new();movement.independent_hunt=true
	var roster: Array=ROSTER.roster('aurelia').slice(0,10)
	movement.configure(roster,{},Vector2(16,10))
	var low:=Vector2(INF,INF);var high:=Vector2(-INF,-INF);var clear:=true
	for offset: Vector2 in movement.travel_offsets.values():low=low.min(offset);high=high.max(offset)
	var offsets: Array=movement.travel_offsets.values()
	for a in offsets.size():
		for b in range(a+1,offsets.size()):
			clear=clear and preload('res://scripts/hunting/HuntBodyCollision.gd').body_distance(offsets[a],offsets[b])>=1.14
	check((high-low).x<=4.89 and (high-low).y<=2.31 and clear,'compact two-row deployment preserves body clearance')
	var planner=preload('res://scripts/hunting/HuntPositionPlanner.gd')
	var stance:=Vector2(16,10)
	var target_points: Array[Vector2]=[Vector2(16.85,10)]
	var stance_state: Dictionary={'hp':100,'range':1}
	var stance_enemies: Array=[{'hp':100}]
	movement.movement_profiles.leonhardt={'melee':true}
	for side in [-1.0,1.0]:
		var destination: Vector2=planner.choose(movement,'leonhardt',stance,0,target_points[0]+Vector2(0,side*.7),stance_state,{'leonhardt':stance_state},{'leonhardt':stance},{'leonhardt':stance},stance_enemies,target_points,{})
		check(destination==stance,'legal melee stance stays still despite changed approach side')
	var invasion=preload('res://scripts/hunting/InvasionHuntDirector.gd').new()
	invasion.configure(stance,7)
	invasion.append_corps([{'hp':100,'archetype':'brute'}],1)
	invasion.enemy_positions[0]=stance
	invasion.target_attack_reaches.assign([.95])
	invasion.advance(.1,[true],[false],[Vector2(16.82,10)])
	check(invasion.enemy_positions[0]==stance,'monster holds valid attack stance instead of orbiting to another side')
	invasion.advance(.1,[true],[false],[Vector2(18,10)])
	check(invasion.enemy_positions[0]!=stance,'monster resumes pursuit when the target leaves contact')
	var main=await make_main('aurelia',10)
	root.content_scale_size=Vector2i(1280,720);root.size=Vector2i(1280,720);await settle()
	main._build_combat_screen();await settle();main.combat_running=true
	if is_instance_valid(main.combat_timer):main.combat_timer.stop()
	var field=main.combat_labels.terrain;field.set_process(false);field._process(0)
	var zoom: float=field.camera.size
	var heights: Dictionary={}
	for actor in main.hero_map_sprites:heights[actor.get_instance_id()]=field._actor_height(actor,true)*field.size.y/field.camera.size
	var stable:=true;var camera_stable:=true
	var party_visible:=true
	for tick in 180:
		main._advance_auto_hunt(1.0/30)
		for actor in main.hero_map_sprites+main.enemy_wave_sprites:actor.set_process(false)
		field._process(1.0/30)
		camera_stable=camera_stable and is_equal_approx(field._rest_camera_size,zoom)
		for actor in main.hero_map_sprites:
			if actor.state=='death':continue
			# Use the actual painted rectangles so camera smoothing cannot clip heads.
			var rect: Rect2=field._paint_rects.get(actor.get_instance_id(),Rect2())
			party_visible=party_visible and (not rect.has_area() or (rect.position.y>=field.position.y-.02 and rect.end.y<=field.position.y+field.size.y+.02))
		for actor in main.hero_map_sprites:stable=stable and is_equal_approx(field._actor_height(actor,true)*field.size.y/field.camera.size,heights[actor.get_instance_id()])
	check(stable,'ten hero displayed heights stay fixed across camera punches, crowd movement, hits and deaths')
	check(camera_stable,'target motion cannot change the rest hunt zoom')
	check(party_visible,'compact pursuit keeps living hero paintings inside the fixed-height hunt view')
	if not main.enemy_wave_sprites.is_empty():
		var enemy=main.enemy_wave_sprites[0];var height: float=field._actor_height(enemy,false)
		enemy.scale*=.2;check(is_equal_approx(field._actor_height(enemy,false),height),'legacy spawn/hit source scale cannot resize painted monsters')
	main.combat_running=false
	main._build_raid_screen();await settle();main._start_raid();main.combat_timer.stop()
	var view=main.content_root.get_node('PortraitRaidView');field=view.battlefield_3d
	field.set_process(false);view.set_process(false);field._process(0)
	var hero=view.hero_actors.values()[0]
	var height: float=field._actor_height(hero,true)*field.size.y/field.camera.size;zoom=field.camera.size
	for tick in 120:
		main._advance_raid_encounter(1.0/30);view._process(1.0/30)
		for actor in view.hero_actors.values():actor.set_process(false)
		main.raid_boss_sprite.set_process(false);field._process(1.0/30)
	check(is_equal_approx(field._actor_height(hero,true)*field.size.y/field.camera.size,height),'raid movement and camera fitting retain projected hero height')
	main.raid_running=false;await dispose(main);done('STABLE_FACING_25D')
