extends SceneTree

var checks := 0
var failures: Array[String] = []

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)

func walk(node: Node, output: Array) -> void:
	output.append(node)
	for child in node.get_children(): walk(child,output)

func _init() -> void:
	run.call_deferred()

func run() -> void:
	var main = preload("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.set_physics_process(false)
	main._offline_checked = true
	for faction in ["aurelia","noxfera"]:
		main.selected_faction = faction
		main.idle_stage = 1
		main.hero_roster_filter = "전체"
		main._build_hero_select_screen()
		await process_frame
		check(main.hero_select_buttons.size()==15, faction + " displays fifteen selectable/locked cards")
		for hero in main._hero_roster_for_faction():
			var id := str(hero["id"])
			check(main.hero_select_buttons[id].disabled == (int(hero["unlock_stage"])>1), id + " follows stage unlock")
		for hero in main._hero_roster_for_faction():
			main._build_hero_detail_screen(str(hero["id"]))
			await process_frame
			await process_frame
			var nodes: Array = []
			walk(main.content_root,nodes)
			for skill in hero["skills"]:
				var found := false
				for node in nodes:
					if node is Label and str(node.text).contains(str(skill["skill"])):
						found = true
						check(node.size.x <= 750.0, "%s skill title fits details panel" % skill["id"])
				check(found, "%s visible in details" % skill["id"])
	main.selected_faction = "aurelia"
	main.idle_stage = 25 # Six deployed heroes must fit the actual progression cap.
	main._restore_deployed_heroes(["leonhardt","adrien","tessa","naia","sael","odelia"])
	main._setup_hero_progress(main._hero_roster_for_faction())
	main.hero_progress["leonhardt"] = {"level":37,"xp":42}
	main.hero_progress["odelia"] = {"level":12,"xp":17}
	main.hero_shards["selene"] = 19
	main._save_idle_state()
	check(main.last_save_status == "saved", "v29 actual save succeeds")
	var restored = preload("res://scenes/Main.tscn").instantiate()
	root.add_child(restored)
	await process_frame
	check(restored._deployed_hero_ids() == main._deployed_hero_ids(), "new hero deployment survives save reload")
	check(restored.hero_progress["leonhardt"] == {"level":37,"xp":42} and restored.hero_progress["odelia"] == {"level":12,"xp":17}, "old and new hero growth survives reload")
	check(restored.hero_shards.get("selene",0)==19, "opposite faction new hero shards preserved")
	main.free()
	restored.free()
	print("v29_roster_ui_save checks=%d failures=%d" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
