extends "res://tests/support/V83UpgradeTestBase.gd"
## Actual Godot viewport capture with an isolated test save, not a generated mockup.
## Run with a display (for CI, xvfb-run); --headless cannot capture rendered pixels.
func _init() -> void: run.call_deferred()

func run() -> void:
	var main = await make_main("aurelia",10)
	main.tutorial_completed=true
	root.content_scale_size=Vector2i(1280,720);root.size=Vector2i(1280,720)
	await settle()
	main._build_combat_screen();await settle()
	main.combat_running=true
	var ids: Array[String] = main._deployed_hero_ids()
	if ids.size() >= 3:
		main.hero_battle_state[ids[0]].hp=float(main.hero_battle_state[ids[0]].max_hp)*.37
		main.hero_battle_state[ids[0]].ultimate=63
		main.hero_battle_state[ids[1]].ultimate=100
		main.hero_battle_state[ids[2]].hp=0
	main.portrait_hud.refresh()
	var destination: String = OS.get_environment("HUNT_UI_CAPTURE_DIR")
	if destination.is_empty(): destination=ProjectSettings.globalize_path("user://hunt-dock-capture")
	DirAccess.make_dir_recursive_absolute(destination)
	await capture(destination.path_join("hunt-dock-1280x720.png"))
	root.content_scale_size=Vector2i(960,540);root.size=Vector2i(960,540)
	await settle();main.portrait_hud.refresh()
	await capture(destination.path_join("hunt-dock-960x540.png"))
	await dispose(main);done("HUNT_DOCK_CAPTURE")

func capture(path: String) -> void:
	await settle()
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	check(image != null and not image.is_empty(),"rendered viewport exists")
	if image == null or image.is_empty(): return
	check(image.save_png(path) == OK,"capture saved: "+path.get_file())
