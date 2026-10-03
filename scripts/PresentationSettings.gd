class_name PresentationSettings
extends RefCounted
## Device-local presentation options. Never part of progression/save migration.
const PATH := "user://ui-preferences.cfg"
const DEFAULTS := {"music_enabled": true, "music_volume": 0.35, "effects_volume": 0.65,
	"ui_volume": 0.55, "ambient_volume": 0.25, "haptics": "off", "performance": "balanced", "orientation": "landscape"}
const PROFILES := {
	"balanced": {"fps": 60, "hud_interval": 0.10, "power_interval": 0.50, "fx_limit": 96, "float_limit": 16},
	"battery": {"fps": 30, "hud_interval": 0.20, "power_interval": 1.0, "fx_limit": 48, "float_limit": 10}}

static func sanitize(raw: Dictionary) -> Dictionary:
	var out: Dictionary = DEFAULTS.duplicate(true)
	if raw.get("music_enabled") is bool: out["music_enabled"] = raw["music_enabled"]
	for key in ["music_volume", "effects_volume", "ui_volume", "ambient_volume"]:
		var value: Variant = raw.get(key, out[key])
		if (value is int or value is float) and is_finite(float(value)):
			out[key] = clampf(float(value), 0.0, 1.0)
	if str(raw.get("haptics", "")) in ["off", "light", "normal"]: out["haptics"] = str(raw["haptics"])
	if PROFILES.has(str(raw.get("performance", ""))): out["performance"] = str(raw["performance"])
	# Retain the key for old preference files, but this release supports landscape only.
	out["orientation"] = "landscape"
	return out

static func load_preferences(path: String = PATH) -> Dictionary:
	var cfg := ConfigFile.new()
	var status: int = cfg.load(path)
	# Recover only from our own last successful settings file.
	if status != OK: cfg.load(path + ".bak")
	var effects: bool = bool(cfg.get_value("display", "combat_effects", true))
	var sound: bool = bool(cfg.get_value("audio", "sound_effects", effects))
	var raw: Dictionary = {"music_enabled": sound}
	for key in DEFAULTS:
		if cfg.has_section_key("presentation_v82", key): raw[key] = cfg.get_value("presentation_v82", key)
	return {"effects": effects, "sound": sound, "options": sanitize(raw)}

static func save_preferences(effects: bool, sound: bool, options: Dictionary, path: String = PATH) -> int:
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK: cfg.load(path + ".bak")
	cfg.set_value("display", "combat_effects", effects)
	cfg.set_value("audio", "sound_effects", sound)
	var safe: Dictionary = sanitize(options)
	for key in safe: cfg.set_value("presentation_v82", key, safe[key])
	var temporary: String = path + ".tmp"
	var error: int = cfg.save(temporary)
	if error != OK: return error
	# Verify the complete temp config before replacing the previous settings.
	var verify := ConfigFile.new()
	error = verify.load(temporary)
	if error != OK: return error
	var global_path: String = ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(path):
		error = DirAccess.copy_absolute(global_path, global_path + ".bak")
		if error != OK: return error
	error = DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), global_path)
	if error != OK and FileAccess.file_exists(path + ".bak") and not FileAccess.file_exists(path):
		DirAccess.copy_absolute(global_path + ".bak", global_path)
	return error

static func profile(options: Dictionary) -> Dictionary:
	return PROFILES[sanitize(options)["performance"]].duplicate(true)
