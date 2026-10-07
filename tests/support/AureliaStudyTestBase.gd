extends SceneTree
## Run in a disposable XDG_DATA_HOME whose path contains `art-pilot`.
## Existing production save files are never replaced by this diagnostic.
const PILOT_SCENE := "res://scenes/art/ArtDirectionLab.tscn"
const INVASION := preload("res://scripts/hunting/InvasionHuntDirector.gd")
const REPORT := preload("res://scripts/raid/RaidReportArchive.gd")
const SIDES := ["east", "west", "north", "south", "northeast", "southwest", "northwest", "southeast"]
var checks := 0
var failures: Array[String] = []
var protected: Dictionary = {}
var direction_results: Array[Dictionary] = []
var startup_runtime: Dictionary = {}

func _init() -> void:
	run.call_deferred()


func check(ok: bool, note: String) -> void:
	checks += 1
	if not ok:
		failures.append(note)
		push_error(note)


func settle(frames := 8) -> void:
	for i in frames: await process_frame


func pointer_click(target: Button) -> void:
	check(target != null and target.is_visible_in_tree() and not target.disabled, "pointer target is available: " + str(target.name if target != null else "missing"))
	if target == null: return
	var viewport_point: Vector2 = target.get_global_transform_with_canvas() * (target.size * 0.5)
	var physical_point: Vector2 = root.get_final_transform() * viewport_point
	check(root.get_final_transform().affine_inverse() * physical_point == viewport_point, "physical pointer uses the actual viewport transform: " + str(target.name))
	var motion := InputEventMouseMotion.new()
	motion.position = physical_point
	motion.global_position = physical_point
	Input.parse_input_event(motion)
	await process_frame
	var hovered := root.gui_get_hovered_control()
	check(hovered == target, "pointer hit reaches visible button: " + str(target.name) + " (hovered " + str(hovered.get_path() if hovered != null else "nothing") + ")")
	for down: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = physical_point
		event.global_position = physical_point
		event.button_index = MOUSE_BUTTON_LEFT
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
		event.pressed = down
		Input.parse_input_event(event)
		await process_frame
	await settle()


func prepare_sentinels() -> bool:
	var user_dir := ProjectSettings.globalize_path("user://")
	if not user_dir.contains("art-pilot"):
		check(false, "diagnostic requires an isolated art-pilot XDG_DATA_HOME")
		return false
	for base: String in ["user://pixel_war_save.json", PresentationSettings.PATH, REPORT.PATH]:
		for suffix: String in ["", ".bak", ".tmp", ".bak.tmp", ".corrupt"]:
			if FileAccess.file_exists(base + suffix):
				check(false, "refuse to replace pre-existing save fixture: " + base + suffix)
				return false
	var sentinel := {"selected_faction": "noxfera", "current_zone_id": "forgotten_mine",
		"idle_stage": 73, "wallet_gold": 987654, "deployed_hero_ids": [],
		"last_idle_timestamp": int(Time.get_unix_time_from_system())}
	var store := SaveStore.new()
	check(bool(store.write_save("user://pixel_war_save.json", sentinel).get("ok", false)), "production sentinel writes successfully")
	check(PresentationSettings.save_preferences(false, false, {"music_volume": 0.13, "performance": "battery"}) == OK, "production config sentinel writes successfully")
	var report_file := FileAccess.open(REPORT.PATH, FileAccess.WRITE)
	report_file.store_string('{"sentinel":"production-raid-archive-must-survive"}')
	report_file.close()
	for base: String in ["user://pixel_war_save.json", PresentationSettings.PATH, REPORT.PATH]:
		check(DirAccess.copy_absolute(ProjectSettings.globalize_path(base), ProjectSettings.globalize_path(base + ".bak")) == OK, "production backup sentinel writes: " + base)
		for suffix: String in ["", ".bak", ".tmp", ".bak.tmp", ".corrupt"]:
			var path := base + suffix
			protected[path] = FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "missing"
	return true


func check_sentinels(stage: String) -> void:
	for path: String in protected:
		var fingerprint := FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "missing"
		check(fingerprint == protected[path], stage + " preserves " + path)


func actor_alignment(game, update: bool) -> Dictionary:
	var field = game.combat_labels.terrain
	if update: field._process(0.1)
	var safe: Rect2 = Rect2(Vector2.ZERO,field.size).grow(0.6)
	var result := {"inside": true, "aligned": true, "samples": 0, "issues": [], "minimum_head_y": INF, "maximum_foot_y": -INF}
	var bodies: Array[Dictionary] = []
	for i in game.deployed_heroes.size():
		var id: String = str(game.deployed_heroes[i].id)
		if int(game.hero_battle_state.get(id, {}).get("hp", 0)) <= 0: continue
		bodies.append({"id": id, "point": game._hero_field_position(id), "sprite": game.hero_map_sprites[i], "hero": true})
	for i in game.enemy_wave.size():
		if int(game.enemy_wave[i].get("hp", 0)) <= 0: continue
		bodies.append({"id": "enemy_" + str(i), "point": game.roaming_hunt.enemy_position(i), "sprite": game.enemy_wave_sprites[i], "hero": false})
	for body: Dictionary in bodies:
		var point: Vector2 = body.point
		var height: float = field._actor_height(body.sprite, body.hero) + 0.6
		var foot: Vector2 = field.project_world(point)
		var head: Vector2 = field.project_world(point, height)
		result.minimum_head_y = minf(result.minimum_head_y, head.y)
		result.maximum_foot_y = maxf(result.maximum_foot_y, foot.y)
		result.samples += 2
		if not safe.has_point(foot) or not safe.has_point(head):
			result.inside = false
			if result.issues.size() < 4: result.issues.append({"id": body.id, "head": head, "foot": foot, "safe": safe})
		var billboard = field.actors.get(body.sprite.get_instance_id())
		if billboard == null:
			result.aligned = false
		else:
			result.aligned = result.aligned and Vector2(billboard.position.x, billboard.position.z).distance_to(point) < 0.001
			result.aligned = result.aligned and body.sprite.position.distance_to(field.position + foot) < 0.001
	return result


func gameplay_snapshot(game) -> Dictionary:
	return {"enemy_wave": game.enemy_wave.duplicate(true), "hero_states": game.hero_battle_state.duplicate(true),
		"hero_runtime": game.hero_skill_runtime.duplicate(true), "enemy_positions": game.roaming_hunt.enemy_positions.duplicate(),
		"party_position": game.party_movement.positions.duplicate(true), "encounter": game.hunt_ai.encounter_id,
		"invasion_clock": game.invasion.clock, "invasion_serial": game.invasion.serial,
		"rng": game.loot_rng.state, "gold": game.wallet_gold, "xp": game.wallet_xp,
		"stage": game.idle_stage, "hunt_cycle": game.combat_hunt_cycle}


func test_directions(game, test_zone := "gray_meadow") -> void:
	for serial in range(1, 9):
		game.current_zone_id = test_zone
		game.idle_stage = 1
		game.hero_progress["leonhardt"] = {"level": 35 if test_zone == "gray_meadow" else 100, "xp": 0}
		game.loot_rng.seed = 90217
		game._build_combat_screen()
		await settle()
		game.combat_running = true
		game.roaming_hunt.clear_enemies()
		game.roaming_hunt.append_corps(game.enemy_wave, serial)
		var entry: String = SIDES[serial - 1]
		var first_wave: Array = game.enemy_wave.duplicate()
		var first_positions: Array = game.roaming_hunt.enemy_positions.duplicate()
		check(not first_wave.is_empty(), entry + " has actual generated enemy stats")
		var centroid := Vector2.ZERO
		for point: Vector2 in first_positions: centroid += point
		centroid /= maxf(1.0, first_positions.size())
		var correct_edge := true
		if entry.contains("east"): correct_edge = correct_edge and centroid.x > 22.0
		if entry.contains("west"): correct_edge = correct_edge and centroid.x < 10.0
		if entry.contains("north"): correct_edge = correct_edge and centroid.y < 7.0
		if entry.contains("south"): correct_edge = correct_edge and centroid.y > 13.0
		check(correct_edge, entry + " actually spawns in the corresponding world quadrant")
		var all_entered := true
		for enemy: Dictionary in first_wave:
			all_entered = all_entered and str(enemy.get("entry_side", "")) == entry
		check(all_entered, entry + " positions every member at the selected entrance")
		var initial_hp := 0
		for enemy: Dictionary in first_wave: initial_hp += int(enemy.hp)
		var cycle: int = game.combat_hunt_cycle
		var steps := 0
		var maximum_alive := 0
		var maximum_groups := 0
		var approached := false
		var framing: Dictionary = actor_alignment(game, true)
		var all_visible: bool = framing.inside
		var all_aligned: bool = framing.aligned
		var screen_samples: int = framing.samples
		var framing_issues: Array = framing.issues.duplicate(true)
		while game.combat_hunt_cycle == cycle and steps < 1800:
			game._advance_auto_hunt(0.1)
			steps += 1
			if steps <= 10:
				for index in mini(first_positions.size(), game.roaming_hunt.enemy_positions.size()):
					var target: Vector2 = game._hero_field_position("leonhardt")
					approached = approached or game.roaming_hunt.enemy_position(index).distance_to(target) + 0.02 < first_positions[index].distance_to(target)
			maximum_alive = maxi(maximum_alive, game._enemy_wave_alive_count())
			maximum_groups = maxi(maximum_groups, game.invasion.groups.size())
			if steps % 10 == 0:
				framing = actor_alignment(game, true)
				all_visible = all_visible and framing.inside
				all_aligned = all_aligned and framing.aligned
				screen_samples += int(framing.samples)
				if framing_issues.is_empty() and not framing.inside: framing_issues = framing.issues.duplicate(true)
			if steps % 120 == 0: await process_frame
		var remaining_hp := 0
		for enemy: Dictionary in first_wave: remaining_hp += maxi(0, int(enemy.hp))
		check(remaining_hp < initial_hp, entry + " receives real combat HP damage")
		check(game.combat_hunt_cycle > cycle, entry + " naturally clears through the production reward loop")
		check(maximum_alive <= 25 and maximum_groups <= 2, entry + " respects normal invasion admission caps")
		check(approached, entry + " enemies move toward the party before the first clear")
		check(all_visible and screen_samples > 0, entry + " live heroes and enemies remain in the safe ground area throughout combat: " + str(framing_issues))
		check(all_aligned, entry + " moving billboards and combat anchors remain attached to their real world feet")
		var maximum_projection_error := 0.0
		var field = game.combat_labels.terrain
		for x in range(0, 33, 8):
			for y in range(0, 21, 5):
				var point := Vector2(x, y)
				maximum_projection_error = maxf(maximum_projection_error, point.distance_to(field.local_to_world(field.project_world(point))))
		check(maximum_projection_error < 0.001, entry + " camera movement preserves the complete field projection roundtrip")
		direction_results.append({"entrance": entry, "seconds": steps * 0.1,
			"removed_hp": initial_hp - remaining_hp, "initial_hp": initial_hp,
			"clears": game.combat_hunt_cycle - cycle, "maximum_alive": maximum_alive,
			"maximum_groups": maximum_groups, "screen_samples": screen_samples,
			"all_actor_points_inside_safe_area": all_visible, "world_render_alignment": all_aligned,
			"maximum_projection_error": maximum_projection_error})
		print("ART_PILOT_DIRECTION ", JSON.stringify(direction_results.back()))
	check_sentinels("eight entrances and automatic reward saves")


func finish() -> void:
	var result := {"checks": checks, "failures": failures, "directions": direction_results, "startup_runtime": startup_runtime,
		"scope": "Actual independent pilot scene; isolated progression, preferences and raid archive; live production hunt engine"}
	var out := FileAccess.open("user://art-pilot-results.json", FileAccess.WRITE)
	if out != null:
		out.store_string(JSON.stringify(result, "  "))
		out.close()
	print("art_direction_pilot checks=%d failures=%s" % [checks, JSON.stringify(failures)])
	quit(0 if failures.is_empty() else 1)

func run() -> void:pass
