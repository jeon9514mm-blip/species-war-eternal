extends SceneTree

var checks := 0
var failures: Array[String] = []

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)

func _init() -> void:
	run.call_deferred()

func run() -> void:
	var main = preload("res://scenes/Main.tscn").instantiate()
	main.save_state_path = "user://v46_faction_isolation_test.json"
	root.add_child(main)
	await process_frame
	main.set_physics_process(false)
	main._offline_checked = true
	main.idle_stage = 100

	main.selected_faction = "aurelia"
	main._load_active_faction_presets()
	main._load_active_faction_world()
	main._restore_deployed_heroes(["leonhardt", "valeria", "mira", "fenris"])
	check(main._deployed_hero_ids() == ["leonhardt", "mira"], "aurelia party rejects noxfera ids")
	main.party_presets[0] = ["leonhardt", "mira"]
	main._stash_active_faction_presets()
	main.faction_war_state.rations = 1234
	main._stash_active_faction_world()

	main.selected_faction = "noxfera"
	main._load_active_faction_presets()
	main._load_active_faction_world()
	check(main.party_presets[0].is_empty(), "noxfera presets do not inherit aurelia")
	check(main.faction_war_state.faction == "noxfera", "noxfera war state has no aurelia ownership context")
	main._restore_deployed_heroes(["leonhardt", "valeria", "mira", "fenris"])
	check(main._deployed_hero_ids() == ["valeria", "fenris"], "noxfera party rejects aurelia ids")
	main.party_presets[0] = ["valeria", "fenris"]
	main._stash_active_faction_presets()

	main.selected_faction = "aurelia"
	main._load_active_faction_presets()
	main._load_active_faction_world()
	check(main.party_presets[0] == ["leonhardt", "mira"], "aurelia preset restored independently")
	check(main.faction_war_state.faction == "aurelia" and main.faction_war_state.rations == 1234, "aurelia war snapshot restored independently")

	main.selected_faction = "noxfera"
	main._load_active_faction_presets()
	check(main.party_presets[0] == ["valeria", "fenris"], "noxfera preset restored independently")

	main.free()
	print("v46_faction_isolation checks=%d failures=%d" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
