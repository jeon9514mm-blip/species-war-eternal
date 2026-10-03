extends "res://scripts/portrait/PortraitMain.gd"
## F6 developer preview. Production progression and local settings are never read
## or written. Combat, invasion, formation and damage are the production methods.
const LAB_FIELD = preload("res://scripts/art/ArtDirectionBattlefield.gd")
const LAB_SAVE_PATH := "user://art-direction-lab/progress.json"
const LAB_SETTINGS_PATH := "user://art-direction-lab/preferences.cfg"

class PilotHud extends "res://scripts/portrait/LandscapeHuntHud.gd":
	func refresh() -> void:
		super.refresh()
		if is_instance_valid(stage_label):
			stage_label.text = "빛바람 초원 · 시범  |  %d 스테이지" % game.idle_stage
			stage_label.tooltip_text = stage_label.text

func _new_hunt_hud() -> Control:
	return PilotHud.new()

func _init() -> void:
	save_state_path = LAB_SAVE_PATH
	presentation_preferences_path = LAB_SETTINGS_PATH
	set_meta("raid_report_path", "user://art-direction-lab/raid-reports.json")
	set_meta("art_direction_lab", true)
	set_meta("pilot_ready", false)

func _ready() -> void:
	# Set these before Main._ready, including when launched with F6 in an editor
	# using the player's normal user:// directory. No XDG wrapper is required.
	save_state_path = LAB_SAVE_PATH
	presentation_preferences_path = LAB_SETTINGS_PATH
	set_meta("raid_report_path", "user://art-direction-lab/raid-reports.json")
	assert(save_state_path != SAVE_PATH)
	assert(presentation_preferences_path != PresentationSettings.PATH)
	# Raid report exploration also uses its own archive when opening other menus.
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://art-direction-lab"))
	super._ready()
	selected_faction = "aurelia"
	current_zone_id = "gray_meadow"
	tutorial_completed = true
	idle_stage = 1
	party_slot_legacy_cap = 3
	_restore_deployed_heroes(["leonhardt", "mira", "elisia"])
	for hero: Dictionary in deployed_heroes:
		hero_progress[str(hero.id)] = {"level": 10, "xp": 0}
	battle_speed = 1.0
	skill_auto = true
	ultimate_auto = true
	_offline_checked = true
	_build_combat_screen()
	set_meta("pilot_ready", true)

func _load_idle_state() -> void:
	save_load_status = "art_lab_no_persistence"
	_offline_checked = true

func _save_idle_state() -> void:
	# Online rewards can still update this disposable session's wallet, without
	# passing any snapshot to SaveStore (also covers close/pause/menu callbacks).
	_deposit_nonoffline_rewards()
	last_save_status = "art_lab_no_persistence"

func _calculate_offline_reward() -> void:
	_offline_checked = true

func _load_ui_preferences() -> void:
	presentation_options = PresentationSettings.DEFAULTS.duplicate(true)
	presentation_options.orientation = "landscape"
	# Keep the art comparison quiet by default; the session setting still works.
	presentation_options.music_enabled = false
	sound_effects_enabled = false

func _save_ui_preferences() -> void:
	presentation_settings_error = OK
	if is_instance_valid(presentation_runtime): presentation_runtime.apply()

func _install_portrait_hud() -> void:
	super._install_portrait_hud()
	var previous: Control = combat_labels.get("terrain")
	var field := LAB_FIELD.new()
	field.name = "ArtDirectionBattlefield"
	field.position = combat_field_rect.position
	field.size = combat_field_rect.size
	field.configure(current_zone_id, _current_zone().color)
	field.game = self
	combat_labels.terrain = field
	if is_instance_valid(previous):
		content_root.remove_child(previous)
		previous.queue_free()
	content_root.add_child(field)
	content_root.move_child(field, 0)
	var concept := P_SKIN.button("영웅 원화 보기", _open_concept_study)
	concept.name = "ArtDirectionConceptButton"
	concept.add_theme_font_size_override("font_size", 14)
	concept.position = Vector2(180, 10)
	concept.size = Vector2(145, 38)
	concept.z_index = 80
	field.add_child(concept)
	var note := Label.new()
	note.name = "ArtDirectionLabNotice"
	note.text = "밝은 초원 · 시범  |  영웅은 기존 동작 검증 중  |  진행·설정 저장 안 함"
	note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	note.position = Vector2(18, 114)
	note.size = Vector2(combat_field_rect.size.x - 12, 20)
	note.add_theme_font_size_override("font_size", 13)
	note.add_theme_color_override("font_color", Color("d9e6c2"))
	note.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	note.z_index = 121
	content_root.add_child(note)
	_update_combat_camera(0)

func _open_concept_study() -> void:
	combat_running = false
	if is_instance_valid(presentation_runtime): presentation_runtime.audio.shutdown()
	get_tree().change_scene_to_file("res://scenes/art/HeroConceptStudy.tscn")

func _apply_portrait_resize() -> void:
	super._apply_portrait_resize()
	if active_screen == "combat" and is_instance_valid(content_root):
		var note: Label = content_root.get_node_or_null("ArtDirectionLabNotice")
		if note != null: note.size.x = combat_field_rect.size.x - 12
