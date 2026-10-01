extends SceneTree
const HOST = preload("res://scripts/V83GameplayBattleHost.gd")
const ROSTER = preload("res://scripts/HeroRosterCatalog.gd")
const PRACTICE = preload("res://scripts/PracticeBattleService.gd")
const PRESET = preload("res://scripts/CombatPresetService.gd")
const SAFETY = preload("res://scripts/SaveSafety.gd")
var checks: int = 0
var failures: Array[String] = []
func check(ok: bool, note: String) -> void:
	checks += 1
	if not ok: failures.append(note); push_error(note)
func settle() -> void:
	for i in 5: await process_frame
func make_main(faction: String = "aurelia", count: int = 10):
	root.content_scale_size = Vector2i(720, 1280); root.size = Vector2i(720, 1280)
	var main = HOST.new()
	main.save_state_path = "user://upgrade-" + faction + "-" + str(Time.get_ticks_usec()) + ".json"
	root.add_child(main); main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); await settle()
	main.set_process(false); main.set_physics_process(false); main._offline_checked = true
	main.selected_faction = faction; main.current_zone_id = "gray_meadow"
	main.idle_stage = 100; main.party_slot_legacy_cap = 10
	var ids: Array[String] = []
	for hero in ROSTER.roster(faction):
		if ids.size() < count: ids.append(str(hero.id))
	main._restore_deployed_heroes(ids)
	for id in ids: main.hero_progress[id] = {"level": 60, "xp": 0}
	main.combat_effects_enabled = false; main.sound_effects_enabled = false
	main.battle_speed = 1.0; main.skill_auto = true; main.ultimate_auto = true
	main.daily_dungeon_day = main._today_key(); main.daily_dungeon_runs = 3
	main.weekly_content_key = main._week_key(); main.weekly_trial_runs = 5
	main.tower_floor = 6; main.tower_best_floor = 5
	main.wallet_gold = 10000; main.wallet_gems = 100
	main._build_lobby_screen(); await settle()
	main._build_meta_hub_screen(); await settle(); main._save_idle_state()
	return main
func dispose(main) -> void:
	if main.challenge_session != null: main._build_lobby_screen()
	if main.presentation_runtime != null: main.presentation_runtime.audio.shutdown()
	await create_timer(0.5).timeout
	main.free(); await create_timer(0.35).timeout
func economic(main) -> Dictionary:
	var state: Dictionary = {}
	for field in PRACTICE.SNAPSHOT_FIELDS:
		if field == "last_idle_timestamp": continue
		var value: Variant = main.get(field)
		state[field] = value.duplicate(true) if typeof(value) in [TYPE_DICTIONARY, TYPE_ARRAY] else value
	state["deployed"] = main._deployed_hero_ids().duplicate()
	state["war"] = main.faction_war_state.export_state().duplicate(true)
	return state
func items(main) -> Array[String]:
	var keys: Array[String] = []
	for item in main.loot_inventory: keys.append(str(item.id))
	for id in main.hero_equipment_items:
		for slot in main.hero_equipment_items[id]: keys.append(str(main.hero_equipment_items[id][slot].id))
	keys.sort(); return keys
func done(marker: String) -> void:
	print("%s checks=%d failures=%s" % [marker, checks, JSON.stringify(failures)])
	quit(0 if failures.is_empty() else 1)
