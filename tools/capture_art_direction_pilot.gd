extends SceneTree
## Captures the actual developer scenes. --movie writes a short live hunt using
## Godot's --write-movie option; concept art is never substituted for live actors.
var game: Node
var output := "res://checks/art-direction-pilot/captures"

func _initialize() -> void:
	_run.call_deferred()

func settle(frames := 12) -> void:
	for i in frames: await process_frame

func capture(label: String) -> void:
	await settle()
	await RenderingServer.frame_post_draw
	var path := ProjectSettings.globalize_path(output).path_join(label + ".png")
	assert(root.get_texture().get_image().save_png(path) == OK)
	print("ART_PILOT_CAPTURE ", label)

func dispose_game() -> void:
	if game == null: return
	game.set_physics_process(false)
	game.set_process(false)
	if game.get("presentation_runtime") != null:
		game.presentation_runtime.audio.shutdown()
	await create_timer(.3).timeout
	game.free()
	game = null
	await settle()

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Use a display renderer for actual screen captures.")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	root.content_scale_size = Vector2i(1280, 720)
	root.size = Vector2i(1280, 720)
	game = load("res://scenes/art/ArtDirectionLab.tscn").instantiate()
	root.add_child(game)
	root.size = Vector2i(1280, 720)
	await settle(30)
	if "--movie" in OS.get_cmdline_user_args():
		await create_timer(10.0).timeout
		await capture("meadow-live")
		await dispose_game()
		quit()
		return
	await create_timer(2.0).timeout
	game.set_physics_process(false)
	game.set_process(false)
	await capture("meadow-combat")
	var field = game.combat_labels.terrain
	field._toggle_art()
	await capture("original-combat-same-state")
	field._toggle_art()
	field._toggle_overview()
	await capture("meadow-overview")
	root.size = Vector2i(1600, 720)
	await capture("meadow-wide")
	root.size = Vector2i(960, 540)
	await capture("meadow-small")
	await dispose_game()
	root.size = Vector2i(1280, 720)
	game = load("res://scenes/art/HeroConceptStudy.tscn").instantiate()
	root.add_child(game)
	await capture("hero-concept-study")
	game.free()
	game = null
	await settle()
	quit()
