extends 'res://tests/support/V83UpgradeTestBase.gd'
func _init() -> void:run.call_deferred()
func run() -> void:
	var main=await make_main('aurelia',10);main._build_combat_screen();await settle()
	var field=main.combat_labels.terrain;field.set_process(false);main.combat_running=true
	if is_instance_valid(main.combat_timer):main.combat_timer.stop()
	var worst: Dictionary={'top':0.,'bottom':0.}
	for i in 180:
		main._advance_auto_hunt(1./30);field._process(1./30)
		for actor in main.hero_map_sprites:
			if actor.state=='death':continue
			var rect: Rect2=field._paint_rects.get(actor.get_instance_id(),Rect2())
			worst.top=minf(worst.top,rect.position.y-field.position.y);worst.bottom=maxf(worst.bottom,rect.end.y-field.position.y-field.size.y)
	print('HUNT_BOUNDS '+JSON.stringify(worst))
	main.combat_running=false;main._build_raid_screen();await settle();main._start_raid();await settle()
	var view=main.content_root.get_node('PortraitRaidView');field=view.battlefield_3d;field.set_process(false);field._process(0)
	var p: Vector2=field.raid_to_world(main.raid_boss_sprite.position)
	var before: Vector2=field.project_world(p);field.camera.v_offset+=.1;var after: Vector2=field.project_world(p)
	print('RAID_PROJECTION '+JSON.stringify({'before':str(before),'after_v_plus':str(after),'height':field.size.y,'floor_end':str(field.project_world(field.raid_to_world(preload('res://scripts/raid/RaidBattlefield.gd').FLOOR.end))),'v':field.camera.v_offset,'base_v':field._camera_base_v,'size':field.camera.size}))
	main.raid_running=false;await dispose(main);done('CAMERA_BOUNDS_PROBE')
