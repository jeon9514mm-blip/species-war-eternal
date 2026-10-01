extends SceneTree
var checks: int = 0
var failures: Array[String] = []
func _init() -> void: _run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); push_error(label)
func _run() -> void:
	var path: String = "user://v82-settings.cfg"
	var old := ConfigFile.new(); old.set_value("display", "combat_effects", false); old.set_value("custom", "keep", 71)
	check(old.save(path) == OK, "legacy config fixture saved")
	var saved: Dictionary = PresentationSettings.load_preferences(path)
	check(not saved["effects"] and not saved["sound"] and not saved["options"]["music_enabled"], "legacy combined mute does not unexpectedly enable music")
	check(saved["options"]["haptics"] == "off", "haptics opt in by default")
	var opts: Dictionary = PresentationSettings.sanitize({"music_volume": 9, "effects_volume": -2, "ui_volume": NAN, "ambient_volume": "bad", "haptics": "bad", "performance": "bad", "music_enabled": "true"})
	check(opts["music_volume"] == 1.0 and opts["effects_volume"] == 0.0, "volumes clamped")
	check(is_finite(opts["ui_volume"]) and opts["ambient_volume"] == 0.25, "invalid numeric input rejected")
	check(opts["haptics"] == "off" and opts["performance"] == "balanced", "unknown profiles rejected")
	opts["music_volume"] = 0.41; opts["music_enabled"] = false; opts["haptics"] = "light"; opts["performance"] = "battery"
	check(PresentationSettings.save_preferences(true, false, opts, path) == OK, "new options saved through temporary file")
	saved = PresentationSettings.load_preferences(path)
	check(saved["options"] == opts and saved["effects"] and not saved["sound"], "actual filesystem roundtrip")
	check(FileAccess.file_exists(path + ".bak"), "previous config backup kept")
	var verify := ConfigFile.new(); verify.load(path)
	check(verify.get_value("custom", "keep", 0) == 71, "unrelated preferences preserved")
	check(PresentationSettings.profile(opts)["fps"] == 30 and PresentationSettings.profile({})["fps"] == 60, "render profiles")
	check(PresentationSettings.profile(opts)["hud_interval"] == 0.2, "battery HUD interval")
	var h := HapticDirector.new(); var pulses: Array = []
	h.sink = func(duration: int, strength: float): pulses.append([duration, strength])
	check(not h.pulse("ultimate", 1000) and pulses.is_empty(), "off produces no vibration request")
	h.mode = "light"
	check(h.pulse("boss_warning", 1000) and pulses.size() == 1, "light request accepted in injected sink")
	check(pulses[0][0] == 50 and is_equal_approx(pulses[0][1], 0.325), "bounded duration and half amplitude")
	check(not h.pulse("critical", 1100), "global cooldown suppresses repeated critical")
	h.suspended = true
	check(not h.pulse("boss_warning", 3000), "background vibration blocked")
	h.suspended = false; h.mode = "normal"
	check(h.pulse("boss_warning", 3000) and pulses[1][1] == 0.65, "normal strength restored")
	check(not h.pulse("unknown", 4000), "unknown events rejected")
	h.mode = "off"; check(not h.pulse("ui_click", 5000), "opt out immediate")
	print("v82_settings checks=%d failures=%s hardware_vibrations=0" % [checks, JSON.stringify(failures)])
	quit(0 if failures.is_empty() else 1)
