extends SceneTree
## Exercise the actual portrait region selection, camera and auto-hunt together.
const CATALOG := preload("res://scripts/FieldTerrainCatalog.gd")
var checks: int = 0
var failures: Array[String] = []
var simulated_seconds: float = 0.0
var sampled_actor_moves: int = 0

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok:
		failures.append(detail)
		push_error("V67 terrain integration: " + detail)

func _settle() -> void:
	for _frame: int in range(4):
		await process_frame

func _check_camera(game: Node, terrain: Control, props: Node, zone: String) -> void:
	var camera_before: Vector2 = game.combat_camera_position
	for corner: Vector2 in [Vector2.ZERO, Vector2(32, 0), Vector2(0, 20), Vector2(32, 20)]:
		game.combat_camera_position = game._clamp_combat_camera(corner)
		game._update_combat_camera(0.0)
		props.refresh()
		var visible: Rect2 = terrain.visible_world_rect()
		var source: Rect2 = terrain.source_rect_for_world(visible)
		var texture_bounds: Rect2 = Rect2(Vector2.ZERO, terrain.field_texture.get_size())
		_check(terrain.art_world_rect().encloses(visible) and texture_bounds.grow(0.01).encloses(source), zone + " edge camera remains covered by painted ground " + str(corner))
		var aligned: bool = true
		for prop: Sprite2D in props.props:
			var world: Vector2 = prop.get_meta("world_position")
			var scenery_point: Vector2 = terrain.position + terrain._map_point(world)
			aligned = aligned and scenery_point.distance_to(game._map_world_position(world)) < 0.01
			aligned = aligned and prop.position.distance_to(scenery_point) < 0.01
		_check(aligned, zone + " terrain, obstacles and actors share edge camera projection " + str(corner))
	game.combat_camera_position = camera_before
	game._update_combat_camera(0.0)
	props.refresh()

func _simulate(game: Node, zone: String) -> void:
	var safe_heroes: bool = true
	var safe_enemies: bool = true
	var clear_hero_motion: bool = true
	var clear_enemy_motion: bool = true
	var wave_generations: int = 0
	var previous_encounter: int = int(game.hunt_ai.encounter_id)
	var killed_at_half: int = 0
	var last_kills: int = 0
	var stall_seconds: float = 0.0
	var longest_stall: float = 0.0
	for tick: int in range(1200):
		var heroes_before: Dictionary = game.party_movement.positions.duplicate()
		var enemies_before: Array = game.roaming_hunt.enemy_positions.duplicate()
		game._advance_auto_hunt(0.1)
		simulated_seconds += 0.1
		var encounter: int = int(game.hunt_ai.encounter_id)
		for id: String in game.party_movement.positions:
			if int(game.hero_battle_state.get(id, {}).get("hp", 0)) <= 0:
				continue
			var point: Vector2 = game.party_movement.positions[id]
			safe_heroes = safe_heroes and point.is_finite() and game.field_navigation.is_walkable(point)
			if heroes_before.has(id):
				clear_hero_motion = clear_hero_motion and game.field_navigation.has_clear_path(heroes_before[id], point)
				sampled_actor_moves += 1
		for index: int in range(mini(game.enemy_wave.size(), game.roaming_hunt.enemy_positions.size())):
			if int(game.enemy_wave[index].get("hp", 0)) <= 0:
				continue
			var point: Vector2 = game.roaming_hunt.enemy_positions[index]
			safe_enemies = safe_enemies and point.is_finite() and game.field_navigation.is_walkable(point)
			if encounter == previous_encounter and index < enemies_before.size():
				clear_enemy_motion = clear_enemy_motion and game.field_navigation.has_clear_path(enemies_before[index], point)
				sampled_actor_moves += 1
		if encounter != previous_encounter:
			wave_generations += 1
		previous_encounter = encounter
		if int(game.combat_kills) > last_kills:
			last_kills = int(game.combat_kills)
			stall_seconds = 0.0
		else:
			stall_seconds += 0.1
		longest_stall = maxf(longest_stall, stall_seconds)
		if tick == 599:
			killed_at_half = int(game.combat_kills)
		if tick % 30 == 0:
			await process_frame
	_check(safe_heroes and clear_hero_motion, zone + " all living heroes remain outside terrain throughout live combat")
	_check(safe_enemies and clear_enemy_motion, zone + " all living monsters spawn and move outside terrain throughout live combat")
	_check(killed_at_half > 0 and int(game.combat_kills) > killed_at_half, zone + " continues clearing packs in both minutes of automatic hunting")
	_check(wave_generations >= 2 and float(game.roaming_hunt.distance_walked) > 5.0, zone + " finds new packs and continues travelling after rewards")
	_check(game.combat_running and longest_stall < 60.0, zone + " never remains stalled for a full minute")
	print("V67 live hunt %s: packs=%d waves=%d path=%.2f longest_no_clear=%.1fs" % [zone, int(game.combat_kills), wave_generations, float(game.roaming_hunt.distance_walked), longest_stall])

func _run() -> void:
	root.content_scale_size = Vector2i(720, 1280)
	root.size = Vector2i(720, 1280)
	var game: Node = preload("res://scenes/PortraitMain.tscn").instantiate()
	game.save_state_path = "user://v67-terrain-integration.json"
	root.add_child(game)
	await _settle()
	game.set_physics_process(false)
	game._offline_checked = true
	game.combat_effects_enabled = false
	game.gear_auto_equip = false
	game.selected_faction = "aurelia"
	game.idle_stage = 25
	game.tutorial_completed = true
	game.battle_speed = 1.0
	var roster: Array = game._hero_roster_for_faction()
	game.deployed_heroes = roster.slice(0, 10).duplicate()
	# A party suitable for all three unlocked regions exercises navigation without
	# making this a level-one balance test. Damage, enemies and AI remain native.
	for hero: Dictionary in game.deployed_heroes:
		game.hero_progress[str(hero["id"])] = {"level": 35, "xp": 0}
	for zone: String in CATALOG.ZONE_IDS:
		game.set_meta("content_region_id", zone)
		game._build_world_map_screen()
		await _settle()
		var preview: Control = game.content_root.find_child("RegionTerrainPreview", true, false)
		_check(preview != null and preview.zone_id == zone, zone + " selected destination has its live terrain preview")
		if preview == null:
			continue
		var preview_ponds: Array = preview._terrain._ponds.duplicate(true)
		var preview_prop_points: Array[Vector2] = []
		for prop: Sprite2D in preview._props:
			preview_prop_points.append(prop.get_meta("world"))
		var preview_texture: String = preview._terrain.field_texture.resource_path
		var enter: Button = game.content_root.find_child("RegionEnterButton", true, false)
		_check(enter != null and not enter.disabled, zone + " region can be entered from its real UI action")
		if enter == null or enter.disabled:
			continue
		enter.pressed.emit()
		await _settle()
		_check(game.active_screen == "combat" and game.current_zone_id == zone and game.field_navigation.zone_id == zone, zone + " launch action configures the same navigation region")
		_check(game.hero_map_sprites.size() == 10 and game.hero_battle_state.size() == 10, zone + " launches the full ten-hero party")
		_check(game.enemy_wave.size() >= 10 and game.enemy_wave.size() == game.roaming_hunt.enemy_positions.size(), zone + " launches a complete moving monster population")
		var terrain: Control = game.combat_labels["terrain"]
		var props: Node = game.content_root.get_node("PortraitMeadowProps" if zone == "gray_meadow" else "PortraitFieldProps")
		_check(terrain.field_texture.resource_path == preview_texture and terrain._ponds == preview_ponds, zone + " destination preview and live ground use identical artwork and pond geometry")
		var matching_props: bool = props.props.size() == preview_prop_points.size()
		for prop: Sprite2D in props.props:
			var point: Vector2 = prop.get_meta("world_position")
			matching_props = matching_props and point in preview_prop_points and not game.field_navigation.is_walkable(point)
		_check(matching_props, zone + " destination obstacles match visible props and actual collision")
		_check_camera(game, terrain, props, zone)
		await _simulate(game, zone)
	game.free()
	print("V67FieldTerrainIntegrationSmokeTest: %d checks, %d failures, %.0f simulated seconds, %d actor movement samples" % [checks, failures.size(), simulated_seconds, sampled_actor_moves])
	quit(0 if failures.is_empty() else 1)
