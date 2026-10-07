extends SceneTree

## Validates the real imported textures and animation lifecycle without claiming
## a rendered screenshot review. Every canonical hero must have actual artwork.
const ROSTER = preload("res://scripts/heroes/HeroRosterCatalog.gd")
const SLOTS := ["a1", "a2", "passive", "ultimate"]
var checks := 0
var failures: Array[String] = []
var portraits: Dictionary = {}
var skill_images: Dictionary = {}
var skill_regions: Dictionary = {}
var source_images: Dictionary = {}
var action_counts: Dictionary = {}
var hero_reports: Array = []

func _init() -> void:
	_run.call_deferred()

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)

func _image(texture: Texture2D) -> Image:
	if texture == null: return null
	var key := str(texture.get_instance_id())
	if source_images.has(key): return source_images[key]
	var value := texture.get_image()
	if value != null and value.is_compressed(): value.decompress()
	source_images[key] = value
	return value

func _digest(image: Image) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(image.get_data())
	return context.finish().hex_encode()

func _texture_image(texture: Texture2D, context: String) -> Image:
	_check(texture != null, context + " texture exists")
	if texture == null: return null
	_check(texture.get_width() > 0 and texture.get_height() > 0, context + " texture has positive dimensions")
	if texture is AtlasTexture:
		var atlas := texture as AtlasTexture
		_check(atlas.atlas != null, context + " atlas source exists")
		if atlas.atlas == null: return null
		var source := _image(atlas.atlas)
		_check(source != null, context + " atlas pixels can be read")
		if source == null: return null
		var region := Rect2i(atlas.region)
		var valid := region.has_area() and Rect2i(Vector2i.ZERO, source.get_size()).encloses(region)
		_check(valid, context + " crop stays inside its source")
		return source.get_region(region) if valid else null
	return _image(texture)

func _check_catalog(catalog) -> void:
	_check(ROSTER.HEROES.size() == 30, "canonical roster remains thirty heroes")
	_check(not catalog.has_hero("missing_hero"), "unknown hero is not silently remapped")
	_check(catalog.portrait_texture("missing_hero") == null, "unknown portrait is absent")
	_check(catalog.skill_texture("missing_hero", "a1") == null, "unknown hero skill is absent")
	for id in ROSTER.HEROES:
		_check(catalog.has_hero(id), id + " has a visual catalog entry")
		var portrait: Texture2D = catalog.portrait_texture(id)
		var portrait_image := _texture_image(portrait, id + " portrait")
		if portrait_image != null:
			_check(portrait_image.get_used_rect().get_area() > 100, id + " portrait contains real artwork")
			var digest := _digest(portrait_image)
			_check(not portraits.has(digest), id + " portrait is not another hero's pixels")
			portraits[digest] = id
			var factory_image := _texture_image(HeroSpriteFactory.portrait_texture(id), id + " factory portrait")
			_check(factory_image != null and _digest(factory_image) == digest, id + " shared factory uses the catalog portrait")
		_check(catalog.skill_texture(id, "missing_slot") == null, id + " invalid skill slot is absent")
		for slot in SLOTS:
			var skill := ROSTER.skill(id, slot)
			_check(not skill.is_empty(), id + "/" + slot + " maps to a canonical skill")
			var design: Dictionary = catalog.skill_design(id, slot)
			_check(str(design.get("id", "")) == str(skill.get("id", "")) and str(design.get("name", "")) == str(skill.get("skill", "")), id + "/" + slot + " design ID and name match the implemented skill")
			var texture: Texture2D = catalog.skill_texture(id, slot)
			var context: String = id + "/" + slot
			var icon := _texture_image(texture, context)
			if icon == null: continue
			_check(icon.get_used_rect().get_area() > 100, context + " icon contains artwork")
			var digest := _digest(icon)
			_check(not skill_images.has(digest), context + " icon pixels are unique")
			skill_images[digest] = str(skill.get("id", context))
			if texture is AtlasTexture:
				var atlas := texture as AtlasTexture
				var key := atlas.atlas.resource_path
				if key.is_empty(): key = str(atlas.atlas.get_instance_id())
				if not skill_regions.has(key): skill_regions[key] = []
				for other in skill_regions[key]:
					_check(not atlas.region.intersects(other["region"]), context + " does not overlap " + str(other["skill"]))
				skill_regions[key].append({"region":atlas.region, "skill":context})
	_check(portraits.size() == 30, "all thirty portrait images are distinct")
	_check(skill_images.size() == 120, "all one hundred twenty skill icon images are distinct")

func _check_new_sheets() -> void:
	var paths: Dictionary = {}
	for id in ROSTER.HEROES:
		var path := HeroAnimationAtlas.sheet_path(id)
		_check(HeroAnimationAtlas.has_hero(id), id + " has a real new sprite-sheet resource")
		if not ResourceLoader.exists(path): continue
		if not paths.has(path): paths[path] = {"regions":[], "poses":{}, "heroes":[]}
		paths[path]["heroes"].append(id)
		var texture := load(path) as Texture2D
		var source := _image(texture)
		_check(source != null, path + " sprite pixels can be read")
		if source == null: continue
		_check(source.detect_alpha() != Image.ALPHA_NONE, path + " background is genuinely transparent")
		var layout := HeroAnimationAtlas.layout(texture, id)
		var regions: Array = layout.get("regions", [])
		_check(regions.size() == 4, id + " maps to exactly four authored field poses")
		for index in regions.size():
			var region: Rect2i = regions[index]
			var context := "%s pose=%d" % [id,index]
			var source_bounds := Rect2i(Vector2i.ZERO, source.get_size())
			_check(source_bounds.encloses(region), context + " source rectangle stays inside its PNG")
			if not source_bounds.encloses(region): continue
			var crop := source.get_region(region)
			_check(crop.get_used_rect().get_area() > 100, context + " is populated")
			for other in paths[path]["regions"]:
				var intersection := region.intersection(other)
				var overlap_alpha := 0.0
				if intersection.has_area():
					for y in range(intersection.position.y, intersection.end.y):
						for x in range(intersection.position.x, intersection.end.x):
							overlap_alpha = maxf(overlap_alpha, source.get_pixel(x,y).a)
				_check(overlap_alpha <= 0.04, context + " never includes visible pixels belonging to another source pose")
			paths[path]["regions"].append(region)
			# Irregular atlases may place separate poses beside one another with
			# no empty gutter. The independent pixel-coverage validator verifies
			# that every visible source pixel belongs to exactly one full pose.
			var digest := _digest(crop)
			_check(not paths[path]["poses"].has(digest), context + " is not a duplicate pose")
			paths[path]["poses"][digest] = true
	var total_poses := 0
	for path in paths:
		# v32 gives Kairen a dedicated source. The other four heroes still own
		# sixteen poses on a01; unused Kairen v31 pixels are never sampled.
		var expected: int = paths[path]["heroes"].size() * 4
		_check(paths[path]["poses"].size() == expected and paths[path]["regions"].size() == expected, path + " contains four unique populated poses per assigned hero")
		total_poses += paths[path]["regions"].size()
	_check(total_poses == 120, "all thirty concepts retain four distinct authored field poses")
	_check(paths.size() == 7, "six group atlases plus Kairen's v32 source cover thirty heroes")

func _finished(action: String, id: String) -> void:
	action_counts[id + "/" + action] = int(action_counts.get(id + "/" + action, 0)) + 1

func _check_frames(actor: HeroSpriteController, id: String) -> void:
	var frames := actor.sprite_frames
	_check(frames != null and actor.sprite_sheet != null, id + " has an actual field atlas")
	if frames == null or actor.sprite_sheet == null: return
	for child in actor.get_children():
		_check(not child is Polygon2D, id + " never uses a geometric fallback marker")
	_check(actor.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, id + " keeps pixel-art filtering")
	_check(absf(actor.get_visual_height() - 40.0) < 0.1, id + " starts at the forty-pixel battlefield scale")
	_check(actor.get_foot_offset() == Vector2.ZERO, id + " health bar uses a shared feet origin")
	var tested_regions: Dictionary = {}
	for direction in ["down", "right", "up", "left"]:
		for state in ["idle", "walk", "attack", "hit", "death"]:
			var name: String = state + "_" + direction
			_check(frames.has_animation(name), id + " has " + name)
			if not frames.has_animation(name): continue
			_check(frames.get_frame_count(name) >= 1, id + " has artwork for " + name)
			_check(frames.get_animation_loop(name) == (state in ["idle", "walk"]), id + " loops only idle and walking: " + name)
			for index in frames.get_frame_count(name):
				var texture := frames.get_frame_texture(name, index)
				_check(texture is AtlasTexture, id + "/" + name + " uses atlas artwork")
				if not texture is AtlasTexture: continue
				var atlas := texture as AtlasTexture
				var key := str(atlas.region)
				if tested_regions.has(key): continue
				tested_regions[key] = true
				var image := _texture_image(atlas, id + "/" + name)
				if image == null: continue
				var used := image.get_used_rect()
				_check(used.get_area() > 100, id + "/" + name + " contains visible sprite pixels")
				if actor.sheet_layout == "heroes_v31":
					var data := HeroAnimationAtlas.layout(actor.sprite_sheet, id)
					var region_index: int = data["regions"].find(Rect2i(atlas.region))
					_check(region_index >= 0, id + "/" + name + " uses a declared complete source pose")
					if region_index >= 0:
						var source_pivot: Vector2 = data["pivots"][region_index]
						var feet := (actor.offset + atlas.margin.position + source_pivot - atlas.region.position) * actor.scale
						_check(feet.length() <= 0.1, id + "/" + name + " authored foot pivot remains at the actor origin")
				else:
					var pixel_feet := (actor.offset.y + atlas.margin.position.y + used.end.y) * absf(actor.scale.y)
					_check(absf(pixel_feet) <= 1.5, id + "/" + name + " artwork aligns to feet within 1.5 pixels")
				var pixel_height := used.size.y * absf(actor.scale.y)
				_check(pixel_height >= 24.0 and pixel_height <= 70.0, id + "/" + name + " artwork stays readable without filling the field")
		var walking_a := frames.get_frame_texture("walk_" + direction, 0) as AtlasTexture
		var walking_b := frames.get_frame_texture("walk_" + direction, 1) as AtlasTexture
		_check(walking_a != null and walking_b != null and walking_a.region != walking_b.region, id + " walking changes artwork: " + direction)
		var attack := frames.get_frame_texture("attack_" + direction, 1) as AtlasTexture
		_check(attack != null and attack.region != walking_a.region and attack.region != walking_b.region, id + " attack has its own pose: " + direction)
	hero_reports.append({"id":id, "layout":actor.sheet_layout, "field_height":actor.get_visual_height(), "distinct_field_regions":tested_regions.size()})

func _run() -> void:
	var catalog = load("res://scripts/heroes/HeroVisualCatalog.gd")
	_check(catalog != null, "hero visual catalog loads")
	if catalog == null:
		_finish()
		return
	_check_catalog(catalog)
	_check_new_sheets()
	var holder := Node2D.new()
	root.add_child(holder)
	var actors: Dictionary = {}
	for id in ROSTER.HEROES:
		# Exercise the retained pixel fallback controller, independently of current SD routing.
		var actor := HeroSpriteController.new()
		actor.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var bright_path: String = HeroSpriteFactory.BRIGHT_SPRITES.get(id, "")
		if not bright_path.is_empty():
			actor.set_bright_sheet(load(bright_path), id)
		else:
			actor.set_animation_atlas(load(HeroAnimationAtlas.sheet_path(id)), id)
		actor.scale = Vector2.ONE * (40.0 / maxf(actor.native_visual_height, 1.0))
		holder.add_child(actor)
		actors[id] = actor
		_check_frames(actor, id)
		actor.action_finished.connect(_finished.bind(id))
		actor.play_walk(Vector2.RIGHT)
		_check(actor.animation == "walk_right", id + " faces actual movement")
		actor.play_attack("left")
		_check(actor.animation == "attack_left", id + " enters its attack pose")
	await create_timer(0.6).timeout
	for id in actors:
		var actor: HeroSpriteController = actors[id]
		_check(actor.state == "idle", id + " exits a completed attack")
		_check(int(action_counts.get(id + "/attack", 0)) == 1, id + " completes attack exactly once")
		actor.play_death()
	await create_timer(0.16).timeout
	var paused: Dictionary = {}
	for id in actors:
		var actor: HeroSpriteController = actors[id]
		_check(actor.modulate.a < 0.95, id + " death visibly starts fading")
		actor.speed_scale = 0.0
		paused[id] = [actor.modulate.a, actor.frame, actor.frame_progress]
	await create_timer(0.18).timeout
	for id in actors:
		var actor: HeroSpriteController = actors[id]
		_check(is_equal_approx(actor.modulate.a, paused[id][0]) and actor.frame == paused[id][1] and is_equal_approx(actor.frame_progress, paused[id][2]), id + " paused death freezes both animation and fading")
		actor.speed_scale = 1.0
	await create_timer(0.4).timeout
	for id in actors:
		var actor: HeroSpriteController = actors[id]
		_check(actor.state == "death" and actor.modulate.a < 0.4, id + " finished death never returns to idle on its own")
		actor.play_idle()
		_check(actor.state == "idle" and is_equal_approx(actor.modulate.a, 1.0), id + " explicit revival restores visible idle artwork")
		actor.play_hit()
	await create_timer(0.4).timeout
	for id in actors:
		var actor: HeroSpriteController = actors[id]
		_check(actor.state == "idle" and actor.self_modulate == Color.WHITE, id + " hit animation and flash settle safely")
		_check(int(action_counts.get(id + "/hit", 0)) == 1, id + " completes hit exactly once")
	holder.free()
	_finish()

func _finish() -> void:
	var report := {"checks":checks,"failures":failures,"heroes":hero_reports,"unique_portraits":portraits.size(),"unique_skill_icons":skill_images.size(),"rendered_screenshot":false}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):
			var file := FileAccess.open(arg.trim_prefix("--report="), FileAccess.WRITE)
			if file != null: file.store_string(JSON.stringify(report, "\t"))
	print("v31_hero_art checks=%d failures=%d heroes=%d portraits=%d skill_icons=%d" % [checks,failures.size(),hero_reports.size(),portraits.size(),skill_images.size()])
	quit(0 if failures.is_empty() else 1)
