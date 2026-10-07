extends SceneTree
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error('V76 raid visual: ' + label)

func _game(zone: String):
	var game = preload('res://scenes/PortraitMain.tscn').instantiate()
	root.add_child(game)
	game.selected_faction = 'aurelia'
	game.idle_stage = 50
	game.deployed_heroes = game._hero_roster_for_faction().slice(0, 10)
	game.selected_raid_id = zone
	game._build_raid_screen()
	game._start_raid()
	if is_instance_valid(game.combat_timer): game.combat_timer.stop()
	return game

func _run() -> void:
	await _test_guard_break()
	await _test_crystal_break()
	await _test_eclipse_tint()
	await _test_enrage_skin()
	await _test_finish_fx()
	print('V76RaidVisualSmokeTest: %d checks, %d failures' % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func _visual(game):
	return _view(game).mechanic_visual

func _view(game):
	return game.content_root.get_node('PortraitRaidView')

func _test_guard_break() -> void:
	var game = _game('gray_meadow')
	for i in 3: await process_frame
	game.raid_phase = 2
	game._raid_activate_phase_mechanic(2)
	var visual = _visual(game)
	visual._process(0.016)
	check(visual.guard_spawn_remaining > 0.0, 'guard activation has spawn animation state')
	game._apply_raid_damage(game.raid_guard_hp)
	visual._process(0.016)
	check(visual.guard_break_remaining > 0.0, 'guard break has fracture animation state')
	await _dispose(game)

func _test_crystal_break() -> void:
	var game = _game('forgotten_mine')
	for i in 3: await process_frame
	game.raid_phase = 2
	game._raid_activate_phase_mechanic(2)
	var visual = _visual(game)
	visual._process(0.016)
	check(visual.crystal_spawn_remaining > 0.0, 'crystal wave has summon animation state')
	game._apply_raid_damage(game.raid_add_hp)
	visual._process(0.016)
	check(visual.crystal_break_remaining > 0.0, 'crystal clear has shatter animation state')
	await _dispose(game)

func _test_eclipse_tint() -> void:
	var game = _game('moonrest_forest')
	for i in 3: await process_frame
	game.raid_phase = 2
	game._raid_activate_phase_mechanic(2)
	var view = _view(game)
	view.refresh()
	var tint: ColorRect = view.mechanic_tint
	check(tint.color.a >= 0.15, 'active eclipse darkens the arena')
	await _dispose(game)

func _test_enrage_skin() -> void:
	var game = _game('gray_meadow')
	for i in 3: await process_frame
	game.raid_enraged = true
	var view = _view(game)
	view.refresh()
	check(game.raid_boss_sprite.modulate.g < game.raid_boss_sprite.modulate.r, 'enrage changes boss body tint')
	var visual = _visual(game)
	visual._process(0.016)
	check(visual.enrage_burst_remaining > 0.0, 'enrage transition owns burst animation state')
	await _dispose(game)

func _test_finish_fx() -> void:
	var game = _game('gray_meadow')
	for i in 3: await process_frame
	var view = _view(game)
	view.show_victory()
	check(_visual(game).victory_burst_remaining > 0.0, 'victory starts dedicated boss finish burst')
	check(game.raid_boss_sprite.state == 'death', 'victory plays boss death state')
	await _dispose(game)

func _dispose(game) -> void:
	if game.raid_running: game._finish_raid("cancelled")
	if game.presentation_runtime != null: game.presentation_runtime.audio.shutdown()
	await create_timer(0.5).timeout
	game.free()
	await create_timer(0.35).timeout
