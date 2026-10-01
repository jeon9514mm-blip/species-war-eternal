extends "res://scripts/V83UpgradeTestBase.gd"
class FailedStore extends SaveStore:
	func write_save(_path: String, _data: Dictionary) -> Dictionary:
		return {"ok":false,"status":"injected_write_failure"}
func _init() -> void: _run.call_deferred()
func _run() -> void:
	var main = await make_main("aurelia",10)
	main._open_combat_presets(); await settle()
	check(PRESET.save(main,0).ok, "UI preset fixture saved")
	main._preview_party_preset(0); await settle()
	check(main.find_child("ConfirmCombatPreset",true,false)!=null, "confirmation required")
	var apply = main.find_child("ConfirmCombatPreset",true,false)
	if apply != null: apply.emit_signal("pressed")
	await settle()
	check(main.active_screen == "combat_presets", "apply returns to overview")
	main._open_practice_screen(); await settle()
	for name in ["PracticeStart_gold_rush","PracticeStart_survival","PracticeStart_boss_hunt","PracticeStart_tower","PracticeStart_weekly","PracticeDailyTier"]:
		check(main.find_child(name,true,false)!=null, "practice UI control " +name)
	var scroll: ScrollContainer = main.find_child("PortraitContentScroll",true,false)
	check(scroll != null and scroll.size.x > 620 and scroll.size.y > 600, "actual viewport content is not zero-sized")
	if scroll != null:
		scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value); await settle()
		var last = main.find_child("PracticeStart_weekly",true,false)
		check(last != null and scroll.get_global_rect().intersects(last.get_global_rect()), "weekly practice button reachable by scrolling")
		scroll.scroll_vertical = 0; await settle()
	var font: Font = preload("res://scripts/UIFontProvider.gd").get_font()
	for c in "전투연습장비프리셋": check(font.has_char(c.unicode_at(0)), "device font Korean coverage " +c)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var path: String = OS.get_environment("V83_CAPTURE_DIR")
		if not path.is_empty(): root.get_texture().get_image().save_png(path.path_join("v83-3-practice.png"))
	var real_store = main.save_store
	var persisted: int = main.wallet_gold
	main.wallet_gold += 777; main.save_store = FailedStore.new()
	main._save_idle_state(); await settle()
	check(SAFETY.pending(main) and main.find_child("RetryPendingSave",true,false)!=null, "visible common save failure barrier")
	check(not main._challenge_tower(), "tower cannot continue over failed write")
	check(not main._start_practice("weekly",1,""), "practice cannot hide pending rewards")
	check(not main.PRESETS.apply(main,0).ok, "preset cannot overwrite pending reward")
	main._load_idle_state()
	check(main.wallet_gold == persisted+777, "loading old save cannot erase pending reward")
	main.save_store = real_store
	main._retry_pending_save(); await settle()
	check(not SAFETY.pending(main) and main.get_node_or_null("SaveSafetyLayer") == null, "retry removes banner")
	check(main.wallet_gold == persisted+777 and main.save_store.read_save(main.save_state_path).data.wallet_gold == persisted+777, "retry persists reward exactly once")
	main._retry_pending_save()
	check(main.wallet_gold == persisted+777, "duplicate retry gives no reward")
	main._open_combat_presets();await settle()
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var path: String = OS.get_environment("V83_CAPTURE_DIR")
		if not path.is_empty():root.get_texture().get_image().save_png(path.path_join("v83-3-presets.png"))
	await dispose(main)
	done("v83_practice_ui")
