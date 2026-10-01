extends SceneTree
var failures := 0
var checks := 0
func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)
func _init() -> void:
	_run.call_deferred()
func _run() -> void:
	var main = preload("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.set_physics_process(false)
	main.selected_faction = "aurelia"
	main._restore_deployed_heroes(["leonhardt"])
	main._setup_hero_skills()
	main.active_screen = "combat"
	main.combat_running = true
	main._begin_hunt_recovery()
	main.hero_battle_state["leonhardt"]["hp"] = 1
	main._sync_party_hp_from_heroes()
	main.battle_speed = 2.0
	var before: float = main.hunt_ai.clock
	main._advance_auto_hunt(0.1)
	_check(is_equal_approx(main.hunt_ai.clock - before, 0.2), "2x combat preserves elapsed time on a 100ms frame")
	before = main.hunt_ai.clock
	main._advance_auto_hunt(NAN)
	main._advance_auto_hunt(INF)
	main._advance_auto_hunt(-1.0)
	_check(main.hunt_ai.clock == before, "Invalid deltas cannot poison simulation")
	main.combat_running = false
	main._advance_auto_hunt(0.1)
	_check(main.hunt_ai.clock == before, "Pause freezes all simulation substeps")
	main.combat_running = true
	main.battle_speed = 1.0
	var samples: Array[int] = []
	for dt in [0.01, 0.1]:
		main._begin_hunt_recovery()
		var state: Dictionary = main.hero_battle_state["leonhardt"]
		state["hp"] = 1
		main._sync_party_hp_from_heroes()
		for tick in int(round(2.0 / dt)):
			main._advance_auto_hunt(dt)
		samples.append(int(state["hp"]))
	_check(absi(samples[0] - samples[1]) <= 1, "Recovery HP is independent of update frequency")
	main.free()
	await process_frame
	print("v27_combat_clock checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)
