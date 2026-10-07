extends SceneTree

var checks := 0
var failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
		push_error(description)

func _run() -> void:
	var holder := Node2D.new()
	root.add_child(holder)
	for hero_id in HeroSpriteFactory.BRIGHT_SPRITES:
		# Validate the retained v28 fallback assets directly. Current factory routing
		# is covered by V46CurrentAssetsSmokeTest (the live game uses action sheets).
		var hero := HeroSpriteController.new()
		hero.set_bright_sheet(load(HeroSpriteFactory.BRIGHT_SPRITES[hero_id]), hero_id)
		hero.scale = Vector2.ONE * (40.0 / hero.native_visual_height)
		holder.add_child(hero)
		_check(hero.sheet_layout == "bright", "%s uses approved bright atlas" % hero_id)
		_check(absf(hero.get_visual_height() - 40.0) < 0.01, "%s battlefield height is 40 pixels" % hero_id)
		_check(hero.get_foot_offset() == Vector2.ZERO and hero.get_head_offset().y < -39.0, "%s has a shared feet origin" % hero_id)
		_check(HeroSpriteFactory.portrait_texture(hero_id) != null, "%s portrait available" % hero_id)
		_check_atlas(hero.sprite_sheet, hero_id)
		_check_actor_frames(hero, hero_id)
		hero.play_walk(Vector2.RIGHT)
		_check(hero.animation == "walk_right", "%s faces movement" % hero_id)
		hero.play_death()
		hero._process(0.4)
		_check(hero.modulate.a < 0.5, "%s death visibly fades" % hero_id)
		hero.play_idle()
		_check(is_equal_approx(hero.modulate.a, 1.0), "%s recovery restores visibility" % hero_id)
		hero.queue_free()
	var monster_texture := load(MonsterSpriteFactory.BRIGHT_ATLAS) as Texture2D
	_check_atlas(monster_texture, "monsters")
	for monster_name in MonsterSpriteFactory.BRIGHT_COLUMNS:
		var monster := MonsterSpriteFactory.create_monster(monster_name, Vector2.ONE * MonsterSpriteFactory.BATTLEFIELD_SCALE)
		holder.add_child(monster)
		var column: int = MonsterSpriteFactory.BRIGHT_COLUMNS[monster_name]
		# v32 replaces the six legacy bright monsters with the matching four-pose
		# pixel atlas. Dedicated v32 checks cover all sixteen new source mappings.
		_check(monster.sheet_layout == "pixel_v32", "%s uses the upgraded pixel atlas" % monster_name)
		_check(absf(monster.get_visual_height() - MonsterSpriteFactory.BRIGHT_HEIGHTS[column]) < 0.01, "%s battlefield size" % monster_name)
		_check(monster.get_foot_offset() == Vector2.ZERO, "%s feet origin" % monster_name)
		_check_actor_frames(monster, monster_name)
		monster.play_walk(Vector2.LEFT)
		_check(monster.flip_h and monster.animation == "walk_left", "%s left-facing flip" % monster_name)
		monster.play_walk(Vector2.RIGHT)
		_check(not monster.flip_h, "%s right-facing restoration" % monster_name)
		monster.play_death()
		monster._process(0.4)
		_check(monster.modulate.a < 0.5, "%s death visibly fades" % monster_name)
		monster.play_idle()
		_check(is_equal_approx(monster.modulate.a, 1.0), "%s recovery restores visibility" % monster_name)
		monster.queue_free()
	var legacy_hero := HeroSpriteFactory.create_hero("elisia", Vector2.ONE * HeroSpriteFactory.BATTLEFIELD_SCALE)
	_check(absf(legacy_hero.get_visual_height() - 40.0) < 0.01, "legacy hero uses the same battlefield scale")
	legacy_hero.free()
	for legacy_name in ["바람 까마귀", "초원왕 그룬"]:
		var boss: bool = legacy_name == "초원왕 그룬"
		var legacy := MonsterSpriteFactory.create_monster(legacy_name, Vector2.ONE * (0.07 if boss else 0.09))
		_check(absf(legacy.get_visual_height() - (100.0 if boss else 44.0)) < 0.01, "%s legacy scale" % legacy_name)
		legacy.free()
	await process_frame
	holder.queue_free()
	print("v28_bright_sprite_smoke_test_ok checks=%d frames=104 failures=%d" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func _check_atlas(texture: Texture2D, key: String) -> void:
	var source := texture.get_image()
	if source.is_compressed():
		source.decompress()
	var regions: Array = BrightSpriteAtlasLayout.REGIONS[key]
	for index in regions.size():
		var region: Rect2i = regions[index]
		_check(Rect2i(Vector2i.ZERO, source.get_size()).encloses(region), "%s frame %d inside source" % [key, index])
		var crop := source.get_region(region)
		var max_edge_alpha := 0.0
		for x in crop.get_width():
			max_edge_alpha = maxf(max_edge_alpha, maxf(crop.get_pixel(x, 0).a, crop.get_pixel(x, crop.get_height() - 1).a))
		for y in crop.get_height():
			max_edge_alpha = maxf(max_edge_alpha, maxf(crop.get_pixel(0, y).a, crop.get_pixel(crop.get_width() - 1, y).a))
		_check(max_edge_alpha <= 0.04, "%s frame %d does not cut opaque weapon, hair or feet" % [key, index])
		_check(crop.get_used_rect().get_area() > 15000, "%s frame %d contains real artwork" % [key, index])
		var frame := BrightSpriteAtlasLayout.frame_texture(texture, key, index, index % 6 if key == "monsters" else -1)
		_check(frame.get_size() == BrightSpriteAtlasLayout.canvas_size(key, index % 6 if key == "monsters" else -1), "%s frame %d shares a stable animation canvas" % [key, index])
		_check(is_equal_approx(frame.margin.position.y + frame.region.size.y, frame.get_height() - 2.0), "%s frame %d aligns to feet" % [key, index])
		for other in range(index):
			if region.intersects(regions[other]):
				_check(false, "%s frame %d overlaps another actor" % [key, index])

func _check_actor_frames(actor: AnimatedSprite2D, actor_name: String) -> void:
	var frames := actor.sprite_frames
	for animation_name in frames.get_animation_names():
		for frame_index in frames.get_frame_count(animation_name):
			var atlas := frames.get_frame_texture(animation_name, frame_index) as AtlasTexture
			var rendered_height: float = (atlas.region.size.y - 6.0) * absf(actor.scale.y)
			_check(rendered_height >= 28.0 and rendered_height <= 51.0, "%s %s frame %d stays at compact battlefield scale" % [actor_name, animation_name, frame_index])
	for direction in ["down", "right", "up", "left"]:
		_check(frames.get_frame_count("idle_%s" % direction) == 1, "%s %s idle artwork" % [actor_name, direction])
		_check(frames.get_frame_count("walk_%s" % direction) == 2, "%s %s walk has two actual frames" % [actor_name, direction])
		var first := frames.get_frame_texture("walk_%s" % direction, 0) as AtlasTexture
		var second := frames.get_frame_texture("walk_%s" % direction, 1) as AtlasTexture
		_check(first.region != second.region, "%s %s walk changes artwork" % [actor_name, direction])
		var attack := frames.get_frame_texture("attack_%s" % direction, 1) as AtlasTexture
		_check(attack.region != first.region and attack.region != second.region, "%s %s attack has a dedicated pose" % [actor_name, direction])
		_check(not frames.get_animation_loop("death_%s" % direction), "%s %s death does not loop" % [actor_name, direction])
