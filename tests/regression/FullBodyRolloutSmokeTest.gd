extends 'res://tests/support/V83UpgradeTestBase.gd'
const PAINT=preload('res://scripts/art/HuntFramePilot.gd')
const LAYOUT=preload('res://scripts/maps3d/CombatBodyLayout.gd')
func _init() -> void:run.call_deferred()

func run() -> void:
	var camera:=Camera3D.new();root.add_child(camera)
	var holder:=Node2D.new();root.add_child(holder)
	var catalog=PAINT.CATALOG.new()
	var covered:=0
	for hero in [true,false]:
		var ids: Array=preload('res://scripts/sd/SDHeroVisuals.gd').HEROES.keys() if hero else MonsterPixelAtlasLayout.PROFILES.keys()
		for id in ids:
			var actor: AnimatedSprite2D=HeroSpriteFactory.create_hero(id) if hero else MonsterSpriteFactory.create_monster(id)
			if not hero:MonsterSpriteFactory.apply_casual(actor,id)
			holder.add_child(actor);actor.set_process(false)
			if hero and actor.has_method('play_visual'):actor.observe_game=false;actor.hold_demo=true
			var paint=PAINT.new();root.add_child(paint)
			var bound: bool=paint.bind(actor,hero,catalog)
			check(bound,str(id)+' complete frames load')
			if not bound:paint.free();actor.free();continue
			covered+=1
			check(not paint._existing,str(id)+' uses authored original paintings, never old SD fallback')
			if hero:
				actor.play_idle('right');paint.present(camera,1.55,Color.WHITE,0,true,Vector2.ZERO,{},false)
				var vertices: PackedVector3Array=paint.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
				var bottom:=INF;var top:=-INF
				for point in vertices:bottom=minf(bottom,point.y);top=maxf(top,point.y)
				check(absf((top-bottom)*paint.basis.y.length()-1.55)<.015,str(id)+' standing painting has the same 1.55 world height')
			for flip in [false,true]:
				actor.flip_h=flip
				for action in ['attack_1','skill','ultimate'] if hero else ['attack_1']:
					paint.timeline.release(action,.15 if hero else .22)
					paint.present(camera,1.55,Color.WHITE,0,true,Vector2.ZERO,{},false)
					var snapshot: Dictionary=paint.debug_snapshot()
					check(snapshot.action==action and is_equal_approx(snapshot.phase,.44),str(id)+' actual release contact for '+action)
					check(snapshot.bones==0 and snapshot.body_parts==1 and is_equal_approx(paint.basis.x.length(),paint.basis.y.length()),str(id)+' undistorted single body in each facing')
				actor.play_walk(Vector2.RIGHT)
				for n in 24:paint.present(camera,1.55,Color.WHITE,1.0/30,true,Vector2(n*.05,0),{},false)
				check(paint.debug_snapshot().action=='walk',str(id)+' movement uses whole frames')
				paint.present(camera,1.55,Color.WHITE,0,false,Vector2.ZERO,{},false)
				var frozen: Dictionary=paint.debug_snapshot()
				for n in 5:paint.present(camera,1.55,Color.WHITE,.1,false,Vector2.ZERO,{},false)
				check(paint.debug_snapshot()==frozen,str(id)+' pause preserves pose and gait distance')
				paint.present(camera,1.55,Color.WHITE,0,true,Vector2.ZERO,{},true)
				check(paint.debug_snapshot().action=='death',str(id)+' death follows actual HP')
				paint.present(camera,1.55,Color.WHITE,0,true,Vector2.ZERO,{},false)
				check(paint.debug_snapshot().action!='death',str(id)+' revival clears fallen frame')
			paint.free();actor.free()
	check(covered==46,'30 heroes, 13 monsters and 3 bosses all covered')
	holder.free();camera.free()
	# Dense projected crowds, asymmetric weapons and multiple depths. Test the
	# resulting visible rectangles, not the implementation's internal metric.
	var rng:=RandomNumberGenerator.new();rng.seed=7102026
	for fixture in 50:
		var items: Array[Dictionary]=[]
		for i in 20:
			var height:=rng.randf_range(.9,2.8);var width:=rng.randf_range(.7,1.9)
			items.append({'id':i,'hero':i<10,'point':Vector2((i%5)*.7+rng.randf_range(-.2,.2),int(i/5.0)*.75+rng.randf_range(-.2,.2)),'bounds':Rect2(-width*.4,-height,width,height+.02)})
		var scales:=LAYOUT.fit(items)
		var equal_size:=true
		for i in 10:
			if not is_equal_approx(scales[i],scales[0]):equal_size=false
		check(equal_size,'all ten heroes share a uniform scale in crowd '+str(fixture))
		var balanced_size:=true
		for item in items:
			if not is_equal_approx(scales[item.id],scales[0]):balanced_size=false
		check(balanced_size,'both factions retain the same crowd factor '+str(fixture))
		var clear:=true
		for a in items.size():
			var ar: Rect2=items[a].bounds;var sa: float=scales[a]
			ar=Rect2(items[a].point+ar.position*sa,ar.size*sa)
			for b in range(a+1,items.size()):
				var br: Rect2=items[b].bounds;var sb: float=scales[b]
				br=Rect2(items[b].point+br.position*sb,br.size*sb)
				if ar.intersects(br):clear=false
		check(clear,'all painted body rectangles separate in crowd '+str(fixture))
	var main=await make_main('aurelia',10)
	root.content_scale_size=Vector2i(1280,720);root.size=Vector2i(1280,720)
	for zone in ['gray_meadow','forgotten_mine','moonrest_forest']:
		main.selected_raid_id=zone;main._build_raid_screen();await settle();main._start_raid();main.combat_timer.stop()
		var view=main.content_root.get_node('PortraitRaidView');var terrain=view.battlefield_3d
		terrain.set_process(false);view.set_process(false)
		for actor in view.hero_actors.values():actor.set_process(false)
		main.raid_boss_sprite.set_process(false)
		terrain._process(0);terrain._process(0)
		var hero_factor: float=terrain._body_scales[view.hero_actors.values()[0].get_instance_id()]
		for actor in view.hero_actors.values():check(is_equal_approx(terrain._body_scales[actor.get_instance_id()],hero_factor),zone+' all heroes retain the same display size')
		check(terrain.visual_running(),zone+' uses the real raid clock')
		for actor in view.hero_actors.values():check(terrain.actors[actor.get_instance_id()].get_node('HuntFramePilot')!=null,zone+' hero routed to complete frame')
		var boss=terrain.actors[main.raid_boss_sprite.get_instance_id()].get_node('HuntFramePilot')
		check(str(boss.entry.id)==str(PAINT.CATALOG.MONSTERS[main.raid_boss_name]),zone+' boss identity has its own artwork')
		var positions: Dictionary=main.raid_positions.duplicate(true);var hp: int=main.raid_boss_hp;var seed: int=main.loot_rng.state
		main.raid_boss_sprite.play_attack('left');terrain._process(0)
		check(boss.debug_snapshot().action=='attack_1' and is_equal_approx(boss.debug_snapshot().phase,.44),zone+' actual boss attack selects contact frame')
		main.raid_boss_sprite.play_hit('left');terrain._process(0)
		check(boss.timeline.hit_age==0,zone+' real source hit produces whole-body recoil')
		main.raid_running=false;terrain._process(0);var held: Dictionary=boss.debug_snapshot()
		for i in 10:terrain._process(.1)
		check(boss.debug_snapshot()==held,zone+' paused boss holds its frame')
		check(main.raid_positions==positions and main.raid_boss_hp==hp and main.loot_rng.state==seed,zone+' body layout leaves coordinates, damage and RNG untouched')
	await dispose(main);done('full_body_rollout')
