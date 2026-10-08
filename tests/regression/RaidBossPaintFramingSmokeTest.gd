extends 'res://tests/support/V83UpgradeTestBase.gd'
## Actual attack atlas anchors, fixed paint scale, walkable floor, and inverse
## touch projection must fit together for all three regional raid originals.
const FIELD=preload('res://scripts/raid/RaidBattlefield.gd')
const CATALOG=preload('res://scripts/art/HuntFrameCatalog.gd')
const EXPECTED_TOP={'grun':216.3058315819,'morgul':235.4332620960,'selene_boss':184.3948853902}
func _init() -> void:run.call_deferred()
func run() -> void:
	var main=await make_main('aurelia',10)
	root.content_scale_size=Vector2i(1280,720);root.size=Vector2i(1120,630)
	for zone in ['gray_meadow','forgotten_mine','moonrest_forest']:
		main.selected_raid_id=zone;main._build_raid_screen();await settle();main._start_raid();await settle()
		if is_instance_valid(main.combat_timer):main.combat_timer.stop()
		main.raid_running=false
		var view=main.content_root.get_node('PortraitRaidView')
		var field=view.battlefield_3d
		field.set_process(false)
		main.raid_boss_sprite.set_process(false)
		field._process(0)
		var boss=main.raid_boss_sprite
		var identity:=CATALOG.identity(boss,false)
		var entry: Dictionary=field._frame_catalog.load_entry(identity)
		check(EXPECTED_TOP.has(identity),'actual regional boss uses the expected complete painting')
		check(absf(field._raid_boss_top_pixels()-float(EXPECTED_TOP[identity])-2.0)<.001,'camera reserves the largest actual attack anchor and 2px breathing')
		var cache_size: int=field._frame_catalog._entries.size()
		for i in 60:field._raid_boss_top_pixels()
		check(field._frame_catalog._entries.size()==cache_size and field._raid_boss_top_cache.size()==1,'repeated framing reads the identity cache instead of loading frame JSON')
		var renderer=field.actors[boss.get_instance_id()]
		var pilot=renderer.get_node('HuntFramePilot')
		check(pilot.entry.id==identity,'actual boss relief pilot renders the catalog used for framing')
		var state:=JSON.stringify([main.hero_battle_state,main.hero_skill_runtime,main.raid_boss_hp,main.wallet_gold,main.wallet_gems])
		var rng: int=main.loot_rng.state
		for boss_position in [FIELD.ENTRY,Vector2(650,FIELD.FLOOR.position.y),Vector2(650,FIELD.FLOOR.end.y)]:
			main.raid_boss_position=boss_position;boss.position=boss_position
			for peak_punch in [false,true]:
				main.combat_effects_enabled=peak_punch
				field.mobile_camera.punch_age=.05 if peak_punch else 1.0
				field.mobile_camera.shake_age=1.0
				field._process(0)
				for frame_index in 8:
					pilot._apply_frame(field.camera,field._actor_height(boss,false),Color.WHITE,'attack',frame_index)
					var pose: Dictionary=entry.attack.frames[frame_index]
					var top: Vector3=pilot.to_global(Vector3(0,float(pose.anchor[1]),0))
					var bottom: Vector3=pilot.to_global(Vector3(0,float(pose.anchor[1])-float(pose.region[3]),0))
					var top_pixel: Vector2=field.camera.unproject_position(top)*field._projection_scale()
					var bottom_pixel: Vector2=field.camera.unproject_position(bottom)*field._projection_scale()
					check(top_pixel.y>=0,'complete attack pose stays below the stage top '+identity+'/'+str(frame_index))
					check(bottom_pixel.y<=field.size.y,'complete attack pose stays above the stage bottom '+identity+'/'+str(frame_index))
				check(absf(field._actor_height(boss,false)*field.size.y/field.camera.size-179.2)<.00001,'framing changes the camera without changing the boss native paint size')
				for point in [FIELD.FLOOR.position,FIELD.FLOOR.end,Vector2(214,486),Vector2(824,280),FIELD.ENTRY]:
					var projected: Vector2=field.project_world(field.raid_to_world(point))
					check(Rect2(Vector2.ZERO,field.size).has_point(projected),'reachable raid floor stays inside the stage')
					check(projected.y<=field.size.y-field.RAID_BOTTOM_CLEARANCE+.02,'floor clears the lower context strip even during zoom punch')
					check(projected.distance_to(view.arena.position+point*view.arena.scale)<.02,'warning and arena projection stay aligned')
					var inverse: Vector2=field.world_to_raid(field.local_to_world(projected))
					check(inverse.distance_to(point)<.02,'inverse touch projection selects the original simulation point')
		check(JSON.stringify([main.hero_battle_state,main.hero_skill_runtime,main.raid_boss_hp,main.wallet_gold,main.wallet_gems])==state and main.loot_rng.state==rng,'pose framing does not change HP, cooldowns, gauge, economy, or combat RNG')
		main.raid_running=false
	await dispose(main);done('RAID_BOSS_PAINT_FRAMING')
