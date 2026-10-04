extends RefCounted
## The live hunt owns one retained screen and one mutable combat state in Main.
## Menus borrow a separate presenter; no second wallet or combat simulation exists.
const FIELDS := ["content_root", "skill_fx_layer", "skill_audio_bus", "combat_labels",
	"hero_map_sprites", "hero_map_offsets", "hero_hp_bars", "enemy_hp_bars", "map_tile_labels",
	"enemy_wave_sprites", "monster_sprite", "raid_boss_sprite", "open_map_boss_sprite",
	"portrait_hud", "_hunt_details_layer", "_hunt_details_shade"]
var ui: Dictionary = {}
var root: Control
var layers: Dictionary = {}
var identity := ""
var party_ids: Array = []

func active() -> bool:
	return is_instance_valid(root) and not root.is_queued_for_deletion()

func _capture(main: Node) -> Dictionary:
	var result: Dictionary = {}
	var properties: Dictionary = {}
	for property in main.get_property_list(): properties[str(property.name)] = true
	for field: String in FIELDS:
		if not properties.has(field): continue
		var value: Variant = main.get(field)
		result[field] = value.duplicate() if value is Array or value is Dictionary else value
	return result

func _apply(main: Node, context: Dictionary) -> void:
	for field in context: main.set(field, context[field])
	main.combat_fx.bind(main.content_root, main.skill_fx_layer)
	main.combat_fx.enabled = main.combat_effects_enabled

func retain(main: Node) -> bool:
	if active(): return true
	if main.active_screen != "combat" or main.challenge_session != null: return false
	main._save_idle_state()
	ui = _capture(main)
	root = main.content_root
	identity = str(main.selected_faction) + "/" + str(main.current_zone_id)
	party_ids = main._deployed_hero_ids().duplicate()
	layers.clear()
	_hide_layers()
	root.hide()
	root.process_mode = Node.PROCESS_MODE_DISABLED
	return true

func clear_presenter(main: Node) -> void:
	for field in ui:
		if field == "content_root": continue
		var value: Variant = main.get(field)
		if value is Array or value is Dictionary:
			var empty: Variant = value.duplicate(); empty.clear(); main.set(field, empty)
		elif value is Node: main.set(field, null)

func discard() -> void:
	if active(): root.queue_free()
	root = null; ui.clear(); layers.clear(); party_ids.clear()

func resume(main: Node) -> bool:
	if not active(): return false
	if identity != str(main.selected_faction) + "/" + str(main.current_zone_id):
		discard(); return false
	var menu_root: Control = main.content_root
	_apply(main, ui)
	main.active_screen = "combat"
	_reconcile_party(main)
	if menu_root != root: menu_root.queue_free()
	root.process_mode = Node.PROCESS_MODE_INHERIT
	root.show()
	for layer in layers:
		if is_instance_valid(layer): layer.visible = bool(layers[layer])
	root = null; ui.clear(); layers.clear()
	main._update_hunt_hud()
	if main.has_method("_portrait_resize"): main._portrait_resize()
	return true

func advance(main: Node, delta: float) -> void:
	if not active(): return
	if identity != str(main.selected_faction) + "/" + str(main.current_zone_id): return
	var menu := _capture(main)
	var screen: String = main.active_screen
	var effects: bool = main.combat_effects_enabled
	var sound: bool = main.sound_effects_enabled
	main.combat_effects_enabled = false; main.sound_effects_enabled = false
	_apply(main, ui)
	main.active_screen = "combat"
	main.set_meta("background_hunt_tick", true)
	_reconcile_party(main)
	main._advance_auto_hunt(delta)
	ui = _capture(main)
	_hide_layers()
	main.set_meta("background_hunt_tick", false)
	main.active_screen = screen
	main.combat_effects_enabled = effects; main.sound_effects_enabled = sound
	_apply(main, menu)

func _reconcile_party(main: Node) -> void:
	var ids: Array = main._deployed_hero_ids()
	if ids == party_ids: return
	var old_states: Dictionary = main.hero_battle_state.duplicate(true)
	var old_runtime: Dictionary = main.hero_skill_runtime.duplicate(true)
	var old_positions: Dictionary = main.party_movement.positions.duplicate()
	var statuses: Dictionary = {}
	for key in ["_guard_seconds", "_weaken_seconds", "_vulnerable_seconds", "_stun_seconds", "_skill_spacing"]: statuses[key] = main.get(key)
	main._setup_hero_skills()
	for id in ids:
		if not old_states.has(id): continue
		var fresh: Dictionary = main.hero_battle_state[id]
		var old: Dictionary = old_states[id]
		var ratio := float(old.hp) / maxf(1.0, float(old.max_hp))
		fresh.hp = maxi(1, roundi(float(fresh.max_hp) * ratio)) if int(old.hp) > 0 else 0
		fresh.alive = int(fresh.hp) > 0
		if old_runtime.has(id):
			var profile: Dictionary = main.hero_skill_runtime[id].profile
			main.hero_skill_runtime[id] = old_runtime[id]
			main.hero_skill_runtime[id].profile = profile
	for key in statuses: main.set(key, statuses[key])
	for actor in main.hero_map_sprites:
		if is_instance_valid(actor): actor.queue_free()
	for bar in main.hero_hp_bars:
		if is_instance_valid(bar): bar.queue_free()
	main._create_map_hero_sprites()
	for id in ids:
		if old_positions.has(id): main.party_movement.positions[id] = old_positions[id]
	main._sync_party_hp_from_heroes()
	party_ids = ids.duplicate()

func _hide_layers() -> void:
	for layer in root.find_children("*", "CanvasLayer", true, false):
		if not layers.has(layer): layers[layer] = layer.visible
		layer.visible = false
