extends SceneTree

## Source-pixel, live asset routing and geometry checks. Headless execution is
## not a rendered screenshot review or a measurement of GPU shader quality.
const FIELD = preload("res://scripts/maps/FieldArtCatalog.gd")
const ROSTER = preload("res://scripts/heroes/HeroRosterCatalog.gd")
const EQUIPMENT = preload("res://scripts/equipment/EquipmentArtCatalog.gd")
const PIXEL_FX = preload("res://scripts/art/PixelFxAtlas.gd")
const MONSTER_ART = preload("res://scripts/monsters/MonsterPixelAtlasLayout.gd")
const PIXEL_PIPELINE = preload("res://scripts/art/PixelArtPipeline.gd")
var checks := 0
var failures: Array[String] = []
var report := {"rendered_screenshot":false, "worlds":[], "monsters":[], "heroes":[], "items":[], "vfx":[]}
var _source_images: Dictionary = {}
var _monster_actions: Dictionary = {}

func _init() -> void:
	_run.call_deferred()

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)

func _image(texture: Texture2D) -> Image:
	if texture == null: return null
	var key := texture.get_instance_id()
	if _source_images.has(key): return _source_images[key]
	var image := texture.get_image()
	if image != null and image.is_compressed(): image.decompress()
	_source_images[key] = image
	return image

func _digest(image: Image) -> String:
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(image.get_data())
	return hash.finish().hex_encode()

func _atlas_image(texture: Texture2D, context: String) -> Image:
	_check(texture is AtlasTexture, context + " uses a declared source region")
	if not texture is AtlasTexture: return null
	var atlas := texture as AtlasTexture
	_check(atlas.atlas != null and atlas.filter_clip, context + " clips sampling to its atlas region")
	var source := _image(atlas.atlas)
	if source == null:
		_check(false, context + " has readable source pixels")
		return null
	var region := Rect2i(atlas.region)
	var valid := region.has_area() and Rect2i(Vector2i.ZERO, source.get_size()).encloses(region)
	_check(valid, context + " crop stays inside the PNG")
	if not valid: return null
	var crop := source.get_region(region)
	_check(crop.get_used_rect().get_area() > 100, context + " contains artwork")
	return crop

func _edge_alpha(image: Image) -> float:
	var alpha := 0.0
	for x in image.get_width():
		alpha = maxf(alpha, maxf(image.get_pixel(x, 0).a, image.get_pixel(x, image.get_height() - 1).a))
	for y in image.get_height():
		alpha = maxf(alpha, maxf(image.get_pixel(0, y).a, image.get_pixel(image.get_width() - 1, y).a))
	return alpha

func _monster_finished(action: String, monster_name: String) -> void:
	var key := monster_name + "/" + action
	_monster_actions[key] = int(_monster_actions.get(key, 0)) + 1

func _test_actors() -> void:
	var holder := Node2D.new()
	root.add_child(holder)
	var material := PIXEL_PIPELINE.actor_material()
	_check(material != null and material.shader != null, "shared actor pixel material loads")
	for hero_id in ROSTER.HEROES:
		var hero := HeroSpriteFactory.create_hero(hero_id, Vector2.ONE * HeroSpriteFactory.BATTLEFIELD_SCALE)
		holder.add_child(hero)
		# v36-v42 replaced live hero pixel shaders/sheets with approved SD actions.
		# The current-route lifecycle is covered by V46CurrentAssetsSmokeTest.
		_check(hero._frames_ready and hero.sprite_frames != null, hero_id + " current action frames load")
		_check(hero.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR, hero_id + " current SD sampling")
		var portrait: Texture2D = HeroVisualCatalog.portrait_texture(hero_id)
		_check(portrait != null and portrait == preload("res://scripts/sd/SDHeroVisuals.gd").portrait(hero_id), hero_id + " portrait uses current approved SD artwork")
		for slot in ["a1", "a2", "passive", "ultimate"]:
			var icon: Texture2D = HeroVisualCatalog.skill_texture(hero_id, slot)
			_check(icon is AtlasTexture and (icon as AtlasTexture).atlas.resource_path.begins_with("res://assets/heroes/pixel-v32/"), hero_id + "/" + slot + " icon actually uses v32 artwork")
		report["heroes"].append({"id":hero_id,"layout":hero.sheet_layout,"pixel_material":hero.material == material})
		hero.free()
	_check(MONSTER_ART.PROFILES.size() == 16 and MonsterSpriteFactory.MONSTER_SPRITES.size() == 16, "all sixteen canonical monster identities remain present")
	var actors: Dictionary = {}
	var source_regions: Dictionary = {}
	var pose_hashes: Dictionary = {}
	for monster_name in MonsterSpriteFactory.MONSTER_SPRITES:
		_check(MONSTER_ART.has_monster(monster_name), monster_name + " has a v32 atlas profile")
		if not MONSTER_ART.has_monster(monster_name): continue
		var profile: Dictionary = MONSTER_ART.PROFILES[monster_name]
		var actor := MonsterSpriteFactory.create_monster(monster_name, Vector2.ONE * float(profile["reference_scale"]))
		holder.add_child(actor)
		actor.set_process(false)
		actors[monster_name] = actor
		_check(actor.sheet_layout == "pixel_v32" and actor.sprite_sheet.resource_path == MONSTER_ART.sheet_path(monster_name), monster_name + " factory selects its actual v32 source")
		_check(actor.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, monster_name + " keeps nearest pixel sampling")
		_check(actor.material is ShaderMaterial and is_equal_approx(float((actor.material as ShaderMaterial).get_shader_parameter("alpha_cutoff")), 0.5), monster_name + " explicitly renders a crisp source-alpha silhouette")
		_check(absf(actor.get_visual_height() - float(profile["target_height"])) < 0.01, monster_name + " retains its original compact field size")
		_check(actor.get_foot_offset() == Vector2.ZERO, monster_name + " retains a shared foot origin")
		var source := _image(actor.sprite_sheet)
		_check(source != null and source.detect_alpha() != Image.ALPHA_NONE, monster_name + " source background is genuinely transparent")
		var path: String = MONSTER_ART.sheet_path(monster_name)
		if not source_regions.has(path): source_regions[path] = []
		for pose in range(4):
			var frame: AtlasTexture = MONSTER_ART.frame_texture(actor.sprite_sheet, monster_name, pose)
			var context := "%s pose %d" % [monster_name, pose]
			var crop := _atlas_image(frame, context)
			if crop == null: continue
			# v32 monster material discards source alpha below .5 before applying
			# modulation. Those authoring fringes are not rendered; opaque artwork
			# must still be complete and cannot be hidden by this test threshold.
			var edge := _edge_alpha(crop)
			_check(edge < 0.5, context + " does not cut rendered sprite edges")
			var digest := _digest(crop)
			_check(not pose_hashes.has(digest), context + " is a distinct authored pose")
			pose_hashes[digest] = context
			var index: int = MONSTER_ART.pose_index(monster_name, pose)
			var pivot: Vector2 = MONSTER_ART.PIVOTS[profile["sheet"]][index]
			var foot := (actor.offset + frame.margin.position + pivot - frame.region.position) * actor.scale
			_check(foot.length() < 0.01, context + " aligns its declared feet to the actor origin")
			_check(frame.get_size() == MONSTER_ART.canvas_size(monster_name), context + " has a stable shared animation canvas")
			for other in source_regions[path]:
				var overlap := Rect2i(frame.region).intersection(other)
				var alpha := 0.0
				if overlap.has_area():
					for y in range(overlap.position.y, overlap.end.y):
						for x in range(overlap.position.x, overlap.end.x):
							alpha = maxf(alpha, source.get_pixel(x, y).a)
				_check(alpha < 0.5, context + " never mixes rendered pixels from an adjacent source pose")
			source_regions[path].append(Rect2i(frame.region))
		var frames := actor.sprite_frames
		for direction in ["down", "left", "right", "up"]:
			for state in ["idle", "walk", "attack", "hit", "death"]:
				var animation: String = state + "_" + direction
				_check(frames.has_animation(animation) and frames.get_frame_count(animation) >= 1, monster_name + " has " + animation)
				_check(frames.get_animation_loop(animation) == (state in ["idle", "walk"]), monster_name + " only idle/walk loop")
			var first := frames.get_frame_texture("walk_" + direction, 0) as AtlasTexture
			var second := frames.get_frame_texture("walk_" + direction, 1) as AtlasTexture
			var attack := frames.get_frame_texture("attack_" + direction, 1) as AtlasTexture
			_check(first != null and second != null and attack != null and first.region != second.region and attack.region != first.region and attack.region != second.region, monster_name + " has two walking poses and a dedicated attack")
		actor.play_walk(Vector2.LEFT)
		_check(actor.flip_h and actor.animation == "walk_left", monster_name + " faces actual leftward movement")
		actor.play_walk(Vector2.RIGHT)
		_check(not actor.flip_h, monster_name + " restores rightward facing")
		actor.action_finished.connect(_monster_finished.bind(monster_name))
		actor.play_attack("right")
		report["monsters"].append({"name":monster_name,"path":path,"field_height":actor.get_visual_height(),"poses":4})
	_check(pose_hashes.size() == 64 and source_regions.size() == 3, "three monster sources provide sixty-four distinct poses")
	await create_timer(0.42).timeout
	for monster_name in actors:
		var actor: MonsterSpriteController = actors[monster_name]
		_check(actor.state == "idle" and int(_monster_actions.get(monster_name + "/attack", 0)) == 1, monster_name + " attack finishes once and returns to idle")
		actor.play_death()
		actor._process(0.2)
		var alpha := actor.modulate.a
		_check(alpha < 0.95, monster_name + " death visibly begins fading")
		actor.speed_scale = 0.0
		actor._process(0.3)
		_check(is_equal_approx(actor.modulate.a, alpha), monster_name + " paused death does not continue fading")
		actor.speed_scale = 1.0
		actor._process(0.4)
		_check(actor.state == "death" and actor.modulate.a < 0.4, monster_name + " resumed death stays dead")
		actor.play_idle()
		_check(actor.state == "idle" and is_equal_approx(actor.modulate.a, 1.0), monster_name + " explicit revival restores visible idle")
	holder.free()

func _test_worlds() -> void:
	var renderer := MapTerrainRenderer.new()
	renderer.size = Vector2(1224, 470)
	root.add_child(renderer)
	renderer.set_process(false)
	_check(renderer.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "field keeps nearest-neighbor pixel sampling")
	_check(renderer.clip_contents, "field artwork cannot bleed into HUD")
	_check(is_equal_approx(renderer.MOOD_BRIGHTNESS, 0.90) and is_equal_approx(renderer.MOOD_SATURATION, 0.88), "field keeps the user's reduced-brightness mood")
	var digests: Dictionary = {}
	for zone in ["gray_meadow", "forgotten_mine", "moonrest_forest"]:
		var path: String = FIELD.texture_path(zone)
		var texture: Texture2D = FIELD.texture_for(zone)
		_check(path.begins_with("res://assets/terrain-v70/") and texture != null, zone + " loads its upgraded world texture")
		if texture == null: continue
		var image := _image(texture)
		_check(image != null and image.get_width() >= 768 and image.get_height() >= 512, zone + " has a populated detailed source")
		if image == null: continue
		var digest := _digest(image)
		_check(not digests.has(digest), zone + " has unique environment artwork")
		digests[digest] = zone
		var uv: Rect2 = FIELD.source_uv(zone)
		_check(uv.has_area() and Rect2(0, 0, 1, 1).encloses(uv), zone + " runtime UV crop stays in the source")
		if zone == "gray_meadow":
			_check(uv == Rect2(0, 0, 1, 1), "meadow preserves the existing obstacle projection")
		else:
			_check(uv.position.x > 0 and uv.position.y > 0 and uv.end.x < 1 and uv.end.y < 1, zone + " keeps decorative perimeter outside its open navigation field")
		renderer.configure(zone, Color.WHITE)
		_check(renderer.field_texture == texture, zone + " is actually selected by the runtime renderer")
		var all_art: Rect2 = renderer.source_rect_for_world(renderer.art_world_rect())
		_check(all_art.position.length() < 0.001 and all_art.size.distance_to(texture.get_size()) < 0.001, zone + " decorative world perimeter maps to the whole source")
		var navigation_source: Rect2 = renderer.source_rect_for_world(Rect2(Vector2.ZERO, renderer.WORLD_SIZE))
		_check(navigation_source.position.distance_to(texture.get_size() * uv.position) < 0.001 and navigation_source.size.distance_to(texture.get_size() * uv.size) < 0.001, zone + " walkable world retains its inner-source mapping")
		for width in [720, 1224, 1536]:
			renderer.size = Vector2(width, 470)
			renderer.configure_world_view(61.333333, Vector2(width * 0.5, 239.2))
			for camera in [Vector2(1, 1), Vector2(16, 10), Vector2(31, 19)]:
				renderer.set_camera_position(camera)
				for point in [Vector2(0, 0), Vector2(16, 10), Vector2(32, 20)]:
					_check(renderer.local_to_world(renderer._map_point(point)).distance_to(point) < 0.0001, zone + " camera projection remains invertible")
				var visible: Rect2 = renderer.visible_world_rect().intersection(renderer.art_world_rect())
				var source: Rect2 = renderer.source_rect_for_world(visible)
				_check(Rect2(Vector2.ZERO, texture.get_size()).grow(0.01).encloses(source), zone + " resized camera only samples valid source pixels")
		report["worlds"].append({"zone":zone,"path":path,"size":[image.get_width(),image.get_height()],"uv":[uv.position.x,uv.position.y,uv.size.x,uv.size.y]})
	var camp: Texture2D = FIELD.camp_texture()
	_check(camp != null and FIELD.camp_texture_path().begins_with("res://assets/terrain-v70/"), "camp resolves the upgraded village artwork")
	if camp != null:
		var image := _image(camp)
		_check(image != null and not digests.has(_digest(image)), "camp is distinct from the three hunting regions")
	renderer.free()

func _test_items_and_fx() -> void:
	var icon_hashes: Dictionary = {}
	_check(EQUIPMENT.cell_texture(-1) == null and EQUIPMENT.cell_texture(12) == null, "invalid equipment cells are not remapped to unrelated art")
	for index in range(12):
		var texture: Texture2D = EQUIPMENT.cell_texture(index)
		var crop := _atlas_image(texture, "equipment cell %d" % index)
		if crop == null: continue
		var digest := _digest(crop)
		_check(not icon_hashes.has(digest), "equipment cell %d is unique artwork" % index)
		icon_hashes[digest] = index
		report["items"].append({"cell":index,"region":str((texture as AtlasTexture).region)})
	_check(icon_hashes.size() == 12, "all twelve authored equipment icon cells are present")
	for item_name in EQUIPMENT.ITEM_CELLS:
		var item := {"name":item_name}
		_check(EQUIPMENT.texture_for(item) == EQUIPMENT.cell_texture(EQUIPMENT.ITEM_CELLS[item_name]), item_name + " resolves its own illustration")
	for slot in ["weapon", "armor", "accessory"]:
		for rarity in ["일반", "희귀", "전설"]:
			_check(EQUIPMENT.texture_for({"name":"legacy item", "slot":slot, "rarity":rarity}) != null, slot + "/" + rarity + " keeps old-save inventory artwork")
	var fx_hashes: Dictionary = {}
	_check(PIXEL_FX.frame_texture("unknown_effect", 0) == null, "unknown VFX never becomes a different elemental spell")
	for effect in PIXEL_FX.EFFECT_ROWS:
		var regions: Array[Rect2] = []
		for index in range(4):
			var texture: Texture2D = PIXEL_FX.frame_texture(effect, index)
			var crop := _atlas_image(texture, "%s frame %d" % [effect, index])
			if crop == null: continue
			var atlas := texture as AtlasTexture
			_check(atlas.region.position == atlas.region.position.floor() and atlas.region.size == atlas.region.size.floor(), "%s frame %d uses exact source pixels" % [effect, index])
			_check(crop.detect_alpha() != Image.ALPHA_NONE, "%s frame %d has a transparent background" % [effect, index])
			var border_alpha := 0.0
			for x in crop.get_width():
				border_alpha = maxf(border_alpha, maxf(crop.get_pixel(x, 0).a, crop.get_pixel(x, crop.get_height() - 1).a))
			for y in crop.get_height():
				border_alpha = maxf(border_alpha, maxf(crop.get_pixel(0, y).a, crop.get_pixel(crop.get_width() - 1, y).a))
			_check(border_alpha <= 0.04, "%s frame %d keeps the entire burst inside its cell" % [effect, index])
			var digest := _digest(crop)
			_check(not fx_hashes.has(digest), "%s frame %d has a unique animation pose" % [effect, index])
			fx_hashes[digest] = true
			for other in regions:
				_check(not atlas.region.intersects(other), "%s frame %d does not sample adjacent frames" % [effect, index])
			regions.append(atlas.region)
			report["vfx"].append({"effect":effect,"frame":index,"region":str(atlas.region)})
	_check(fx_hashes.size() == 16, "four authored effects each retain four distinct frames")
	for hero_id in ROSTER.HEROES:
		for mode in ["enemy", "heal", "shield", "buff", "guard"]:
			_check(PIXEL_FX.effect_for(hero_id, "passive", mode).is_empty(), hero_id + " passive never acquires an invented elemental burst")
	_check(PIXEL_FX.effect_for("caelum", "a1", "enemy") == "solar_flare", "solar burst is attached to Caelum's actual enemy recipient")
	_check(PIXEL_FX.effect_for("tessa", "ultimate", "enemy") == "rune_spark", "rune burst is attached to Tessa's actual enemy recipient")
	_check(PIXEL_FX.effect_for("elisia", "a2", "heal") == "leaf_heal", "healing burst is attached to Elisia's actual heal recipient")
	_check(PIXEL_FX.effect_for("selene", "a1", "shield") == "ruby_shield", "ruby burst is attached to Selene's actual shield recipient")
	_check(PIXEL_FX.effect_for("bora", "ultimate", "enemy").is_empty(), "Bora gains no invented freezing effect")
	_check(PIXEL_FX.effect_for("elisia", "a1", "enemy").is_empty() and PIXEL_FX.effect_for("selene", "a1", "enemy").is_empty(), "support raster bursts cannot appear on enemies")

func _descendants(node: Node) -> Array[Node]:
	var result: Array[Node] = []
	for child in node.get_children():
		result.append(child)
		result.append_array(_descendants(child))
	return result

func _test_live_screens() -> void:
	root.content_scale_size = Vector2i(1280, 720)
	root.size = Vector2i(1280, 720)
	var main = preload("res://scenes/Main.tscn").instantiate()
	main.save_state_path = "user://v32-graphics-smoke.json"
	main._offline_checked = true
	root.add_child(main)
	await process_frame
	main.set_process(false)
	main.set_physics_process(false)
	main.selected_faction = "aurelia"
	main.idle_stage = 8
	main._restore_deployed_heroes(["leonhardt", "mira", "kairen"])
	main._setup_hero_progress(main._hero_roster_for_faction())
	for build_method in ["_build_title_screen", "_build_login_screen"]:
		main.call(build_method)
		await process_frame
		var has_camp := false
		for node in _descendants(main.content_root):
			if node is TextureRect and node.texture != null and node.texture.resource_path == FIELD.camp_texture_path():
				has_camp = true
				_check(node.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, build_method + " camp uses pixel sampling")
		_check(has_camp, build_method + " actually displays the upgraded village")
	for zone in ["gray_meadow", "forgotten_mine", "moonrest_forest"]:
		main.current_zone_id = zone
		main._build_lobby_screen()
		await process_frame
		var has_zone := false
		for node in _descendants(main.content_root):
			if node is TextureRect and node.texture != null and node.texture.resource_path == FIELD.texture_path(zone):
				has_zone = true
		_check(has_zone, "live lobby displays the selected " + zone + " background")
		main._build_combat_screen()
		await process_frame
		if is_instance_valid(main.combat_timer): main.combat_timer.stop()
		var terrain: MapTerrainRenderer = main.combat_labels.get("terrain")
		_check(is_instance_valid(terrain) and terrain.field_texture == FIELD.texture_for(zone), "live hunt displays the selected " + zone + " artwork")
		if not is_instance_valid(terrain): continue
		var map_scale: Vector2 = main._combat_map_scale()
		var anchor: Vector2 = main._combat_camera_anchor() - main.combat_field_rect.position
		var before := anchor / map_scale
		var after: Vector2 = (main.combat_field_rect.size - anchor) / map_scale
		var art_bounds: Rect2 = FIELD.world_art_rect(zone, RoamingHuntDirector.WORLD_SIZE)
		for requested in [Vector2(-100, -100), Vector2(0, 0), Vector2(16, 10), Vector2(32, 20), Vector2(100, 100)]:
			var camera: Vector2 = main._clamp_combat_camera(requested)
			var viewport_world := Rect2(camera - before, before + after)
			_check(art_bounds.grow(0.0001).encloses(viewport_world), zone + " actual Main camera never exposes missing world pixels")
			if zone == "gray_meadow":
				_check(camera.distance_to(requested.clamp(before, RoamingHuntDirector.WORLD_SIZE - after)) < 0.0001, "meadow camera retains its original world clamp")
			main.combat_camera_position = camera
			main._update_combat_camera(0.0)
			for point in [Vector2(0, 0), Vector2(16, 10), Vector2(32, 20)]:
				var actor_point: Vector2 = main._map_world_position(point)
				var ground_point: Vector2 = main.combat_field_rect.position + terrain._map_point(point)
				_check(actor_point.distance_to(ground_point) < 0.001, zone + " live actors remain anchored to the same world artwork")
		_check(main.field_navigation.is_walkable(Vector2(6.9, 3.6)) == (zone != "gray_meadow"), zone + " cosmetic perimeter does not change navigation rules")
		main._build_raid_screen()
		await process_frame
		var boss: MonsterSpriteController = main.raid_boss_sprite
		var boss_name: String = main._current_zone()["boss"]
		_check(is_instance_valid(boss) and boss.sheet_layout == "pixel_v32" and boss.sprite_sheet.resource_path == MONSTER_ART.sheet_path(boss_name), boss_name + " raid portrait update keeps the new atlas")
		if is_instance_valid(boss):
			_check(absf(boss.get_visual_height() - 150.0) < 0.01, boss_name + " raid portrait preserves its existing readable scale")
		var boss_texture: Texture2D = main._boss_texture(boss_name)
		_check(boss_texture is AtlasTexture and (boss_texture as AtlasTexture).atlas.resource_path == MONSTER_ART.sheet_path(boss_name), boss_name + " legacy boss helper resolves the new source")
	for monster_name in MONSTER_ART.PROFILES:
		var texture: Texture2D = main._monster_texture(monster_name)
		_check(texture is AtlasTexture and (texture as AtlasTexture).atlas.resource_path == MONSTER_ART.sheet_path(monster_name), monster_name + " legacy monster helper resolves the new source")
	main.loot_inventory = []
	for item_name in EQUIPMENT.ITEM_CELLS:
		var cell := int(EQUIPMENT.ITEM_CELLS[item_name])
		var slot := "armor" if cell in [4, 5, 6, 7] else ("accessory" if cell in [8, 9, 10] else "weapon")
		main.loot_inventory.append({"id":"v32_art_%d" % cell,"name":item_name,"slot":slot,"rarity":"일반","level":1,"power":8})
	main._build_inventory_screen()
	await process_frame
	var cells: Dictionary = {}
	for node in _descendants(main.content_root):
		if not node is TextureRect or node.name != "EquipmentArt": continue
		var cell := int(node.get_meta("equipment_art_cell", -1))
		_check(cell >= 0 and node.texture == EQUIPMENT.cell_texture(cell), "live inventory renders the exact equipment icon")
		_check(node.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST and node.mouse_filter == Control.MOUSE_FILTER_IGNORE, "equipment artwork stays sharp and cannot intercept item actions")
		cells[cell] = true
	_check(cells.size() == EQUIPMENT.ITEM_CELLS.size(), "every mapped item appears in a real inventory row")
	main.free()

func _run() -> void:
	_test_worlds()
	_test_items_and_fx()
	await _test_actors()
	await _test_live_screens()
	_finish()

func _finish() -> void:
	report["checks"] = checks
	report["failures"] = failures
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):
			var file := FileAccess.open(arg.trim_prefix("--report="), FileAccess.WRITE)
			if file != null: file.store_string(JSON.stringify(report, "\t"))
	print("v32_graphics checks=%d failures=%d" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
