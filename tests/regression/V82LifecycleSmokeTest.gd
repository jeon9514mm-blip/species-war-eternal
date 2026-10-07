extends SceneTree
var checks: int = 0
var failures: Array[String] = []
func _init() -> void: _run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); push_error(label)
func settle() -> void:
	for i in 7: await process_frame
func _run() -> void:
	root.content_scale_size=Vector2i(720,1280);root.size=Vector2i(720,1280)
	var base_nodes: int=root.get_child_count()
	for run in 3:
		var main: Node=preload("res://scenes/PortraitMain.tscn").instantiate()
		main.save_state_path="user://v82-life-%d.json"%run
		main.presentation_preferences_path="user://v82-life-%d.cfg"%run
		root.add_child(main);await settle();main.set_physics_process(false);main.set_process(false);main._offline_checked=true
		main.selected_faction="aurelia";main._restore_deployed_heroes(["leonhardt","mira","elisia"])
		for view in 6:
			main._build_lobby_screen();await settle();main._show_main_menu();await settle()
			main._open_presentation_settings();await settle()
			main._set_presentation_option("performance","battery" if view%2 else "balanced",false)
			check(main.presentation_runtime.audio.get_child_count()==11,"rebuild has fixed audio pool")
			check(main.find_children("PresentationRuntime","",true,false).size()==1,"only one presentation service per root")
			var before: int=main.presentation_runtime.audio.accepted
			main.presentation_runtime.audio._process(1.0)
			var preview: Button=main.content_root.find_child("PresentationAudioPreview",true,false)
			var subscriptions: int=preview.pressed.get_connections().size()
			main.presentation_runtime._on_node_added(preview);main.presentation_runtime._on_node_added(preview)
			check(preview.pressed.get_connections().size()==subscriptions,"rewiring does not retain duplicate weak callbacks")
			preview.emit_signal("pressed")
			check(main.presentation_runtime.audio.accepted-before<=2,"no duplicate UI subscriptions after repeated wiring")
		main.queue_free();await settle();await create_timer(0.12).timeout
		check(root.get_child_count()==base_nodes,"scene audio service and controls leave tree cleanly")
	print("v82_lifecycle checks=%d failures=%s scene_rebuilds=18"%[checks,JSON.stringify(failures)])
	quit(0 if failures.is_empty() else 1)
