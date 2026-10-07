extends SceneTree
const DESIGN := preload("res://scripts/raid/RaidBossDesign.gd")
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error("V75 raid mechanic: " + label)

func _game(zone: String):
	var game = preload("res://scenes/PortraitMain.tscn").instantiate()
	root.add_child(game)
	game.selected_faction = "aurelia"
	game.idle_stage = 50
	game.deployed_heroes = game._hero_roster_for_faction().slice(0, 10)
	game.selected_raid_id = zone
	game._build_raid_screen()
	game._start_raid()
	if is_instance_valid(game.combat_timer): game.combat_timer.stop()
	return game

func _run() -> void:
	_test_design()
	await _test_guard()
	await _test_adds()
	await _test_dps_check()
	await _test_break_gauge()
	print("V75RaidMechanicSmokeTest: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func _test_design() -> void:
	check(str(DESIGN.mechanic("gray_meadow", 2).get("kind")) == "guard", "meadow phase two owns guard break")
	check(str(DESIGN.mechanic("forgotten_mine", 2).get("kind")) == "adds", "mine phase two owns crystal adds")
	check(str(DESIGN.mechanic("moonrest_forest", 3).get("kind")) == "dps_check", "forest phase three owns DPS check")

func _test_guard() -> void:
	var game = _game("gray_meadow")
	for i in 4: await process_frame
	check(game.content_root.get_node_or_null("PortraitRaidView/PortraitRaidDetails/PortraitRaidArena/PortraitRaidActors/PortraitRaidMechanicVisual") != null, "portrait raid renders live mechanic overlay")
	game.raid_phase = 2
	game._raid_activate_phase_mechanic(2)
	var boss_before: int = game.raid_boss_hp
	var shield: int = game.raid_guard_hp
	check(shield > 0, "meadow creates a real shield HP pool")
	game._apply_raid_damage(shield)
	check(game.raid_guard_hp == 0 and game.raid_guard_breaks == 1, "shield can be broken exactly once")
	check(game.raid_boss_hp == boss_before, "breaking hit is absorbed before boss HP")
	check(game._vulnerable_seconds >= 2.9, "guard break exposes a vulnerability window")
	await _dispose(game)

func _test_adds() -> void:
	var game = _game("forgotten_mine")
	for i in 4: await process_frame
	game.raid_phase = 2
	game._raid_activate_phase_mechanic(2)
	var boss_before: int = game.raid_boss_hp
	var adds: int = game.raid_add_hp
	check(game.raid_add_count == 2 and adds > 0, "mine summons two crystal cores")
	game._apply_raid_damage(adds)
	check(game.raid_add_hp == 0 and game.raid_add_waves_cleared == 1, "crystal core wave can be cleared")
	check(game.raid_boss_hp == boss_before, "crystal cores intercept damage before boss HP")
	await _dispose(game)

func _test_dps_check() -> void:
	var game = _game("moonrest_forest")
	for i in 4: await process_frame
	game.raid_phase = 2
	game._raid_activate_phase_mechanic(2)
	var target: int = game.raid_dps_check_target
	check(game.raid_dps_check_remaining > 0.0 and target > 0, "forest starts a timed damage check")
	game._apply_raid_damage(target)
	check(game.raid_dps_checks_passed == 1 and game.raid_dps_check_remaining == 0.0, "enough damage breaks the eclipse ritual")
	check(game._raid_performance_crystal_bonus() >= 3, "successful mechanic grants performance currency")
	await _dispose(game)

func _test_break_gauge() -> void:
	var game = _game("gray_meadow")
	for i in 4: await process_frame
	game.boss_telegraph_pending = true
	game.boss_telegraph_skill = "검증 시전"
	game.boss_telegraph_remaining = 1.0
	check(game._raid_apply_control(0.4), "first short control contributes to break gauge")
	check(game.boss_telegraph_pending and game.raid_break_gauge > 0.0 and game.raid_break_gauge < game.raid_break_gauge_max, "partial control no longer pretends the cast is fully interrupted")
	check(game._raid_apply_control(0.4), "second short control is accepted")
	check(not game.boss_telegraph_pending and game.raid_interrupt_count == 1 and game.raid_break_gauge == 0.0, "combined control fills gauge and interrupts the cast")
	await _dispose(game)

func _dispose(game) -> void:
	if game.raid_running: game._finish_raid("cancelled")
	if game.presentation_runtime != null: game.presentation_runtime.audio.shutdown()
	await create_timer(0.5).timeout
	game.free()
	await create_timer(0.35).timeout
