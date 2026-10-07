extends "res://tests/support/V83UpgradeTestBase.gd"
const FRAMING=preload('res://scripts/maps3d/CombatCameraFraming.gd')
const FLOOR=preload('res://scripts/raid/RaidBattlefield.gd')
func _init() -> void:run.call_deferred()
func run() -> void:
	for faction in ['aurelia','noxfera']:
		var main=await make_main(faction,10)
		main._build_combat_screen();await settle()
		main.combat_running=false
		var terrain=main.combat_labels.terrain
		var hp: Dictionary=main.hero_battle_state.duplicate(true)
		var wave: Array=main.enemy_wave.duplicate(true)
		for screen in [Vector2i(720,1280),Vector2i(1280,720),Vector2i(720,1600),Vector2i(450,800)]:
			main.presentation_options.orientation='landscape' if screen.x>screen.y else 'portrait'
			preload('res://scripts/app/DisplayOrientation.gd').apply(main,false);root.size=screen
			await settle();main._apply_portrait_resize();await settle()
			terrain._resize_world();terrain._process(0)
			check(main.hero_battle_state==hp and main.enemy_wave==wave,'view resize preserves battle '+str(screen))
			check(terrain.camera.size*minf(1.,terrain.size.x/terrain.size.y)<34.0,'closer combat framing '+str(screen))
			for point in terrain.camera_points():
				var ground: Vector2=terrain.project_world(Vector2(point.x,point.z))
				var visual:=ground-Vector2(0,point.y*terrain.size.y/terrain.camera.size)
				check(Rect2(Vector2.ZERO,terrain.size).has_point(visual),'living actor fits '+str(screen))
			for point in [Vector2(0,0),Vector2(16,10),Vector2(32,20)]:
				check(terrain.local_to_world(terrain.project_world(point)).distance_to(point)<.001,'tap projection round trip')
			var reference_height:=-1.0
			for sprite in main.hero_map_sprites:
				check(sprite.visibility_layer==0,'source 2D painting cannot reappear over original')
				var actor: Sprite3D=terrain.actors[sprite.get_instance_id()]
				var paint=actor.get_node('HuntFramePilot')
				var standing_height: float=paint.basis.y.length()*float(paint.entry.motion.native_height)
				if reference_height<0:reference_height=standing_height
				check(is_equal_approx(standing_height,reference_height),'consistent original hero body height after crowd fitting')
			for bar in main.hero_hp_bars.values():check(not bar.visible,'full health hero bar leaves screen clear')
			check(terrain.find_child('CombatViewToggle',true,false)==null,'only combat camera remains')
			check(not terrain.has_method('_toggle_overview'),'overview switching removed')
		# A sudden wave on opposite edges must stay visible during smooth follow.
		var corners: Array[Vector3]=[Vector3(0,3,0),Vector3(32,0,20)]
		var sine: float=terrain.CAMERA_OFFSET.normalized().y
		var frame: Dictionary=FRAMING.fit(corners,terrain.size,sine)
		var old_focus:=Vector2(4,4)
		var required: float=FRAMING.size_at_center(frame.bounds,old_focus,terrain.size,sine)
		check(required>=frame.size,'outward safety fit during tracking')
		# Injured units get short, non-overlapping labels; priority target is retained.
		for bar in main.hero_hp_bars.values():bar.value=25
		for bar in main.enemy_hp_bars:bar.value=50
		main.roaming_hunt.aggro_active=true;main.roaming_hunt.current_target=0
		terrain._process(0)
		var occupied: Array[Rect2]=[]
		var visible:=0
		for bar in main.hero_hp_bars.values()+main.enemy_hp_bars:
			if not bar.visible:continue
			visible+=1
			var rect: Rect2=bar.get_rect()
			check(Rect2(terrain.position,terrain.size).encloses(rect),'health label inside field')
			for used in occupied:check(not rect.intersects(used),'health labels do not overlap')
			occupied.append(rect)
		check(visible>0,'injured health labels visible')
		check(main.enemy_hp_bars[0].visible,'selected target keeps priority label')
		main.selected_raid_id='gray_meadow';main._build_raid_screen();await settle();await settle()
		var raid=main.content_root.get_node('PortraitRaidView');terrain=raid.battlefield_3d
		for point in [FLOOR.FLOOR.position,FLOOR.FLOOR.end,Vector2(214,486),Vector2(824,280),FLOOR.ENTRY]:
			var projected: Vector2=terrain.project_world(terrain.raid_to_world(point))
			check(Rect2(Vector2.ZERO,terrain.size).has_point(projected),'raid reachable floor stays visible')
			check(projected.distance_to(raid.arena.position+point*raid.arena.scale)<.02,'raid warnings share actor projection')
			check(((projected-raid.arena.position)/raid.arena.scale).distance_to(point)<.02,'raid touch maps to original position')
		# Camera keeps reachable floor above the dodge/auto-follow button strip.
		var near_edge: Vector2=terrain.project_world(terrain.raid_to_world(FLOOR.FLOOR.end))
		check(near_edge.y<terrain.size.y-55,'raid movement floor clears bottom controls')
		await dispose(main)
	done('v8364_combat_view')
