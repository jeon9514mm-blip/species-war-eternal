extends SceneTree
## Real multipart renderer captures. A static concept is only the labelled
## reference at the right; the centre always renders independently hinged parts.
const CATALOG = preload("res://scripts/art/HeroPartsCatalog.gd")
var output := "res://checks/aurelia-four-head/captures"
var study: Control
var records: Array[Dictionary] = []

func _initialize() -> void:
	_run.call_deferred()

func settle(frames := 5) -> void:
	for index in frames: await process_frame

func capture(label: String) -> void:
	await settle()
	await RenderingServer.frame_post_draw
	var path := ProjectSettings.globalize_path(output).path_join(label + ".png")
	assert(root.get_texture().get_image().save_png(path) == OK)
	records.append({"capture": label, "state": study.gallery_state(),
		"draw_calls": int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		"texture_memory_bytes": int(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED))})
	var file := FileAccess.open("res://checks/aurelia-four-head/render-review.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(records, "  ") + "\n")
	print("AURELIA_PARTS_CAPTURE ", label)

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Use a display renderer for multipart visual review")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	root.content_scale_size = Vector2i(1280, 720)
	root.size = Vector2i(1280, 720)
	study = load("res://scenes/art/HeroPartsStudy.tscn").instantiate()
	root.add_child(study)
	await settle(20)
	study.set_animation_playing(false)
	var ids: Array = CATALOG.HERO_IDS.duplicate()
	var selected := OS.get_environment("AURELIA_CAPTURE_IDS")
	if not selected.is_empty(): ids = Array(selected.split(",", false))
	for hero_id: String in ids:
		study.select_hero(hero_id)
		study.select_action("idle")
		study.seek_animation(0.0)
		await capture(hero_id + "-idle")
		if "--idle-only" in OS.get_cmdline_user_args(): continue
		for action: String in ["run", "attack_1", "skill", "death"]:
			study.select_action(action)
			study.seek_animation(float(study.gallery_state().get("duration", 1.0)) * (.48 if action != "death" else .94))
			await capture(hero_id + "-" + action)
	study.free()
	await settle()
	quit()
