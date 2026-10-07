extends SceneTree
var main: Node
var checks: int = 0
var failures: Array[String] = []
func _init() -> void: _run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); push_error(label)
func settle() -> void:
	for frame in 8: await process_frame
func item(name: String) -> Node: return main.content_root.find_child(name, true, false)
func _run() -> void:
	root.content_scale_size = Vector2i(720,1280); root.size = Vector2i(720,1280)
	main = preload("res://scenes/PortraitMain.tscn").instantiate()
	main.save_state_path = "user://v82-ui-save.json"; main.presentation_preferences_path = "user://v82-ui-prefs.cfg"
	root.add_child(main); await settle(); main.set_physics_process(false); main.set_process(false)
	main._offline_checked = true; main.selected_faction = "aurelia"; main._restore_deployed_heroes(["leonhardt","mira","elisia"])
	main._build_lobby_screen(); await settle();
	check(is_instance_valid(main.presentation_runtime), "presentation service survives initial and lobby screen clears")
	main._show_main_menu(); await settle()
	check(item("PresentationSettingsEntry") != null and item("PortraitMenuScroll") != null, "new settings reachable without overcrowded fixed menu")
	item("PresentationSettingsEntry").emit_signal("pressed"); await settle()
	check(item("PresentationSettingsScroll") != null and item("PresentationClose") != null, "scroll body and fixed close control")
	check(item("Presentation_orientation") == null and item("PresentationLandscapeNotice") != null, "landscape-only settings have no portrait/auto selector")
	check(main.presentation_options.orientation == "landscape" and root.content_scale_size == Vector2i(1280,720), "saved settings and viewport stay landscape")
	for name in ["music_volume","effects_volume","ui_volume","ambient_volume","haptics","performance"]:
		check(item("Presentation_"+name) != null, "visible option " + name)
	var gold: int = main.wallet_gold; var tick_rate: int = Engine.physics_ticks_per_second; var speed: float = main.battle_speed
	var perf: OptionButton = item("Presentation_performance"); perf.select(1); perf.item_selected.emit(1)
	check(main.presentation_options["performance"] == "battery" and main.combat_fx.optional_node_limit == 48, "battery applied live")
	check(Engine.physics_ticks_per_second == tick_rate and main.battle_speed == speed and main.wallet_gold == gold, "presentation does not change combat cadence/currency")
	var slider: HSlider = item("Presentation_music_volume"); slider.value = 23; slider.drag_ended.emit(true)
	check(is_equal_approx(main.presentation_options["music_volume"], 0.23), "slider live value")
	var persisted: Dictionary = PresentationSettings.load_preferences(main.presentation_preferences_path)
	check(is_equal_approx(persisted["options"]["music_volume"], 0.23) and persisted["options"]["performance"] == "battery", "actual options stored")
	item("PresentationMusicEnabled").button_pressed = false
	check(not main.presentation_options["music_enabled"] and main.presentation_runtime.audio._music_key.is_empty(), "BGM mute separate from effects")
	item("PresentationSoundEnabled").button_pressed = false
	check(not main.sound_effects_enabled and not main.presentation_runtime.audio.play_cue("reward"), "effects mute applied")
	main._application_suspended = true; main.presentation_runtime.sync_context()
	check(main.presentation_runtime.audio.suspended and main.presentation_runtime.haptics.suspended, "background stops presentation")
	main._application_suspended = false; main.presentation_runtime.sync_context()
	check(not main.presentation_runtime.audio.suspended, "foreground presentation resumes")
	item("PresentationClose").emit_signal("pressed"); await settle()
	check(item("PresentationSettingsOverlay") == null, "close removes panel")
	main._open_presentation_settings(); await settle()
	var event := InputEventAction.new(); event.action = "ui_cancel"; event.pressed = true
	main._unhandled_key_input(event); await settle()
	check(item("PresentationSettingsOverlay") == null, "back action closes settings")
	main._load_ui_preferences(); check(main.presentation_options["performance"] == "battery" and not main.sound_effects_enabled, "settings reload")
	main.queue_free(); await settle(); await create_timer(0.12).timeout
	print("v82_presentation_ui checks=%d failures=%s" % [checks, JSON.stringify(failures)])
	quit(0 if failures.is_empty() else 1)
