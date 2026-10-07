extends Control

const _FIELD = preload("res://scripts/hunting/HuntFieldService.gd")
const FORMATIONS = preload("res://scripts/combat/BattleFormation.gd")
var invasion := preload("res://scripts/hunting/InvasionWaveState.gd").new()
var formation_id: String = "balanced"
var hunt_autosave: Node
var background_hunt := preload("res://scripts/persistence/BackgroundHunt.gd").new()

# v83 domain services; legacy commands below remain compatible virtual entrypoints.
const _SAVE_FLOW = preload("res://scripts/persistence/GameSaveCoordinator.gd")
const _OFFLINE_REWARDS = preload("res://scripts/persistence/OfflineRewardService.gd")
const _HERO_PROGRESS = preload("res://scripts/heroes/HeroProgressionService.gd")
const _GUARDIAN_PROGRESS = preload("res://scripts/heroes/GuardianProgressionService.gd")
const _SUMMONS = preload("res://scripts/progression/SummonService.gd")
const _LEGACY_QUESTS = preload("res://scripts/progression/LegacyQuestService.gd")
const _REWARD_CLAIMS = preload("res://scripts/progression/RewardClaimService.gd")
const _EQUIPMENT_COMMANDS = preload("res://scripts/equipment/EquipmentCommandService.gd")

const UI := preload("res://scripts/ui/GameUiTheme.gd")
const UI_CHROME := preload("res://scripts/ui/UiChrome.gd")
const LANDING_UI := preload("res://scripts/ui/LandingScreens.gd")
const GROWTH_UI := preload("res://scripts/progression/GrowthInventoryScreens.gd")
const GEAR := preload("res://scripts/equipment/EquipmentRules.gd")
const WORKSHOP := preload("res://scripts/equipment/EquipmentWorkshop.gd")
const GEAR_UI := preload("res://scripts/equipment/EquipmentScreens.gd")
const GEAR_MAIL_CAP := 3000
const GEAR_OVERFLOW_CAP := GEAR_MAIL_CAP # Existing saves and command integrations.

# v80 work-in-progress: shared actual daily combat and clear-gated sweeps.
const CHALLENGE_DRIVER = preload("res://scripts/combat/ChallengeBattleDirector.gd")
var challenge_session: ChallengeBattleSession = null
var challenge_serial: int = 0
var combat_presets: Dictionary = {}
const PRACTICE = preload("res://scripts/progression/PracticeBattleService.gd")
const PRESETS = preload("res://scripts/combat/CombatPresetService.gd")
const SAVE_SAFETY = preload("res://scripts/persistence/SaveSafety.gd")

# v81: persistent long-term goals; counter events come from settled content only.
const GOALS = preload("res://scripts/progression/LongTermGoalsService.gd")
var long_term_goals: Dictionary = {}
var goals_save_pending: bool = false
var goal_claim_busy: bool = false

const BG := Color("#e5e8dc")
const PANEL := Color("#fbf7ed")
const PANEL_SOFT := Color("#edf0e4")
const TEXT := Color("#254239")
const MUTED := Color("#65766b")
const GOLD := Color("#a27130")
const BLUE := Color("#3474ac")
const RED := Color("#b94c57")
const GREEN := Color("#328263")

const MONSTER_SPRITES := {
	"초원 고블린": "res://assets/monsters/gray-meadow-goblin.png",
	"들개 무리": "res://assets/monsters/gray-meadow-wolves.png",
	"가시 멧돼지": "res://assets/monsters/gray-meadow-boar.png",
	"바람 까마귀": "res://assets/monsters/gray-meadow-crow.png",
	"광산 오크": "res://assets/monsters/forgotten-mine-orc.png",
	"철갑 두더지": "res://assets/monsters/forgotten-mine-mole.png",
	"용암 박쥐": "res://assets/monsters/forgotten-mine-bat.png",
	"수정 거미": "res://assets/monsters/forgotten-mine-spider.png",
	"달빛 늑대": "res://assets/monsters/moonrest-wolf.png",
	"숲의 망령": "res://assets/monsters/moonrest-wraith.png",
	"독버섯 정령": "res://assets/monsters/moonrest-mushroom.png",
	"밤까마귀": "res://assets/monsters/moonrest-raven.png",
	"서리 사슴": "res://assets/monsters/moonrest-deer.png"
}

const BOSS_SPRITES := {
	"초원왕 그룬": "res://assets/monsters/gray-meadow-boss.png",
	"광맥의 거인 모르굴": "res://assets/monsters/forgotten-mine-boss.png",
	"월식의 여왕 셀레네": "res://assets/monsters/moonrest-boss.png"
}

var selected_faction := ""
var confirm_button: Button
var selection_hint: Label
var content_root: Control
var faction_cards: Dictionary = {}
var deployed_heroes: Array = []
var hero_slot_labels: Array = []
var hero_select_buttons: Dictionary = {}
var hero_hint: Label
var party_composition_label: Label
var hero_roster_filter := "전체"
var hero_roster_sort := "등급"
var combat_timer: Timer
var combat_running := false
var combat_kills := 0
var combat_hunt_cycle := 0
var combat_progress := 0.0
var combat_tick_count := 0
var combat_engage_settle_remaining := 0.0
var roaming_hunt_seed := 1
var roaming_wave_spawn_cooldown := 0.0
var roaming_last_party_velocity := Vector2.ZERO
var hunt_ai := AutoHuntController.new()
var roaming_hunt := preload("res://scripts/hunting/InvasionHuntDirector.gd").new()
var party_movement := PartyMovementDirector.new()
var field_navigation := preload("res://scripts/hunting/MeadowNavigation.gd").new()
var combat_camera_position := RoamingHuntDirector.FIELD_CENTER
var combat_tactics := AutoCombatTactics.new()
var combat_decisions := CombatDecisionEngine.new()
const FIELD_ECOLOGY = preload("res://scripts/hunting/FieldEcology.gd")
const HUNT_VARIETY = preload("res://scripts/hunting/FieldHuntVariety.gd")
const RAID_REPORT = preload("res://scripts/raid/RaidContributionService.gd")
const HERO_KITS = preload("res://scripts/heroes/HeroKitRuntime.gd")
const HERO_ROSTER = preload("res://scripts/heroes/HeroRosterCatalog.gd")
var hero_identity_catalog := HeroIdentityCatalog.new()
var combat_fx := CombatFxDirector.new()
var idle_hunt_estimator := IdleHuntEstimator.new()
var _rewarded_encounter := -1
# v77: runtime-only hunt variety. No save-schema fields are added.
var hunt_variety_profile: Dictionary = {}
var hunt_event_text := ""
var hunt_combo := 0
var hunt_combo_best := 0
var hunt_combo_remaining := 0.0
var hunt_treasure_captured := false
var hunt_treasure_expired := false
var _hud_elapsed := 0.0
var _save_elapsed := 0.0
var _enemy_attack_remaining := 0.9
var _skill_spacing := 0.0
var _guard_seconds := 0.0
var _weaken_seconds := 0.0
var _vulnerable_seconds := 0.0
var _stun_seconds := 0.0
var _recovery_start_hp := 0
var _offline_checked := false
var _application_suspended := false
var combat_effects_enabled := true
var sound_effects_enabled := true
var _skill_sound_cache: Dictionary = {} # retained for legacy debug callers; no runtime synthesis
var presentation_options: Dictionary = PresentationSettings.DEFAULTS.duplicate(true)
var presentation_settings_error: int = OK
var presentation_runtime: PresentationRuntime
var presentation_preferences_path: String = PresentationSettings.PATH
var wallet_gold := 0
var wallet_xp := 0
var wallet_gems := 0
var unclaimed_gold := 0
var unclaimed_xp := 0
var combat_labels: Dictionary = {}
var monster_sprite: MonsterSpriteController
var raid_boss_sprite: MonsterSpriteController
var open_map_boss_sprite: MonsterSpriteController
var current_zone_id := "gray_meadow"
var selected_raid_id := ""
var expedition_position := RoamingHuntDirector.FIELD_CENTER
var expedition_target := RoamingHuntDirector.FIELD_CENTER
var zone_rotation := 0
var map_tile_labels: Array = []
var hero_map_sprites: Array[HeroSpriteController] = []
var hero_map_offsets: Array[Vector2] = []
var hero_hp_bars: Dictionary = {}
var enemy_hp_bars: Array[ProgressBar] = []
var enemy_name := ""
var enemy_hp := 0
var enemy_max_hp := 0
var enemy_attack := 0
var enemy_wave: Array = []
var enemy_wave_sprites: Array[MonsterSpriteController] = []
var hero_battle_state: Dictionary = {}
var battle_speed := 1.0
var skill_auto := true
var ultimate_auto := true
var party_presets: Array = [[], [], []]
# v46: each faction owns independent party presets; legacy party_presets mirrors the active faction.
var faction_party_presets: Dictionary = {"aurelia": [[], [], []], "noxfera": [[], [], []]}
var active_preset_index := -1
var pet_runtime: Dictionary = {}
var pet_progress: Dictionary = {}
const GUARDIANS := preload("res://scripts/heroes/GuardianCatalog.gd")
var guardian_collection: Dictionary = {}
var guardian_equipped := ""
var guardian_legendary_pity := 0
var guardian_mythic_pity := 0
var guardian_free_claimed := false
var hero_skill_tree: Dictionary = {}
var boss_telegraph_remaining := 0.0
var boss_telegraph_pending := false
var boss_telegraph_skill := ""
var open_map_boss_active := false
var open_map_boss_position := Vector2.ZERO
var open_map_boss_name := ""
var raid_running := false
var raid_boss_name := ""
var raid_boss_hp := 0
var raid_boss_max_hp := 0
var raid_boss_attack := 0
var raid_boss_turns := 0
var raid_boss_attack_remaining := 0.8
var raid_clears: Dictionary = {}
var raid_last_result := ""
# Runtime-only encounter identity prevents stale timers and duplicate settlement.
const RAID_TIME_LIMIT := 240.0
const RAID_ENRAGE_TIME := 180.0
const RAID_STEP := 0.05
const RAID_FIELD := preload("res://scripts/raid/RaidBattlefield.gd")
var raid_encounter_serial := 0
var raid_encounter_zone := ""
var raid_reward_settled := false
var raid_outcome := "ready"
var raid_elapsed := 0.0
var raid_phase := 1
var raid_enraged := false
var raid_control_immunity := 0.0
var raid_interrupt_count := 0
var raid_pattern_count := 0
var raid_pattern_sequence := 0
var raid_damage_dealt := 0
var raid_event_text := ""
var raid_cast_profile: Dictionary = {}
var raid_positions: Dictionary = {}
var raid_boss_position := Vector2(635.0, 397.0)
var raid_rally_position := Vector2.ZERO
var raid_rally_active := false
var raid_pattern_shape: Dictionary = {}
var raid_second_wave_shape: Dictionary = {}
var raid_dodge_remaining := 0.0
var raid_dodge_cooldown := 0.0
var raid_evaded_hits := 0
var raid_second_wave_profile: Dictionary = {}
var raid_second_wave_remaining := 0.0
var raid_hit_fx_remaining := 0.0
var raid_reward_receipt: Dictionary = {}
# v75: runtime-only raid mechanics. No save-schema fields are added.
var raid_break_gauge := 0.0
var raid_break_gauge_max := 100.0
var raid_guard_hp := 0
var raid_guard_max_hp := 0
var raid_guard_breaks := 0
var raid_add_hp := 0
var raid_add_max_hp := 0
var raid_add_count := 0
var raid_add_attack_remaining := 0.0
var raid_add_waves_cleared := 0
var raid_dps_check_remaining := 0.0
var raid_dps_check_target := 0
var raid_dps_check_damage := 0
var raid_dps_checks_passed := 0
var raid_dps_checks_failed := 0
var raid_mechanic_rage_stacks := 0
var raid_last_mechanic_phase := 0
var skill_fx_layer: Control
var skill_audio_bus: AudioStreamPlayer
var skill_fx_sequence := 0
var party_power := 0
var party_hp := 0
var party_max_hp := 0
var hero_skill_runtime: Dictionary = {}
var skill_event_text := ""
var hero_progress: Dictionary = {}
var hero_level_event := ""
var hero_equipment: Dictionary = {}
var hero_equipment_rarity: Dictionary = {}
var hero_equipment_names: Dictionary = {}
var equipment_labels: Dictionary = {}
var loot_inventory: Array = []
var last_drop_text := ""
var loot_rng := RandomNumberGenerator.new()
var active_screen := ""
var idle_stage := 1
var idle_stage_kills := 0
var idle_stage_target := 10
var idle_chest_gold := 0
var idle_chest_xp := 0
var offline_pending_gold := 0
var offline_pending_xp := 0
var offline_pending_chest_gold := 0
var offline_pending_chest_xp := 0
var last_idle_timestamp: int = 0
var offline_reward_gold := 0
var offline_reward_xp := 0
var offline_reward_seconds := 0
var _offline_notice_pending := false
var offline_pet_xp := 0
var offline_rations := 0
var offline_gear_rolls := 0
var offline_stage_clears := 0
var offline_efficiency := 0
var hunt_productivity: Dictionary = {}
var offline_reward_basis: String = ""
var daily_reward_claimed_day := ""
var rewarded_ad_claimed_count := 0
var rewarded_ad_day := ""
var bm_labels: Dictionary = {}
var hero_shards: Dictionary = {}
var hero_breakthrough: Dictionary = {}
var quest_claimed: Dictionary = {}
var tower_floor := 1
var tower_best_floor := 0
var daily_dungeon_runs := 0
var daily_dungeon_day := ""
var daily_dungeon_clears: Dictionary = {}
var codex_seen: Dictionary = {}
var auto_salvage_min_rarity := "일반"
var summon_pity := 0
var hero_ascension: Dictionary = {}
var hero_equipment_sets: Dictionary = {}
var hero_equipment_items: Dictionary = {}
var equipment_overflow: Array = []
var equipment_mail_headers: Dictionary = {}
var pending_equipment_rolls: Dictionary = {}
var raid_crystals := 0
var gear_auto_equip := true
var gear_market_state: Dictionary = {}
var gear_market_service := preload("res://scripts/equipment/EquipmentMarketService.gd").new()
var _gear_market_loaded := false
var gear_workshop_context: Dictionary = {}
var content_party_context: Dictionary = {}
var weekly_content_key := ""
var weekly_trial_runs := 0
var weekly_trial_best := 0
var weekly_trial_legacy_best: int = 0
var weekly_trial_legacy_week: String = ""
var tracked_quest_id := ""
var tutorial_step := 0
var tutorial_completed := false
var tutorial_actions: Dictionary = {}
var party_slot_legacy_cap := 0
var faction_war_state := WorldWarState.new()
var faction_march_state := WorldMarchState.new()
var faction_conflict_state := WorldConflictState.new()
# v46: war/march/conflict snapshots are stored separately per faction so switching sides never reuses the other side's state.
var faction_world_snapshots: Dictionary = {"aurelia": {}, "noxfera": {}}
var world_season_state := WorldSeasonState.new()
var world_authority := WorldAuthorityService.new()
var world_server_gateway := WorldServerGateway.new()
var world_war_client_session := WorldWarClientSession.new()
const SAVE_PATH := "user://pixel_war_save.json"
var save_state_path := SAVE_PATH
var save_store := SaveStore.new()
var last_save_status := ""
var save_load_status := ""
var _save_blocked_for_newer_version := false
var _save_issue_notified := false
const PARTY_CAP := 10
const INVENTORY_CAP := GEAR.INVENTORY_CAP
const IDLE_REWARD_CAP_SECONDS := 8 * 60 * 60
const IDLE_KILL_INTERVAL_SECONDS := 5
const DESIGN_WIDTH := 1280.0
const DESIGN_HEIGHT := 720.0
var combat_field_rect := Rect2(Vector2(55, 198), Vector2(760, 350))
var combat_side_rect := Rect2(Vector2(850, 198), Vector2(375, 310))

func _ready() -> void:
	hunt_autosave = preload("res://scripts/persistence/HuntAutosave.gd").new()
	hunt_autosave.name = "HuntAutosave"
	add_child(hunt_autosave)
	var touch_scroll := preload("res://scripts/ui/TouchScrollController.gd").new()
	touch_scroll.name = "TouchScrollController"
	add_child(touch_scroll)
	theme = UI.make_theme()
	_load_ui_preferences()
	presentation_runtime = PresentationRuntime.new()
	add_child(presentation_runtime)
	presentation_runtime.bind(self)
	_configure_mobile_display()
	loot_rng.randomize()
	_load_idle_state()
	# Settle the saved expedition before any menu action can advance its receipt
	# timestamp or replace its party, region or equipment.
	if not deployed_heroes.is_empty():
		_calculate_offline_reward()
	_enter_game()

func _enter_game() -> void:
	# Returning expeditions open on the live field; new players keep onboarding.
	if _save_blocked_for_newer_version:
		_build_login_screen()
	elif selected_faction in ["aurelia", "noxfera"]:
		_open_home()
	else:
		_build_title_screen()

func _open_home() -> void:
	if _save_blocked_for_newer_version:
		_build_login_screen()
		return
	if selected_faction not in ["aurelia", "noxfera"]:
		_build_faction_screen()
		return
	content_party_context.clear()
	if deployed_heroes.is_empty():
		_build_hero_select_screen()
		return
	if background_hunt.resume(self):
		_maybe_show_offline_reward_popup()
		return
	# Repeated Home taps retain the encounter, HP, timers and manual pause.
	if active_screen == "combat" and challenge_session == null:
		_maybe_show_offline_reward_popup()
		return
	_build_combat_screen()

func _configure_mobile_display() -> void:
	if OS.has_feature("mobile"):
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_LANDSCAPE)
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

func _layout_width() -> float:
	return maxf(DESIGN_WIDTH, get_viewport_rect().size.x)

func _layout_height() -> float:
	return maxf(DESIGN_HEIGHT, get_viewport_rect().size.y)

func _safe_margins() -> Vector4:
	var left := 28.0
	var top := 18.0
	var right := 28.0
	var bottom := 14.0
	if OS.has_feature("mobile"):
		var safe: Rect2i = DisplayServer.get_display_safe_area()
		var screen_size: Vector2i = DisplayServer.screen_get_size(DisplayServer.SCREEN_OF_MAIN_WINDOW)
		var viewport_size := get_viewport_rect().size
		if screen_size.x > 0 and screen_size.y > 0 and safe.size.x > 0 and safe.size.y > 0:
			var scale_x := viewport_size.x / float(screen_size.x)
			var scale_y := viewport_size.y / float(screen_size.y)
			left = maxf(left, float(safe.position.x) * scale_x + 8.0)
			top = maxf(top, float(safe.position.y) * scale_y + 6.0)
			right = maxf(right, float(screen_size.x - safe.position.x - safe.size.x) * scale_x + 8.0)
			bottom = maxf(bottom, float(screen_size.y - safe.position.y - safe.size.y) * scale_y + 6.0)
	return Vector4(left, top, right, bottom)

func _mobile_wide_layout() -> bool:
	return _layout_width() >= 1420.0

func _combat_actor_scale() -> float:
	# A wider display reveals more of the world rather than inflating actors.
	return 0.065

func _combat_layout_for_width(layout_w: float, safe: Vector4) -> Dictionary:
	var left := maxf(28.0, safe.x)
	var usable := layout_w - left - maxf(28.0, safe.z)
	var field_top := maxf(76.0, safe.y + 58.0)
	return {"left": left, "usable": usable,
		"field": Rect2(Vector2(left, field_top), Vector2(usable, 536.0 - field_top)),
		"side": Rect2(Vector2(left + usable - 372, field_top + 62), Vector2(360, 380))}

func _physics_process(delta: float) -> void:
	# A stall or resuming a backgrounded app must not burst overdue attacks.
	if not _application_suspended:
		_advance_auto_hunt(delta)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_handle_android_back()
	elif what == NOTIFICATION_APPLICATION_PAUSED and not _application_suspended:
		_application_suspended = true
		if is_instance_valid(presentation_runtime): presentation_runtime.sync_context()
		_save_idle_state()
	elif what == NOTIFICATION_APPLICATION_RESUMED and _application_suspended:
		_application_suspended = false
		if bool(get_meta("practice_active", false)):
			if is_instance_valid(presentation_runtime): presentation_runtime.sync_context()
			return
		if is_instance_valid(presentation_runtime): presentation_runtime.sync_context()
		if not deployed_heroes.is_empty():
			_offline_checked = false
			_calculate_offline_reward()
			_update_reward_labels()
		if active_screen == "combat":
			_maybe_show_offline_reward_popup()
		elif active_screen == "faction_war":
			world_war_client_session.reconnect_and_resync()
			_save_idle_state()
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save_idle_state()

func _handle_android_back() -> void:
	# Share Escape's presenter-specific dialog handling with Android's back button.
	var event := InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.pressed = true
	get_viewport().push_input(event, true)
	var consumed := get_viewport().is_input_handled()
	var release := InputEventKey.new()
	release.keycode = KEY_ESCAPE
	get_viewport().push_input(release, true)
	if not consumed and active_screen not in ["combat", "title", "login", "faction"]:
		_open_home()

func _clear_screen(keep_hunt: bool = false) -> void:
	var retained := keep_hunt and background_hunt.retain(self)
	if retained:
		active_screen = ""
		background_hunt.clear_presenter(self)
		for child in get_children():
			if child == background_hunt.root or child == presentation_runtime or child.name in ["SaveSafetyLayer", "TouchScrollController", "HuntAutosave"]: continue
			child.queue_free()
		_new_screen_root()
		return
	if background_hunt.active(): _save_idle_state()
	background_hunt.discard()
	if challenge_session != null and challenge_session.practice:
		challenge_session.cancel("left_screen")
		CHALLENGE_DRIVER.publish_report(self, challenge_session)
		PRACTICE.restore(self)
		challenge_session = null
	if challenge_session != null:
		challenge_session.cancel("left_screen")
		CHALLENGE_DRIVER.publish_report(self, challenge_session)
		challenge_session = null
	if active_screen == "combat" or active_screen == "raid":
		_save_idle_state()
	active_screen = ""
	combat_running = false
	raid_running = false
	boss_telegraph_pending = false
	boss_telegraph_remaining = 0.0
	if is_instance_valid(combat_timer):
		combat_timer.stop()
	combat_timer = null
	hero_map_sprites.clear()
	hero_map_offsets.clear()
	hero_hp_bars.clear()
	enemy_hp_bars.clear()
	map_tile_labels.clear()
	combat_labels.clear()
	equipment_labels.clear()
	for enemy_sprite in enemy_wave_sprites:
		if is_instance_valid(enemy_sprite):
			enemy_sprite.queue_free()
	enemy_wave_sprites.clear()
	enemy_wave.clear()
	hero_battle_state.clear()
	monster_sprite = null
	raid_boss_sprite = null
	open_map_boss_sprite = null
	for child in get_children():
		# Audio/settings, input and save recovery belong to the game root.
		if child == presentation_runtime or child.name in ["SaveSafetyLayer", "TouchScrollController", "HuntAutosave"]: continue
		child.queue_free()
	_new_screen_root()

func _new_screen_root() -> void:
	content_root = Control.new()
	content_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(content_root)
	if not content_party_context.is_empty():
		_validate_content_party_route.call_deferred(content_root.get_instance_id())
	_build_background()
	skill_fx_layer = Control.new()
	skill_fx_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	skill_fx_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	skill_fx_layer.z_index = 20
	content_root.add_child(skill_fx_layer)
	combat_fx.bind(content_root, skill_fx_layer)
	combat_fx.enabled = combat_effects_enabled
	skill_audio_bus = AudioStreamPlayer.new()
	content_root.add_child(skill_audio_bus)

func _skill_visual_profile(role_group: String) -> Dictionary:
	return {
		"탱커": {"color": Color("#55b9ff"), "symbol": "✦", "sound": 180.0},
		"딜러": {"color": Color("#ff5e78"), "symbol": "✹", "sound": 520.0},
		"서포터": {"color": Color("#6ef0a0"), "symbol": "✧", "sound": 360.0},
		"컨트롤러": {"color": Color("#c28cff"), "symbol": "◇", "sound": 260.0}
	}.get(role_group, {"color": GOLD, "symbol": "★", "sound": 300.0})

func _emit_skill_fx(hero: Dictionary, profile: Dictionary, dealt: int) -> void:
	if not is_instance_valid(skill_fx_layer):
		return
	var visual: Dictionary = _skill_visual_profile(str(profile["role_group"]))
	# Record the event even when the battle field supplies its own positioned FX.
	skill_fx_sequence += 1
	# Sound is independent of optional cosmetic effects.
	if active_screen in ["combat", "raid"]:
		_play_skill_sound(float(visual["sound"]), str(profile["role_group"]))
		return
	if not combat_effects_enabled:
		return
	var fx_color: Color = visual["color"]
	var impact_center := Vector2(535, 365) if active_screen == "raid" else Vector2(695, 335)
	if str(profile.get("kind", "damage")) == "heal" and active_screen == "combat":
		impact_center = _map_world_position(expedition_position)
	var flash := ColorRect.new()
	flash.color = Color(fx_color, 0.10)
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	skill_fx_layer.add_child(flash)
	var flash_tween := content_root.create_tween()
	flash_tween.tween_property(flash, "color", Color(fx_color, 0.0), 0.24)
	flash_tween.tween_callback(flash.queue_free)
	_emit_fx_ring(impact_center, 42.0, fx_color, 0.32)
	_emit_fx_ring(impact_center, 92.0, Color(fx_color, 0.62), 0.48)
	for ray_index in range(8):
		var ray := ColorRect.new()
		ray.color = Color(fx_color, 0.88)
		ray.size = Vector2(5, 72 if ray_index % 2 == 0 else 48)
		ray.position = impact_center - Vector2(2.5, ray.size.y)
		ray.pivot_offset = Vector2(2.5, ray.size.y)
		ray.rotation = TAU * float(ray_index) / 8.0
		ray.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ray.modulate = Color(1, 1, 1, 0)
		skill_fx_layer.add_child(ray)
		var ray_tween := content_root.create_tween().set_parallel(true)
		ray_tween.tween_property(ray, "modulate", Color.WHITE, 0.06)
		ray_tween.tween_property(ray, "scale", Vector2(1.0, 1.35), 0.12)
		ray_tween.chain().tween_property(ray, "modulate", Color(1, 1, 1, 0), 0.28)
		ray_tween.chain().tween_callback(ray.queue_free)
	for particle_index in range(6):
		var particle := _label(str(visual["symbol"]), 18, fx_color)
		particle.position = impact_center + Vector2(-70 + particle_index * 23, -12)
		particle.size = Vector2(24, 24)
		particle.mouse_filter = Control.MOUSE_FILTER_IGNORE
		particle.modulate = Color(1, 1, 1, 0)
		skill_fx_layer.add_child(particle)
		var particle_target := impact_center + Vector2(cos(TAU * particle_index / 6.0), sin(TAU * particle_index / 6.0)) * 105.0
		var particle_tween := content_root.create_tween().set_parallel(true)
		particle_tween.tween_property(particle, "modulate", Color.WHITE, 0.08)
		particle_tween.tween_property(particle, "position", particle_target, 0.42)
		particle_tween.tween_property(particle, "scale", Vector2(1.35, 1.35), 0.28)
		particle_tween.chain().tween_property(particle, "modulate", Color(1, 1, 1, 0), 0.18)
		particle_tween.chain().tween_callback(particle.queue_free)
	var banner := Label.new()
	banner.text = "%s  %s\n%s" % [visual["symbol"], profile["skill"], ("피해 %d" % dealt) if dealt > 0 else str(profile["effect"])]
	banner.position = Vector2(470, 255)
	banner.size = Vector2(340, 100)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	banner.add_theme_font_size_override("font_size", 25)
	banner.add_theme_color_override("font_color", fx_color)
	banner.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	banner.add_theme_constant_override("shadow_offset_x", 3)
	banner.add_theme_constant_override("shadow_offset_y", 3)
	banner.modulate = Color(1, 1, 1, 0)
	banner.scale = Vector2(0.72, 0.72)
	banner.pivot_offset = Vector2(170, 50)
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	skill_fx_layer.add_child(banner)
	var banner_tween := content_root.create_tween().set_parallel(true)
	banner_tween.tween_property(banner, "modulate", Color.WHITE, 0.10)
	banner_tween.tween_property(banner, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	banner_tween.chain().tween_property(banner, "position", Vector2(470, 215), 0.42)
	banner_tween.parallel().tween_property(banner, "modulate", Color(1, 1, 1, 0), 0.42)
	banner_tween.chain().tween_callback(banner.queue_free)
	_emit_v11_skill_signature(impact_center, profile, fx_color)
	_play_skill_sound(float(visual["sound"]), str(profile["role_group"]))

func _emit_v11_skill_signature(center: Vector2, profile: Dictionary, color: Color) -> void:
	var kind := str(profile.get("kind", "damage"))
	if kind == "heal":
		for index in range(4):
			var cross := _label("✚", 24, color)
			cross.position = center + Vector2(-72 + index * 48, 30 + (index % 2) * 18)
			cross.size = Vector2(32, 32)
			cross.mouse_filter = Control.MOUSE_FILTER_IGNORE
			skill_fx_layer.add_child(cross)
			var tween := content_root.create_tween().set_parallel(true)
			tween.tween_property(cross, "position", cross.position + Vector2(0, -88), 0.55)
			tween.tween_property(cross, "modulate:a", 0.0, 0.55)
			tween.chain().tween_callback(cross.queue_free)
		return
	if kind in ["guard", "taunt"]:
		var shield := Panel.new()
		shield.position = center - Vector2(50, 58)
		shield.size = Vector2(100, 116)
		shield.mouse_filter = Control.MOUSE_FILTER_IGNORE
		shield.add_theme_stylebox_override("panel", _panel_style(Color(color, 0.08), Color(color, 0.9), 22, 4))
		shield.scale = Vector2(0.65, 0.65)
		shield.pivot_offset = Vector2(50, 58)
		skill_fx_layer.add_child(shield)
		var shield_tween := content_root.create_tween().set_parallel(true)
		shield_tween.tween_property(shield, "scale", Vector2(1.15, 1.15), 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		shield_tween.tween_property(shield, "modulate:a", 0.0, 0.48).set_delay(0.18)
		shield_tween.chain().tween_callback(shield.queue_free)
		return
	if kind in ["stun", "vulnerable", "weaken"]:
		var break_text := _label("BREAK", 20, color)
		break_text.position = center - Vector2(70, 70)
		break_text.size = Vector2(140, 34)
		break_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
		skill_fx_layer.add_child(break_text)
		var break_tween := content_root.create_tween().set_parallel(true)
		break_tween.tween_property(break_text, "scale", Vector2(1.5, 1.5), 0.28)
		break_tween.tween_property(break_text, "modulate:a", 0.0, 0.42).set_delay(0.12)
		break_tween.chain().tween_callback(break_text.queue_free)
		return
	for index in range(3):
		var slash := ColorRect.new()
		slash.color = Color(color, 0.85)
		slash.size = Vector2(150, 5)
		slash.position = center + Vector2(-95, -38 + index * 34)
		slash.rotation = -0.45 + index * 0.10
		slash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slash.scale = Vector2(0.2, 1.0)
		slash.pivot_offset = Vector2(75, 2.5)
		skill_fx_layer.add_child(slash)
		var slash_tween := content_root.create_tween().set_parallel(true)
		slash_tween.tween_property(slash, "scale", Vector2(1.2, 1.0), 0.14 + index * 0.025)
		slash_tween.tween_property(slash, "modulate:a", 0.0, 0.30).set_delay(0.12)
		slash_tween.chain().tween_callback(slash.queue_free)

func _emit_fx_ring(center: Vector2, diameter: float, color: Color, duration: float) -> void:
	var ring := Panel.new()
	ring.position = center - Vector2(diameter / 2.0, diameter / 2.0)
	ring.size = Vector2(diameter, diameter)
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ring_style := _panel_style(Color(0, 0, 0, 0), color, 999, 3)
	ring.add_theme_stylebox_override("panel", ring_style)
	ring.modulate = Color(1, 1, 1, 0.0)
	ring.scale = Vector2(0.35, 0.35)
	ring.pivot_offset = Vector2(diameter / 2.0, diameter / 2.0)
	skill_fx_layer.add_child(ring)
	var tween := content_root.create_tween().set_parallel(true)
	tween.tween_property(ring, "modulate", Color.WHITE, 0.05)
	tween.tween_property(ring, "scale", Vector2.ONE, duration * 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.chain().tween_property(ring, "modulate", Color(1, 1, 1, 0), duration * 0.45)
	tween.chain().tween_callback(ring.queue_free)

func _play_skill_sound(_frequency: float, role_group: String) -> void:
	_presentation_event({"탱커": "guard", "딜러": "magic", "서포터": "heal", "컨트롤러": "control"}.get(role_group, "magic"))

func _build_background() -> void:
	content_root.add_child(UI.background(Vector2(_layout_width(), _layout_height())))

func _label(text_value: String, font_size: int, color: Color = TEXT) -> Label:
	return UI.label(text_value, font_size, color)

func _panel_style(color: Color, border_color: Color = Color.TRANSPARENT, radius := 12, width := 0) -> StyleBoxFlat:
	return UI.panel(color, border_color, radius, width)

func _button(text_value: String, min_size: Vector2, color: Color = PANEL_SOFT) -> Button:
	return UI.button(text_value, min_size, color)

func _faction_name() -> String:
	if selected_faction == "aurelia":
		return "아우렐리아 연합"
	if selected_faction == "noxfera":
		return "녹스페라 연맹"
	return "진영 미선택"

func _faction_accent() -> Color:
	if selected_faction == "aurelia":
		return Color("#4c8fe8")
	if selected_faction == "noxfera":
		return Color("#c95770")
	return GOLD

func _hero_faction(hero_id: String) -> String:
	return str(HERO_ROSTER.HEROES.get(hero_id, {}).get("faction", ""))

func _hero_belongs_to_selected_faction(hero_id: String) -> bool:
	return selected_faction in ["aurelia", "noxfera"] and _hero_faction(hero_id) == selected_faction

func _clean_party_ids_for_faction(ids: Array, faction_id: String) -> Array:
	var clean: Array = []
	if faction_id not in ["aurelia", "noxfera"]:
		return clean
	for raw_id in ids:
		var hero_id := str(raw_id)
		if _hero_faction(hero_id) == faction_id and hero_id not in clean:
			clean.append(hero_id)
			if clean.size() >= PARTY_CAP:
				break
	return clean

func _normalize_faction_party_presets() -> void:
	for faction_id in ["aurelia", "noxfera"]:
		var source = faction_party_presets.get(faction_id, [[], [], []])
		var clean: Array = [[], [], []]
		if typeof(source) == TYPE_ARRAY:
			for preset_index in range(mini(3, source.size())):
				if typeof(source[preset_index]) == TYPE_ARRAY:
					clean[preset_index] = _clean_party_ids_for_faction(source[preset_index], faction_id)
		faction_party_presets[faction_id] = clean

func _stash_active_faction_presets() -> void:
	if selected_faction not in ["aurelia", "noxfera"]:
		return
	var clean: Array = [[], [], []]
	for index in range(mini(3, party_presets.size())):
		if typeof(party_presets[index]) == TYPE_ARRAY:
			clean[index] = _clean_party_ids_for_faction(party_presets[index], selected_faction)
	faction_party_presets[selected_faction] = clean

func _load_active_faction_presets() -> void:
	_normalize_faction_party_presets()
	party_presets = faction_party_presets.get(selected_faction, [[], [], []]).duplicate(true) if selected_faction in ["aurelia", "noxfera"] else [[], [], []]
	active_preset_index = clampi(active_preset_index, -1, 2)

func _stash_active_faction_world() -> void:
	if selected_faction not in ["aurelia", "noxfera"]:
		return
	faction_world_snapshots[selected_faction] = {
		"season_number": world_season_state.season_number,
		"war": faction_war_state.export_state(),
		"march": faction_march_state.export_state(),
		"conflict": faction_conflict_state.export_state()
	}

func _load_active_faction_world() -> void:
	faction_war_state = WorldWarState.new()
	faction_march_state = WorldMarchState.new()
	faction_conflict_state = WorldConflictState.new()
	if selected_faction not in ["aurelia", "noxfera"]:
		return
	var snapshot = faction_world_snapshots.get(selected_faction, {})
	if typeof(snapshot) == TYPE_DICTIONARY:
		var war = snapshot.get("war", {})
		var march = snapshot.get("march", {})
		var conflict = snapshot.get("conflict", {})
		if typeof(war) == TYPE_DICTIONARY and not war.is_empty():
			faction_war_state.import_state(war)
		if typeof(march) == TYPE_DICTIONARY and not march.is_empty():
			faction_march_state.import_state(march)
		if typeof(conflict) == TYPE_DICTIONARY and not conflict.is_empty():
			faction_conflict_state.import_state(conflict)
		var saved_season := WorldWarState.safe_int(snapshot.get("season_number", world_season_state.season_number), world_season_state.season_number)
		if saved_season < world_season_state.season_number:
			# Inactive faction banks must follow the global season too. initialize_new
			# preserves earned honor; territory, wounds and tactics are seasonal.
			faction_war_state.initialize_new(selected_faction)
			faction_war_state.rations = WorldWarState.STARTING_RATIONS
			faction_conflict_state.reset_for_new_season()
			faction_march_state.reset()
	faction_war_state.ensure_initialized(selected_faction)
	if not faction_march_state.faction.is_empty() and faction_march_state.faction != selected_faction:
		faction_march_state = WorldMarchState.new()
	_stash_active_faction_world()

func _sanitize_deployed_party_for_faction() -> void:
	if selected_faction not in ["aurelia", "noxfera"]:
		deployed_heroes.clear()
		return
	var clean: Array = []
	var seen: Dictionary = {}
	for hero in deployed_heroes:
		var hero_id := str(hero.get("id", ""))
		if _hero_faction(hero_id) == selected_faction and not seen.has(hero_id):
			clean.append(hero)
			seen[hero_id] = true
	deployed_heroes = clean.slice(0, _party_slot_cap())

func _create_metric_card(title: String, value: String, detail: String, accent: Color, min_size: Vector2 = Vector2(0, 88)) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = min_size
	card.add_theme_stylebox_override("panel", _panel_style(Color("#15223b"), Color(accent, 0.9), 14, 1))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	card.add_child(box)
	var top := _label(title, 12, Color(accent, 0.95))
	top.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	box.add_child(top)
	var mid := _label(value, 21, TEXT)
	mid.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	mid.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(mid)
	var bottom := _label(detail, 11, MUTED)
	bottom.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	bottom.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(bottom)
	return card

func _add_screen_header(back_text: String, back_action: Callable, title_text: String, subtitle_text: String, badge_text: String = "", accent: Color = GOLD, wallet_text: String = "") -> void:
	UI_CHROME.header(self, back_text, back_action, title_text, subtitle_text, badge_text, accent, wallet_text)

func _add_status_dashboard(position: Vector2, cards: Array, columns: int = 4, size: Vector2 = Vector2(1170, 96)) -> void:
	var grid := GridContainer.new()
	grid.name = "StatusDashboard"
	grid.columns = columns
	var safe := _safe_margins()
	var resolved_position := position
	var resolved_size := size
	if absf(size.x - 1170.0) < 1.0 and absf(position.x - 55.0) < 2.0:
		resolved_position.x = maxf(55.0, safe.x)
		resolved_size.x = _layout_width() - resolved_position.x - maxf(55.0, safe.z)
	grid.position = resolved_position
	grid.size = resolved_size
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	content_root.add_child(grid)
	for card in cards:
		grid.add_child(card)

func _build_title_screen() -> void:
	LANDING_UI.title(self)

func _build_login_screen() -> void:
	LANDING_UI.login(self)

func _show_main_menu() -> void:
	UI_CHROME.menu(self)

func _today_key() -> String:
	# Shared daily reset uses Korea time, independent of the device timezone.
	var date := Time.get_date_dict_from_unix_time(int(Time.get_unix_time_from_system()) + 9 * 3600)
	return "%04d-%02d-%02d" % [date.year, date.month, date.day]

func _claim_daily_reward(button: Button, status: Label) -> void:
	_REWARD_CLAIMS.claim_daily_reward(self, button, status)

func _claim_rewarded_ad(button: Button, status: Label) -> void:
	_REWARD_CLAIMS.claim_rewarded_ad(self, button, status)

func _build_bm_screen() -> void:
	ContentScreens.bm(self)

func _build_lobby_screen() -> void:
	LANDING_UI.lobby(self)

func _lobby_deploy() -> void:
	if selected_faction.is_empty():
		_build_faction_screen()
	else:
		_build_hero_select_screen()

func _lobby_start_hunt() -> void:
	_open_home()

func _build_faction_screen() -> void:
	OnboardingScreens.faction(self)

func _create_faction_card(id: String, title: String, species: String, doctrine: String, description: String, traits: Array[String], accent: Color, sigil: String) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(516, 300)
	card.add_theme_stylebox_override("panel", _panel_style(PANEL, Color("#2b3b60"), 14, 1))
	faction_cards[id] = card

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 7)
	root.add_theme_stylebox_override("panel", _panel_style(PANEL, Color.TRANSPARENT, 14, 0))
	card.add_child(root)

	var top := HBoxContainer.new()
	top.custom_minimum_size = Vector2(0, 76)
	root.add_child(top)

	var sigil_label := _label(sigil, 48, accent)
	sigil_label.custom_minimum_size = Vector2(92, 76)
	top.add_child(sigil_label)

	var names := VBoxContainer.new()
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(names)
	var title_label := _label(title, 25, TEXT)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	names.add_child(title_label)
	var species_label := _label(species, 14, accent)
	species_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	names.add_child(species_label)

	var doctrine_label := _label(doctrine, 16, GOLD)
	doctrine_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	doctrine_label.custom_minimum_size = Vector2(0, 30)
	root.add_child(doctrine_label)

	var body := _label(description, 14, MUTED)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(0, 44)
	root.add_child(body)

	var trait_row := HBoxContainer.new()
	trait_row.add_theme_constant_override("separation", 6)
	root.add_child(trait_row)
	for trait_text in traits:
		var tag := _label(trait_text, 12, accent)
		tag.custom_minimum_size = Vector2(0, 30)
		tag.add_theme_stylebox_override("normal", _panel_style(Color("#202c47"), Color("#30466f"), 6, 1))
		trait_row.add_child(tag)

	var select := _button("이 진영 살펴보기", Vector2(0, 46), accent.darkened(0.5))
	select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	select.pressed.connect(func(): _select_faction(id))
	root.add_child(select)
	return card

func _select_faction(id: String) -> void:
	if bool(get_meta("practice_active", false)) or preload("res://scripts/persistence/SaveSafety.gd").pending(self):
		_show_toast("연습을 종료하거나 저장 대기를 먼저 해결해 주세요."); return
	if id not in ["aurelia", "noxfera"]:
		return
	if selected_faction in ["aurelia", "noxfera"]:
		_stash_active_faction_presets()
		_stash_active_faction_world()
	if selected_faction != id:
		deployed_heroes.clear()
	selected_faction = id
	_load_active_faction_presets()
	_load_active_faction_world()
	for faction_id in faction_cards.keys():
		var card: PanelContainer = faction_cards[faction_id]
		var accent := Color("#4c8fe8") if faction_id == "aurelia" else Color("#c95770")
		var border := accent if faction_id == id else Color("#2b3b60")
		var width := 3 if faction_id == id else 1
		card.add_theme_stylebox_override("panel", _panel_style(PANEL, border, 14, width))

	var faction_name := "아우렐리아 연합" if id == "aurelia" else "녹스페라 연맹"
	if is_instance_valid(selection_hint):
		selection_hint.text = "%s을(를) 선택했습니다. 아래 버튼으로 확정하세요." % faction_name
		selection_hint.add_theme_color_override("font_color", GOLD)
	if is_instance_valid(confirm_button):
		confirm_button.text = "%s으로 시작하기" % faction_name
		confirm_button.disabled = false

func _confirm_faction() -> void:
	if selected_faction.is_empty():
		return
	_build_intro_screen()

func _build_intro_screen() -> void:
	OnboardingScreens.intro(self)

func _hero_roster_for_faction() -> Array:
	return HERO_ROSTER.roster(selected_faction)

func _deployed_hero_ids() -> Array[String]:
	var ids: Array[String] = []
	for hero in deployed_heroes:
		ids.append(str(hero.get("id", "")))
	return ids

func _restore_deployed_heroes(hero_ids: Array) -> void:
	deployed_heroes.clear()
	if selected_faction not in ["aurelia", "noxfera"]:
		return
	var allowed_ids := _clean_party_ids_for_faction(hero_ids, selected_faction)
	var roster := _hero_roster_for_faction()
	for saved_id in allowed_ids:
		for hero in roster:
			if str(hero["id"]) == str(saved_id) and deployed_heroes.size() < PARTY_CAP:
				deployed_heroes.append(hero)
				break
	_sanitize_deployed_party_for_faction()

func _save_party_preset(index: int) -> void:
	var result: Dictionary = PRESETS.save(self, index)
	_show_toast(str(result.get("reason", "")))
	if is_instance_valid(hero_hint): hero_hint.text = str(result.get("reason", ""))

func _apply_party_preset(index: int) -> void:
	var stored: Dictionary = PRESETS.get_preset(self, index)
	if stored.is_empty():
		if PRESETS.entry_error(self).is_empty(): _apply_legacy_party_preset(index)
		return
	var result: Dictionary = PRESETS.apply(self, index)
	_show_toast(str(result.get("reason", "")))
	if is_instance_valid(hero_hint): hero_hint.text = str(result.get("reason", ""))

func _apply_legacy_party_preset(index: int) -> void:
	if selected_faction not in ["aurelia", "noxfera"]:
		return
	_load_active_faction_presets()
	if index < 0 or index >= party_presets.size() or typeof(party_presets[index]) != TYPE_ARRAY:
		return
	var saved_ids: Array = _clean_party_ids_for_faction(party_presets[index], selected_faction)
	if saved_ids.is_empty():
		if is_instance_valid(hero_hint):
			hero_hint.text = "P%d 프리셋이 비어 있습니다. 먼저 현재 편성을 저장하세요." % (index + 1)
		return
	var unlocked_ids: Array = []
	for saved_id in saved_ids:
		for hero in _hero_roster_for_faction():
			if str(hero["id"]) == str(saved_id) and idle_stage >= int(hero.get("unlock_stage", 1)):
				unlocked_ids.append(saved_id)
				break
	if unlocked_ids.is_empty():
		if is_instance_valid(hero_hint):
			hero_hint.text = "P%d에는 현재 진영에서 사용할 수 있는 영웅이 없습니다." % (index + 1)
		return
	var cap := _party_slot_cap()
	_restore_deployed_heroes(unlocked_ids.slice(0, cap))
	active_preset_index = index
	if active_screen == "hero_select":
		_refresh_party_slots(Color("#4c8fe8") if selected_faction == "aurelia" else Color("#c95770"))
	_save_idle_state()
	if is_instance_valid(hero_hint):
		hero_hint.text = "P%d 편성을 적용했습니다. 현재 %d/%d명입니다." % [index + 1, deployed_heroes.size(), _party_slot_cap()]

func _cycle_battle_speed(button: Button = null) -> void:
	battle_speed = 2.0 if battle_speed < 1.5 else 1.0
	if is_instance_valid(button):
		button.text = "×%d" % int(battle_speed)
	_save_idle_state()

func _party_progression_cap() -> int:
	if idle_stage >= 25:
		return 10
	if idle_stage >= 15:
		return 7
	if idle_stage >= 8:
		return 5
	if idle_stage >= 3:
		return 3
	return 1

func _party_slot_cap() -> int:
	return clampi(maxi(_party_progression_cap(), party_slot_legacy_cap), 1, PARTY_CAP)

func _party_slot_unlock_stage(index: int) -> int:
	if index <= 0:
		return 1
	if index <= 2:
		return 3
	if index <= 4:
		return 8
	if index <= 6:
		return 15
	return 25

func _party_next_unlock_text() -> String:
	var cap := _party_slot_cap()
	if cap >= PARTY_CAP:
		return "10인 원정대 완전 개방"
	return "다음 편성 확장 · 스테이지 %d" % _party_slot_unlock_stage(cap)

func _party_slot_name(index: int) -> String:
	if index < 3:
		return "전열 %d" % (index + 1)
	if index < 7:
		return "중열 %d" % (index - 2)
	return "후열 %d" % (index - 6)

func _faction_identity_summary() -> String:
	if selected_faction == "aurelia":
		return "아우렐리아 · 수호/정밀/회복 중심 · 장기전 안정형"
	if selected_faction == "noxfera":
		return "녹스페라 · 흡혈/광폭/약화 중심 · 공격 템포형"
	return "진영 특성 없음"

func _party_composition_summary() -> String:
	var roles := {"탱커":0,"딜러":0,"서포터":0,"컨트롤러":0}
	for hero in deployed_heroes:
		var role_group := str(_hero_skill_profile(str(hero.get("id",""))).get("role_group","딜러"))
		roles[role_group] = int(roles.get(role_group,0)) + 1
	return "탱 %d · 딜 %d · 지원 %d · 제어 %d" % [
		int(roles.get("탱커",0)), int(roles.get("딜러",0)),
		int(roles.get("서포터",0)), int(roles.get("컨트롤러",0))
	]

func _party_composition_hint() -> String:
	if deployed_heroes.is_empty():
		return "첫 영웅을 배치하세요."
	var roles := {"탱커":0,"딜러":0,"서포터":0,"컨트롤러":0}
	for hero in deployed_heroes:
		var role_group := str(_hero_skill_profile(str(hero.get("id",""))).get("role_group","딜러"))
		roles[role_group] = int(roles.get(role_group,0)) + 1
	if deployed_heroes.size() >= 3 and int(roles["탱커"]) == 0:
		return "전열 탱커가 없어 후열이 빨리 노출됩니다."
	if deployed_heroes.size() >= 3 and int(roles["딜러"]) == 0:
		return "딜러가 없어 전투 시간이 길어질 수 있습니다."
	if deployed_heroes.size() >= 5 and int(roles["서포터"]) == 0:
		return "장기 사냥용 회복 영웅을 고려하세요."
	if deployed_heroes.size() >= 6 and int(roles["컨트롤러"]) == 0:
		return "정예·보스 대응용 제어 영웅이 있으면 안정적입니다."
	return "역할 균형 양호 · %s" % _calculate_party_synergy().get("summary","")

func _hero_grade_color(hero_id: String) -> Color:
	return {"R":Color("#9ba9c7"),"SR":Color("#58a6ff"),"SSR":Color("#c28cff"),"UR":Color("#ffb84d")}.get(_hero_grade(hero_id), TEXT)

func _hero_role_group(hero_id: String) -> String:
	return str(_hero_skill_profile(hero_id).get("role_group","딜러"))

func _filtered_sorted_roster(roster: Array) -> Array:
	var result: Array = []
	for hero_value in roster:
		var hero: Dictionary = hero_value
		var hero_id := str(hero.get("id",""))
		if hero_roster_filter != "전체" and _hero_role_group(hero_id) != hero_roster_filter:
			continue
		result.append(hero)
	result.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:
		var a_id := str(a.get("id",""))
		var b_id := str(b.get("id",""))
		if hero_roster_sort == "레벨":
			var al := int(_get_hero_progress(a_id).get("level",1))
			var bl := int(_get_hero_progress(b_id).get("level",1))
			if al != bl: return al > bl
		elif hero_roster_sort == "전투력":
			var ap := _equipment_power(a_id) + int(_get_hero_progress(a_id).get("level",1)) * 35
			var bp := _equipment_power(b_id) + int(_get_hero_progress(b_id).get("level",1)) * 35
			if ap != bp: return ap > bp
		else:
			var ranks := {"R":1,"SR":2,"SSR":3,"UR":4}
			var ar := int(ranks.get(_hero_grade(a_id),1))
			var br := int(ranks.get(_hero_grade(b_id),1))
			if ar != br: return ar > br
		return str(a.get("name","")) < str(b.get("name",""))
	)
	return result

func _cycle_hero_filter() -> void:
	var filters: Array[String] = ["전체","탱커","딜러","서포터","컨트롤러"]
	var index := filters.find(hero_roster_filter)
	hero_roster_filter = filters[(index + 1) % filters.size()]
	_build_hero_select_screen()

func _cycle_hero_sort() -> void:
	var modes: Array[String] = ["등급","레벨","전투력"]
	var index := modes.find(hero_roster_sort)
	hero_roster_sort = modes[(index + 1) % modes.size()]
	_build_hero_select_screen()

func _build_hero_select_screen() -> void:
	HeroScreens.roster(self)

func _create_hero_card(hero: Dictionary, accent: Color) -> PanelContainer:
	return HeroScreens.card(self, hero, accent)

func _make_hero_slot(slot_name: String, accent: Color) -> PanelContainer:
	var slot := PanelContainer.new()
	slot.custom_minimum_size = Vector2(0, 46)
	slot.add_theme_stylebox_override("panel", _panel_style(Color("#17233e"), Color("#31466f"), 8, 1))
	var label := _label("%s\n비어 있음" % slot_name, 12, MUTED)
	label.name = "HeroSlotLabel"
	label.custom_minimum_size = Vector2(0, 42)
	slot.add_child(label)
	hero_slot_labels.append(label)
	return slot

func _refresh_party_slots(accent: Color) -> void:
	var cap := _party_slot_cap()
	for index in hero_slot_labels.size():
		var label: Label = hero_slot_labels[index]
		if index < deployed_heroes.size():
			var hero: Dictionary = deployed_heroes[index]
			var progress: Dictionary = _get_hero_progress(str(hero["id"]))
			label.text = "%s · %s\nLv.%d · %s" % [_party_slot_name(index), hero["name"], progress["level"], hero["class"]]
			label.add_theme_color_override("font_color", UI.text_color(hero["color"]))
		elif index >= cap:
			label.text = "%s\n잠김 · 스테이지 %d" % [_party_slot_name(index), _party_slot_unlock_stage(index)]
			label.add_theme_color_override("font_color", Color("#687696"))
		else:
			label.text = "%s\n비어 있음" % _party_slot_name(index)
			label.add_theme_color_override("font_color", MUTED)
	for hero_id in hero_select_buttons.keys():
		var button: Button = hero_select_buttons[hero_id]
		if not is_instance_valid(button):
			continue
		var hero_data: Dictionary = {}
		for candidate in _hero_roster_for_faction():
			if str(candidate["id"]) == str(hero_id):
				hero_data = candidate
				break
		var selected := false
		for hero in deployed_heroes:
			if str(hero["id"]) == str(hero_id):
				selected = true
				break
		var hero_locked := not hero_data.is_empty() and idle_stage < int(hero_data.get("unlock_stage", 1))
		var cap_locked := not selected and deployed_heroes.size() >= cap
		button.disabled = hero_locked or cap_locked
		if hero_locked:
			button.text = "사냥 스테이지 %d 해금" % int(hero_data.get("unlock_stage", 1))
		elif selected:
			button.text = "배치 해제"
		elif cap_locked:
			button.text = "편성 슬롯 확장 필요"
		else:
			button.text = "이 영웅 배치"
		button.modulate = Color.WHITE
	if party_composition_label != null and is_instance_valid(party_composition_label):
		party_composition_label.text = "%s\n%s" % [_party_composition_summary(), _party_composition_hint()]

func _deploy_hero(hero: Dictionary) -> void:
	var hero_id := str(hero.get("id", ""))
	if not _hero_belongs_to_selected_faction(hero_id):
		if hero_hint != null:
			hero_hint.text = "선택한 진영의 영웅만 편성할 수 있습니다."
		return
	var unlock_stage := int(hero.get("unlock_stage", 1))
	if idle_stage < unlock_stage:
		if hero_hint != null:
			hero_hint.text = "%s은(는) 사냥 스테이지 %d부터 합류합니다." % [hero["name"], unlock_stage]
		return
	for index in deployed_heroes.size():
		if str(deployed_heroes[index]["id"]) == str(hero["id"]):
			deployed_heroes.remove_at(index)
			_refresh_party_slots(Color("#4c8fe8") if selected_faction == "aurelia" else Color("#c95770"))
			if hero_hint != null:
				hero_hint.text = "%s을(를) 원정대에서 제외했습니다. %d/%d명" % [hero["name"], deployed_heroes.size(), _party_slot_cap()]
			_save_idle_state()
			return
	var cap := _party_slot_cap()
	if deployed_heroes.size() >= cap:
		if hero_hint != null:
			hero_hint.text = "현재 편성 한도는 %d명입니다. %s" % [cap, _party_next_unlock_text()]
		return
	deployed_heroes.append(hero)
	_refresh_party_slots(Color("#4c8fe8") if selected_faction == "aurelia" else Color("#c95770"))
	if hero_hint != null:
		hero_hint.text = "%s을(를) %s에 배치했습니다. %d/%d명" % [hero["name"], _party_slot_name(deployed_heroes.size() - 1), deployed_heroes.size(), _party_slot_cap()]
	_save_idle_state()

func _swap_deployed_heroes(first: int, second: int) -> bool:
	if active_screen != "hero_select" or first < 0 or second < 0 or first >= deployed_heroes.size() or second >= deployed_heroes.size():
		return false
	if first == second:
		return false
	var selected: Dictionary = deployed_heroes[first]
	deployed_heroes[first] = deployed_heroes[second]
	deployed_heroes[second] = selected
	_save_idle_state()
	return true

func _confirm_party() -> void:
	set_meta("roster_swap_slot", -1)
	if deployed_heroes.is_empty():
		if is_instance_valid(hero_hint):
			hero_hint.text = "최소 한 명의 영웅을 배치해야 원정대를 출전시킬 수 있습니다."
		else:
			_show_toast("최소 한 명의 영웅을 편성해 주세요.")
		return
	_save_idle_state()
	var destination: Dictionary = content_party_context.duplicate(true) if active_screen == "hero_select" else {}
	content_party_context.clear()
	if _restore_content_party_destination(destination):
		return
	var names: Array[String] = []
	for hero in deployed_heroes:
		names.append(hero.name)
	_build_party_ready_screen(names)

func _restore_content_party_destination(destination: Dictionary) -> bool:
	match str(destination.get("kind", "")):
		"meta":
			_build_meta_hub_screen()
			return true
		"world":
			_build_world_map_screen()
			return true
		"raid":
			var zone_id := str(destination.get("zone_id", selected_raid_id if not selected_raid_id.is_empty() else current_zone_id))
			if _zone_data().has(zone_id) and _is_zone_unlocked(zone_id):
				_select_zone_for_raid(zone_id)
			else:
				_build_boss_select_screen()
			return true
		"party_ready":
			_build_party_ready_screen(_deployed_names())
			return true
	return false

func _back_from_content_party() -> void:
	set_meta("roster_swap_slot", -1)
	var destination := content_party_context.duplicate(true)
	content_party_context.clear()
	# Formation changes are already saved by the existing deploy/remove actions.
	# Back returns to the prior content; it is not an undo of those changes.
	if not _restore_content_party_destination(destination):
		_build_lobby_screen()

func _open_content_party(kind: String, zone_id: String = "") -> void:
	if kind not in ["meta", "raid", "world", "party_ready"]:
		return
	if raid_running:
		_show_toast("레이드가 끝난 뒤 편성을 변경할 수 있습니다.")
		return
	if selected_faction.is_empty():
		content_party_context.clear()
		_build_faction_screen()
		return
	var destination_zone := (selected_raid_id if not selected_raid_id.is_empty() else current_zone_id) if kind == "raid" and zone_id.is_empty() else (current_zone_id if zone_id.is_empty() else zone_id)
	if kind == "raid" and (not _zone_data().has(destination_zone) or not _is_zone_unlocked(destination_zone)):
		_show_toast("아직 해금되지 않은 지역입니다.")
		return
	content_party_context = {"kind": kind, "zone_id": destination_zone, "faction_id": selected_faction}
	_build_hero_select_screen()

func _validate_content_party_route(screen_instance: int) -> void:
	if not is_instance_valid(content_root) or content_root.get_instance_id() != screen_instance:
		return
	# Preserve the route while inspecting a hero, their gear or research, but do not let
	# an abandoned dungeon setup redirect a later, unrelated party confirmation.
	if active_screen not in ["hero_select", "hero_detail", "equipment_detail", "research_allocation"] or str(content_party_context.get("faction_id", selected_faction)) != selected_faction:
		content_party_context.clear()

func _build_party_ready_screen(names: Array[String]) -> void:
	OnboardingScreens.ready(self, names)

func _save_idle_state() -> void:
	if is_instance_valid(hunt_autosave): hunt_autosave.before_critical_save()
	_SAVE_FLOW.save_idle_state(self)

func _queue_hunt_save() -> void:
	if is_instance_valid(hunt_autosave): hunt_autosave.request()
	else: _save_idle_state()

func _load_idle_state() -> void:
	if is_instance_valid(hunt_autosave): hunt_autosave.before_critical_save()
	_SAVE_FLOW.load_idle_state(self)

func _calculate_offline_reward() -> void:
	_OFFLINE_REWARDS.calculate_offline_reward(self)

func _on_offline_hunt_reward(_gold: int, _xp: int, _chest_gold: int, _chest_xp: int) -> void:
	pass

func _zone_data() -> Dictionary:
	return preload("res://scripts/maps/ZoneCatalog.gd").all()

func _current_zone() -> Dictionary:
	return _zone_data().get(current_zone_id, _zone_data()["gray_meadow"])

func _is_zone_unlocked(zone_id: String) -> bool:
	var zones := _zone_data()
	if not zones.has(zone_id):
		return false
	return idle_stage >= int(zones[zone_id].get("unlock_stage", 1))

func _monster_texture(monster_name: String) -> Texture2D:
	return MonsterSpriteFactory.get_portrait_texture(monster_name)

func _update_monster_portrait(monster_name: String) -> void:
	if monster_sprite == null or not is_instance_valid(monster_sprite):
		return
	monster_sprite.visible = MonsterSpriteFactory.apply_monster(monster_sprite, monster_name, monster_sprite.presentation_scale)
	if not monster_sprite.visible:
		return
	monster_sprite.play_idle("down")

func _boss_texture(boss_name: String) -> Texture2D:
	return MonsterSpriteFactory.get_portrait_texture(boss_name)

func _update_boss_portrait(boss_name: String) -> void:
	if raid_boss_sprite == null or not is_instance_valid(raid_boss_sprite):
		return
	raid_boss_sprite.visible = MonsterSpriteFactory.apply_monster(raid_boss_sprite, boss_name, raid_boss_sprite.presentation_scale)
	if not raid_boss_sprite.visible:
		return
	raid_boss_sprite.play_idle("down")

func _spawn_open_map_boss() -> void:
	if active_screen != "combat" or not is_instance_valid(content_root) or open_map_boss_active:
		return
	var zone: Dictionary = _current_zone()
	open_map_boss_active = true
	open_map_boss_name = str(zone["boss"])
	open_map_boss_position = field_navigation.clamp_to_walkable(expedition_position + Vector2(3.0, -1.5))
	open_map_boss_sprite = MonsterSpriteFactory.create_monster(open_map_boss_name, Vector2(0.07, 0.07))
	open_map_boss_sprite.position = _map_world_position(open_map_boss_position, Vector2(0, -5))
	_field_actor_parent().add_child(open_map_boss_sprite)
	open_map_boss_sprite.play_idle("down")
	var alert: Label = combat_labels.get("boss_alert")
	if alert != null:
		alert.text = "☠ 보스 출현!  %s" % open_map_boss_name
		alert.add_theme_color_override("font_color", Color("#ffb84d"))
	var button: Button = combat_labels.get("boss_raid_button")
	if button != null:
		button.visible = true
		button.text = "보스 레이드 입장"
	var quick_button: Button = combat_labels.get("raid_button")
	if quick_button != null:
		quick_button.disabled = false
		quick_button.text = "지역 보스 레이드"
	var latest: Label = combat_labels.get("latest")
	if latest != null:
		latest.text = "최근 기록\n%s이(가) 사냥터에 나타났습니다!\n레이드 입장 버튼을 눌러 보스전에 도전하세요." % open_map_boss_name
	_emit_boss_spawn_fx(zone)
	_update_map_tiles()

func _emit_boss_spawn_fx(zone: Dictionary) -> void:
	_presentation_event("boss_warning")
	if not combat_effects_enabled:
		return
	if skill_fx_layer == null or not is_instance_valid(skill_fx_layer):
		return
	var boss_color := Color("#ffb84d")
	var flash := ColorRect.new()
	flash.color = Color("#160d1b", 0.78)
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	skill_fx_layer.add_child(flash)
	var warning := _label("⚠  WARNING  ⚠", 24, Color("#ff6b75"))
	warning.position = Vector2(430, 102)
	warning.size = Vector2(420, 42)
	warning.z_index = 4
	warning.modulate = Color(1, 1, 1, 0)
	skill_fx_layer.add_child(warning)
	var impact_center := Vector2(695, 335)
	combat_fx.boss_arrival(impact_center, boss_color)
	combat_fx.camera_impact(7.0, 0.24, 0.014)
	_emit_fx_ring(impact_center, 80.0, boss_color, 0.7)
	_emit_fx_ring(impact_center, 170.0, Color("#ff6b75"), 0.95)
	for ray_index in range(12):
		var ray := ColorRect.new()
		ray.color = Color(boss_color, 0.75)
		ray.size = Vector2(6, 130 if ray_index % 3 == 0 else 82)
		ray.position = impact_center - Vector2(3, ray.size.y)
		ray.pivot_offset = Vector2(3, ray.size.y)
		ray.rotation = TAU * float(ray_index) / 12.0
		ray.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ray.modulate = Color(1, 1, 1, 0)
		skill_fx_layer.add_child(ray)
		var ray_tween := content_root.create_tween().set_parallel(true)
		ray_tween.tween_property(ray, "modulate", Color.WHITE, 0.08)
		ray_tween.tween_property(ray, "scale", Vector2(1.0, 1.45), 0.22)
		ray_tween.chain().tween_property(ray, "modulate", Color(1, 1, 1, 0), 0.62)
		ray_tween.chain().tween_callback(ray.queue_free)
	var banner := _label("☠  지역 보스 출현  ☠\n%s" % str(zone["boss"]), 28, Color("#ffcf70"))
	banner.position = Vector2(380, 210)
	banner.size = Vector2(520, 110)
	banner.z_index = 5
	banner.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	banner.add_theme_constant_override("shadow_offset_x", 4)
	banner.add_theme_constant_override("shadow_offset_y", 4)
	banner.modulate = Color(1, 1, 1, 0)
	banner.scale = Vector2(1.35, 1.35)
	banner.pivot_offset = Vector2(260, 55)
	skill_fx_layer.add_child(banner)
	var tween := content_root.create_tween().set_parallel(true)
	tween.tween_property(flash, "color", Color("#160d1b", 0.0), 0.72)
	tween.tween_property(warning, "modulate", Color.WHITE, 0.12)
	tween.tween_property(banner, "modulate", Color.WHITE, 0.18)
	tween.tween_property(banner, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.chain().tween_property(warning, "modulate", Color(1, 1, 1, 0), 0.52)
	tween.parallel().tween_property(banner, "position", Vector2(380, 175), 0.72)
	tween.parallel().tween_property(banner, "modulate", Color(1, 1, 1, 0), 0.72)
	tween.chain().tween_callback(flash.queue_free)
	tween.tween_callback(warning.queue_free)
	tween.tween_callback(banner.queue_free)
	if open_map_boss_sprite != null and is_instance_valid(open_map_boss_sprite):
		open_map_boss_sprite.modulate = Color(1, 1, 1, 0)
		open_map_boss_sprite.spawn_scale = 0.25
		var boss_tween := content_root.create_tween().set_parallel(true)
		boss_tween.tween_property(open_map_boss_sprite, "modulate", Color.WHITE, 0.18)
		boss_tween.tween_property(open_map_boss_sprite, "spawn_scale", 1.18, 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		boss_tween.chain().tween_property(open_map_boss_sprite, "spawn_scale", 1.0, 0.25)

func _enter_open_map_boss_raid() -> void:
	if active_screen != "combat" or not open_map_boss_active or deployed_heroes.is_empty():
		return
	combat_running = false
	_build_raid_screen()

func _add_combat_chip(parent: Control, position: Vector2, title_text: String, value_text: String, accent: Color, key: String, width: float = 282.0) -> void:
	var panel := PanelContainer.new()
	panel.name = "CombatChip_%s" % key
	panel.position = position
	panel.size = Vector2(width, 46)
	panel.z_index = 38
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _panel_style(Color("#111a2be8"), Color(accent,0.82), 10, 1))
	parent.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",6)
	panel.add_child(row)
	var title := _label(title_text, 11, Color(accent,0.95))
	title.custom_minimum_size = Vector2(54,40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.add_child(title)
	var value := _label(value_text, 12, TEXT)
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(value)
	combat_labels[key] = value

func _build_combat_field_hud(accent: Color) -> void:
	var y := combat_field_rect.position.y + 10.0
	var x := combat_field_rect.position.x + 12.0
	_add_combat_chip(content_root, Vector2(x, y), "상태", "자동사냥 준비", accent, "field_state_chip", 170.0)
	x += 178.0
	_add_combat_chip(content_root, Vector2(x, y), "원정대", "%d/%d명 · HP 100%%" % [deployed_heroes.size(), deployed_heroes.size()], GREEN, "field_party_chip", 190.0)
	x += 198.0
	_add_combat_chip(content_root, Vector2(x, y), "현재 조우", "탐색 중", RED, "field_enemy_chip", 250.0)
	x += 258.0
	_add_combat_chip(content_root, Vector2(x, y), "진행", "%d-1 · %d/%d" % [idle_stage, idle_stage_kills, idle_stage_target], GOLD, "field_stage_chip", 190.0)

func _build_combat_tactical_strip() -> void:
	var tray := PanelContainer.new()
	tray.name = "CombatTacticalStrip"
	tray.position = Vector2(combat_field_rect.position.x, 544)
	tray.size = Vector2(combat_field_rect.size.x, 88)
	tray.add_theme_stylebox_override("panel", _panel_style(PANEL, Color("#bdcbbb"), 12, 1))
	content_root.add_child(tray)
	combat_labels["tactical_strip"] = tray
	var heading := _label("원정대\n%d / 10" % deployed_heroes.size(), 16, TEXT)
	heading.position = tray.position + Vector2(8, 8)
	heading.size = Vector2(98, 68)
	content_root.add_child(heading)
	var row := HBoxContainer.new()
	row.position = tray.position + Vector2(112, 8)
	row.size = Vector2(combat_field_rect.size.x - 260, 70)
	row.add_theme_constant_override("separation", 7)
	content_root.add_child(row)
	for index in PARTY_CAP:
		var slot := Button.new()
		slot.name = "PartyPortrait%d" % index
		slot.custom_minimum_size = Vector2(64, 70)
		slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot.add_theme_stylebox_override("normal", _panel_style(PANEL_SOFT, Color("#9cbda8"), 9, 1))
		slot.add_theme_stylebox_override("hover", _panel_style(PANEL_SOFT.lightened(0.08), GREEN, 9, 2))
		row.add_child(slot)
		if index >= deployed_heroes.size():
			slot.text = "+" if index < _party_slot_cap() else "잠김"
			slot.add_theme_font_size_override("font_size", 17)
			slot.add_theme_color_override("font_color", MUTED)
			slot.pressed.connect(_open_hero_menu)
			continue
		var hero: Dictionary = deployed_heroes[index]
		var hero_id := str(hero["id"])
		slot.tooltip_text = str(hero["name"])
		slot.pressed.connect(_build_hero_detail_screen.bind(hero_id))
		var portrait := TextureRect.new()
		portrait.name = "Portrait"
		portrait.texture = _combat_portrait_texture(hero_id)
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		portrait.offset_left = 4
		portrait.offset_right = -4
		portrait.offset_top = 2
		portrait.offset_bottom = -15
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(portrait)
		if portrait.texture == null:
			slot.text = str(hero["name"]).left(2)
			slot.add_theme_color_override("font_color", TEXT)
		for kind in ["hp", "ultimate"]:
			var bar := ProgressBar.new()
			bar.name = kind
			bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
			bar.offset_left = 5
			bar.offset_right = -5
			bar.offset_top = -13 if kind == "hp" else -6
			bar.offset_bottom = -8 if kind == "hp" else -2
			bar.show_percentage = false
			bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
			bar.add_theme_stylebox_override("background", _panel_style(Color("#c4d1c9"), Color.TRANSPARENT, 3))
			bar.add_theme_stylebox_override("fill", _panel_style(GREEN if kind == "hp" else BLUE, Color.TRANSPARENT, 3))
			slot.add_child(bar)
			combat_labels["portrait_%s_%s" % [kind, hero_id]] = bar
		var status := _label("", 15)
		status.visible = false
		slot.add_child(status)
		combat_labels["hero_tactical_%s" % hero_id] = status
	var claim := _button("보상 받기", Vector2(124, 62), Color("#e8d7a3"))
	claim.position = tray.position + Vector2(combat_field_rect.size.x - 136, 13)
	claim.pressed.connect(_claim_rewards)
	content_root.add_child(claim)
	combat_labels["claim"] = claim
	_update_combat_tactical_strip()

func _combat_portrait_texture(hero_id: String) -> Texture2D:
	return HeroSpriteFactory.portrait_texture(hero_id)

func _update_combat_tactical_strip() -> void:
	for hero in deployed_heroes:
		var hero_id := str(hero["id"])
		var state: Dictionary = hero_battle_state.get(hero_id, {})
		var hp := float(state.get("hp", 0))
		var max_hp := maxf(1.0, float(state.get("max_hp", 1)))
		var gauge := float(state.get("ultimate", 0.0))
		var hp_bar: ProgressBar = combat_labels.get("portrait_hp_%s" % hero_id)
		var ult_bar: ProgressBar = combat_labels.get("portrait_ultimate_%s" % hero_id)
		if is_instance_valid(hp_bar):
			hp_bar.value = 100.0 * hp / max_hp
		if is_instance_valid(ult_bar):
			ult_bar.value = gauge
		var label: Label = combat_labels.get("hero_tactical_%s" % hero_id)
		if is_instance_valid(label):
			label.text = "HP %d%% · %s" % [roundi(hp / max_hp * 100), "궁극기 준비" if gauge >= 100 else "궁극기 %d" % roundi(gauge)]

func _create_combat_target_marker() -> void:
	var marker := Label.new()
	marker.name = "CombatTargetMarker"
	marker.text = "▼"
	marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	marker.add_theme_font_size_override("font_size", 14)
	marker.add_theme_color_override("font_color", GOLD)
	marker.add_theme_color_override("font_shadow_color", Color("#000000"))
	marker.add_theme_constant_override("shadow_offset_x", 1)
	marker.add_theme_constant_override("shadow_offset_y", 1)
	marker.size = Vector2(78, 20)
	marker.visible = false
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marker.z_index = 30
	_field_actor_parent().add_child(marker)
	combat_labels["target_marker"] = marker

func _update_combat_target_marker() -> void:
	var marker: Label = combat_labels.get("target_marker")
	if not is_instance_valid(marker):
		return
	var target_index := roaming_hunt.current_target
	if not roaming_hunt.aggro_active or target_index < 0 or target_index >= enemy_wave_sprites.size():
		marker.visible = false
		return
	var sprite: MonsterSpriteController = enemy_wave_sprites[target_index]
	if not is_instance_valid(sprite):
		marker.visible = false
		return
	marker.visible = sprite.visible and int(enemy_wave[target_index].get("hp", 0)) > 0
	marker.position = sprite.position + _sprite_head_offset(sprite) + Vector2(-39, -29)
	var enemy: Dictionary = enemy_wave[target_index] if target_index < enemy_wave.size() else {}
	var role := str(enemy.get("archetype", ""))
	marker.text = "▼"

func _update_combat_danger_banner() -> void:
	var banner: Label = combat_labels.get("danger_banner")
	if not is_instance_valid(banner):
		return
	var warning := ""
	for enemy in enemy_wave:
		if int(enemy.get("hp", 0)) <= 0:
			continue
		if bool(enemy.get("rage_triggered", false)):
			warning = "⚠ 정예 광폭화 · 공격 속도와 피해량 상승"
			break
		if bool(enemy.get("elite", false)):
			warning = "⚠ 정예 몬스터 조우 · 체력 40% 이하에서 광폭화"
	if warning.is_empty():
		banner.visible = false
	else:
		banner.visible = true
		banner.text = warning

func _build_combat_screen() -> void:
	_clear_screen()
	active_screen = "combat"
	combat_running = not deployed_heroes.is_empty()
	raid_running = false
	combat_kills = 0
	combat_hunt_cycle = 0
	combat_progress = 0.0
	combat_tick_count = 0
	combat_engage_settle_remaining = 0.0
	open_map_boss_active = false
	open_map_boss_position = Vector2.ZERO
	open_map_boss_name = ""
	_calculate_offline_reward()
	combat_labels.clear()
	map_tile_labels.clear()
	var zone: Dictionary = _current_zone()
	var accent: Color = zone["color"]
	expedition_position = RoamingHuntDirector.FIELD_CENTER
	hunt_ai.configure(zone["positions"], expedition_position)
	roaming_hunt_seed = idle_stage * 7919 + int(zone.get("difficulty", 1)) * 131 + (17 if selected_faction == "aurelia" else 29)
	roaming_hunt.invasion_enabled = true
	party_movement.independent_hunt = true
	party_movement.holding_formation = false
	roaming_hunt.configure(expedition_position, roaming_hunt_seed, current_zone_id)
	roaming_wave_spawn_cooldown = 0.0
	roaming_last_party_velocity = Vector2.ZERO
	expedition_target = expedition_position
	_rewarded_encounter = -1
	_hud_elapsed = 0.0
	_save_elapsed = 0.0
	party_power = _calculate_party_power()
	_setup_hero_skills()
	enemy_name = zone["monsters"][0]
	enemy_max_hp = int(zone["power"]) * 3
	enemy_hp = enemy_max_hp
	enemy_attack = int(zone["power"]) / 8

	var layout: Dictionary = _combat_layout_for_width(_layout_width(), _safe_margins())
	combat_field_rect = layout["field"]
	combat_side_rect = layout["side"]
	var top := HBoxContainer.new()
	top.name = "CombatTopBar"
	top.position = Vector2(combat_field_rect.position.x, combat_field_rect.position.y - 58)
	top.size = Vector2(combat_field_rect.size.x, 48)
	top.add_theme_constant_override("separation", 14)
	content_root.add_child(top)
	var back := _button("원정대", Vector2(112, 46))
	back.pressed.connect(_build_party_ready_screen.bind(_deployed_names()))
	top.add_child(back)
	var title := _label("%s  ·  %d 스테이지" % [zone["name"], idle_stage], 20, TEXT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	combat_labels["header_stage"] = title
	var stage := _label("무리 격파  %d / %d" % [idle_stage_kills, idle_stage_target], 16, GREEN)
	stage.custom_minimum_size = Vector2(185, 44)
	top.add_child(stage)
	combat_labels["header_progress"] = stage
	var gold := _label("골드 %s" % _compact_hud_amount(wallet_gold), 17, GOLD)
	gold.custom_minimum_size = Vector2(145, 44)
	top.add_child(gold)
	combat_labels["gold"] = gold
	var gems := _label("보석 %s" % _compact_hud_amount(wallet_gems), 17, BLUE)
	gems.custom_minimum_size = Vector2(135, 44)
	top.add_child(gems)
	combat_labels["gems"] = gems
	var terrain := MapTerrainRenderer.new()
	terrain.name = "RoamingTerrain"
	terrain.position = combat_field_rect.position
	terrain.size = combat_field_rect.size
	terrain.configure(current_zone_id, accent)
	content_root.add_child(terrain)
	combat_labels["terrain"] = terrain
	_build_combat_field_hud(accent)
	_create_map_hero_sprites()
	_create_combat_target_marker()
	_build_combat_tactical_strip()
	_build_hunt_details(zone)
	var controls := HBoxContainer.new()
	controls.name = "HuntControls"
	controls.position = Vector2(combat_field_rect.end.x - 354, combat_field_rect.position.y + 12)
	controls.size = Vector2(342, 44)
	controls.add_theme_constant_override("separation", 8)
	controls.z_index = 40
	content_root.add_child(controls)
	var details := _button("사냥터", Vector2(108, 44))
	details.pressed.connect(_toggle_hunt_details)
	controls.add_child(details)
	combat_labels["details_button"] = details
	var toggle := _button("자동사냥 켬", Vector2(146, 44))
	toggle.pressed.connect(_toggle_combat.bind(toggle))
	controls.add_child(toggle)
	combat_labels["toggle"] = toggle
	var speed := _button("×%d" % int(battle_speed), Vector2(72, 44))
	speed.pressed.connect(_cycle_battle_speed.bind(speed))
	controls.add_child(speed)
	combat_labels["speed"] = speed
	var danger := _label("", 16, RED)
	danger.name = "CombatDangerBanner"
	danger.position = combat_field_rect.position + Vector2(12, 64)
	danger.size = Vector2(minf(620.0, combat_field_rect.size.x - 378.0), 35)
	danger.add_theme_stylebox_override("normal", _panel_style(PANEL, RED, 8, 1))
	danger.visible = false
	danger.z_index = 35
	content_root.add_child(danger)
	combat_labels["danger_banner"] = danger
	_add_bottom_nav("world")
	if challenge_session != null:
		_ensure_roaming_wave()
	else:
		_spawn_enemy_wave(zone)
	_update_map_tiles()
	_update_reward_labels()
	_update_stage_label()
	_update_hunt_hud()
	_maybe_show_offline_reward_popup()

func _build_hunt_details(zone: Dictionary) -> void:
	var panel := PanelContainer.new()
	panel.name = "HuntDetails"
	panel.position = combat_side_rect.position
	panel.size = combat_side_rect.size
	panel.z_index = 55
	panel.add_theme_stylebox_override("panel", _panel_style(PANEL, Color("#97b6a3"), 12, 2))
	content_root.add_child(panel)
	combat_labels["details_panel"] = panel
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	combat_labels["details_scroll"] = scroll
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 12)
	scroll.add_child(box)
	var close := _button("사냥터 정보 닫기", Vector2(0, 44))
	close.pressed.connect(_toggle_hunt_details)
	box.add_child(close)
	for key in ["zone_info", "enemy", "hunt_info", "stage", "pending", "latest", "growth", "skills", "boss_alert", "status", "map_title", "combat_state_chip", "combat_party_chip", "combat_enemy_chip", "combat_stage_chip", "xp", "auto_badge"]:
		var text_label := _label("", 16, TEXT)
		text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text_label.custom_minimum_size = Vector2(310, 24)
		box.add_child(text_label)
		combat_labels[key] = text_label
	combat_labels["zone_info"].text = _zone_info_text(zone)
	combat_labels["latest"].text = "원정대가 사냥터에 도착했습니다."
	combat_labels["boss_alert"].text = "몬스터 무리 5회 격파 시 보스 등장"
	var progress := ProgressBar.new()
	progress.custom_minimum_size = Vector2(0, 12)
	progress.show_percentage = false
	box.add_child(progress)
	combat_labels["progress"] = progress
	var zone_button := _button("다음 사냥터", Vector2(0, 44))
	zone_button.pressed.connect(_cycle_zone)
	box.add_child(zone_button)
	combat_labels["zone_button"] = zone_button
	var world := _button("사냥터 선택", Vector2(0, 44))
	world.pressed.connect(_build_world_map_screen)
	box.add_child(world)
	var raid := _button("보스 출현 대기", Vector2(0, 44))
	raid.disabled = true
	raid.pressed.connect(_enter_open_map_boss_raid)
	box.add_child(raid)
	combat_labels["raid_button"] = raid
	var boss := _button("보스 레이드 입장", Vector2(0, 44))
	boss.pressed.connect(_enter_open_map_boss_raid)
	boss.visible = false
	box.add_child(boss)
	combat_labels["boss_raid_button"] = boss
	panel.visible = false

func _toggle_hunt_details() -> void:
	var panel: Control = combat_labels.get("details_panel")
	if is_instance_valid(panel):
		panel.visible = not panel.visible

func _combat_map_scale() -> Vector2:
	return Vector2.ONE * clampf(combat_field_rect.size.y / 7.5, 54.0, 72.0)

func _combat_camera_anchor() -> Vector2:
	return combat_field_rect.position + combat_field_rect.size * Vector2(0.5, 0.52)

func _clamp_combat_camera(point: Vector2) -> Vector2:
	var scale := _combat_map_scale()
	var anchor := _combat_camera_anchor() - combat_field_rect.position
	var before := anchor / scale
	var after := (combat_field_rect.size - anchor) / scale
	var art_bounds: Rect2 = preload("res://scripts/maps/FieldArtCatalog.gd").world_art_rect(current_zone_id, RoamingHuntDirector.WORLD_SIZE)
	return point.clamp(art_bounds.position + before, art_bounds.end - after)

func _update_combat_camera(delta: float) -> void:
	var focus := party_movement.centroid(hero_battle_state, expedition_position)
	var offset := focus - combat_camera_position
	var desired := combat_camera_position + Vector2(signf(offset.x) * maxf(0.0, absf(offset.x) - 0.55), signf(offset.y) * maxf(0.0, absf(offset.y) - 0.35))
	combat_camera_position = _clamp_combat_camera(combat_camera_position.lerp(desired, 1.0 - exp(-3.5 * maxf(0.0, delta))))
	var terrain = combat_labels.get("terrain")
	if is_instance_valid(terrain):
		if terrain.has_method("configure_world_view"):
			terrain.configure_world_view(_combat_map_scale().x, _combat_camera_anchor() - combat_field_rect.position)
		if terrain.has_method("set_camera_position"):
			terrain.set_camera_position(combat_camera_position)

func _map_world_position(cell: Vector2, offset := Vector2.ZERO) -> Vector2:
	if active_screen == "combat" and combat_field_rect.size.x > 0.0:
		return _combat_camera_anchor() + (cell - combat_camera_position) * _combat_map_scale() + offset
	return Vector2(108.0 + cell.x * 94.0, 280.0 + cell.y * 44.0) + offset

func _hero_field_position(hero_id: String) -> Vector2:
	return party_movement.positions.get(hero_id, expedition_position)

func _field_actor_parent() -> Node2D:
	var existing = combat_labels.get("actor_layer")
	if is_instance_valid(existing):
		return existing
	var clip := Control.new()
	clip.name = "FieldActorClip"
	clip.position = combat_field_rect.position
	clip.size = combat_field_rect.size
	clip.clip_contents = true
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content_root.add_child(clip)
	var layer := Node2D.new()
	layer.name = "FieldActors"
	layer.position = -combat_field_rect.position
	layer.y_sort_enabled = true
	clip.add_child(layer)
	combat_labels["actor_clip"] = clip
	combat_labels["actor_layer"] = layer
	return layer

func _field_actor_depth(y: float) -> int:
	return 2 + clampi(int(16.0 * (y - combat_field_rect.position.y) / maxf(1.0, combat_field_rect.size.y)), 0, 16)

func _sprite_head_offset(sprite: Node2D) -> Vector2:
	return sprite.get_head_offset() if sprite.has_method("get_head_offset") else Vector2(0, -42)

func _sprite_foot_offset(sprite: Node2D) -> Vector2:
	return sprite.get_foot_offset() if sprite.has_method("get_foot_offset") else Vector2.ZERO

func _create_map_hero_sprites() -> void:
	hero_map_sprites.clear()
	hero_map_offsets.clear()
	field_navigation.configure_zone(current_zone_id)
	field_navigation.clear_routes()
	roaming_hunt.field_navigation = field_navigation
	party_movement.field_navigation = field_navigation
	roaming_hunt.party_position = field_navigation.clamp_to_walkable(expedition_position)
	expedition_position = roaming_hunt.party_position
	party_movement.configure(deployed_heroes, hero_battle_state, expedition_position)
	party_movement.apply_formation(deployed_heroes, formation_id)
	party_movement.place_formation(expedition_position)
	combat_camera_position = _clamp_combat_camera(expedition_position)
	_update_combat_camera(0.0)
	for index in range(deployed_heroes.size()):
		var hero: Dictionary = deployed_heroes[index]
		var hero_id := str(hero["id"])
		var actor_scale := _combat_actor_scale()
		var sprite := HeroSpriteFactory.create_hero(hero_id, Vector2(actor_scale, actor_scale))
		sprite.position = _map_world_position(_hero_field_position(hero_id))
		_field_actor_parent().add_child(sprite)
		sprite.play_idle("down")
		hero_map_sprites.append(sprite)
		hero_map_offsets.append(Vector2.ZERO)
		var hp_bar := ProgressBar.new()
		hp_bar.min_value = 0.0
		hp_bar.max_value = 100.0
		hp_bar.value = 100.0
		hp_bar.show_percentage = false
		hp_bar.size = Vector2(32, 4)
		hp_bar.position = sprite.position + _sprite_foot_offset(sprite) + Vector2(-16, 3)
		hp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hp_bar.z_index = 19
		hp_bar.add_theme_stylebox_override("background", _panel_style(Color("#34413d"), Color("#34413d"), 2, 0))
		hp_bar.add_theme_stylebox_override("fill", _panel_style(GREEN, GREEN, 2, 0))
		_field_actor_parent().add_child(hp_bar)
		hero_hp_bars[hero_id] = hp_bar

func _zone_info_text(zone: Dictionary) -> String:
	var unlock_stage := int(zone.get("unlock_stage", 1))
	var unlock_text := "해금 완료" if idle_stage >= unlock_stage else "사냥 스테이지 %d 해금" % unlock_stage
	return "몬스터  %s\n지역 보스  %s\n권장 전투력  %d\n난이도  %d / 3 · %s\n\n%s" % [" · ".join(zone["monsters"]), zone["boss"], zone["power"], zone["difficulty"], unlock_text, zone["description"]]

func _calculate_party_synergy() -> Dictionary:
	var power_multiplier := 1.0
	var hp_multiplier := 1.0
	var labels: Array[String] = []
	var count := deployed_heroes.size()
	if count >= 3:
		power_multiplier += 0.05
		labels.append("3인 결속 +5% 전투력")
	if count >= 6:
		power_multiplier += 0.07
		hp_multiplier += 0.05
		labels.append("6인 전술대 +7% 전투력/+5% HP")
	if count >= 10:
		power_multiplier += 0.08
		hp_multiplier += 0.10
		labels.append("10인 대원정대 +8% 전투력/+10% HP")
	var race_counts: Dictionary = {}
	var role_counts := {"탱커": 0, "딜러": 0, "서포터": 0, "컨트롤러": 0}
	for hero in deployed_heroes:
		var race := str(hero.get("race", ""))
		race_counts[race] = int(race_counts.get(race, 0)) + 1
		var role_group := str(_hero_skill_profile(str(hero["id"])).get("role_group", "딜러"))
		role_counts[role_group] = int(role_counts.get(role_group, 0)) + 1
	if selected_faction == "aurelia":
		if int(race_counts.get("휴먼", 0)) >= 3:
			hp_multiplier += 0.08
			labels.append("휴먼 방진 +8% HP")
		if int(race_counts.get("엘프", 0)) >= 3:
			power_multiplier += 0.07
			labels.append("엘프 별숲 +7% 전투력")
	elif selected_faction == "noxfera":
		if int(race_counts.get("뱀파이어", 0)) >= 3:
			power_multiplier += 0.07
			labels.append("혈월 결속 +7% 전투력")
		if int(race_counts.get("늑대인간", 0)) >= 3:
			hp_multiplier += 0.08
			labels.append("사냥 무리 +8% HP")
	var utility_count := int(role_counts.get("서포터", 0)) + int(role_counts.get("컨트롤러", 0))
	if int(role_counts.get("탱커", 0)) >= 2 and int(role_counts.get("딜러", 0)) >= 3 and utility_count >= 2:
		power_multiplier += 0.08
		hp_multiplier += 0.05
		labels.append("균형 진형 +8% 전투력/+5% HP")
	return {
		"power_multiplier": power_multiplier,
		"hp_multiplier": hp_multiplier,
		"summary": " · ".join(labels) if not labels.is_empty() else "없음 (3인부터 결속 발동)"
	}

func _calculate_party_power() -> int:
	var power := 100 + (clampi(idle_stage, 1, 10000) - 1) * 10
	for hero in deployed_heroes:
		var hero_id := str(hero["id"])
		var breakthrough_bonus := _hero_breakthrough_rank(hero_id) * 55
		var set_profile := _equipment_set_profile(hero_id)
		var raw_power := 140 + (_effective_combat_level(hero_id) - 1) * 35 + _equipment_power(hero_id) + _skill_tree_spent(hero_id) * 22 + breakthrough_bonus
		var identity_power := hero_identity_catalog.balance_budget(hero_id)
		power += int(float(raw_power) * _hero_grade_multiplier(hero_id) * float(set_profile.get("attack_mult", 1.0)) * identity_power)
	var synergy := _calculate_party_synergy()
	return int(round(power * float(synergy["power_multiplier"]) * (1.0 + _guardian_bonus("attack")) * float(FORMATIONS.profile(formation_id).attack)))

func _hero_xp_to_next(level: int) -> int:
	return _HERO_PROGRESS.hero_xp_to_next(self, level)

const MAX_HERO_LEVEL := 100
const MAX_PET_LEVEL := 100
const MAX_EQUIPMENT_LEVEL := 10
const EQUIPMENT_SLOTS := ["weapon", "armor", "accessory"]

func _valid_growth_hero(hero_id: String) -> bool:
	return _HERO_PROGRESS.valid_growth_hero(self, hero_id)

func _refresh_growth_runtime() -> void:
	_HERO_PROGRESS.refresh_growth_runtime(self)

func _setup_hero_progress(roster: Array) -> void:
	_HERO_PROGRESS.setup_hero_progress(self, roster)

func _get_skill_tree(hero_id: String) -> Dictionary:
	return _HERO_PROGRESS.get_skill_tree(self, hero_id)

func _skill_tree_spent(hero_id: String) -> int:
	return _HERO_PROGRESS.skill_tree_spent(self, hero_id)

func _skill_tree_total_points(hero_id: String) -> int:
	return _HERO_PROGRESS.skill_tree_total_points(self, hero_id)

func _skill_tree_available_points(hero_id: String) -> int:
	return _HERO_PROGRESS.skill_tree_available_points(self, hero_id)

func _upgrade_skill_tree(hero_id: String, branch: String) -> void:
	_HERO_PROGRESS.upgrade_skill_tree(self, hero_id, branch)

func _skill_tree_branch_text(branch: String, rank: int) -> String:
	return _HERO_PROGRESS.skill_tree_branch_text(self, branch, rank)

func _build_growth_screen() -> void:
	GROWTH_UI.growth(self)

func _get_hero_equipment(hero_id: String) -> Dictionary:
	if not _valid_growth_hero(hero_id):
		return {"weapon": 1, "armor": 1, "accessory": 1}
	if not hero_equipment.has(hero_id) or not hero_equipment[hero_id] is Dictionary:
		hero_equipment[hero_id] = {"weapon": 1, "armor": 1, "accessory": 1}
	for slot in EQUIPMENT_SLOTS:
		hero_equipment[hero_id][slot] = clampi(int(hero_equipment[hero_id].get(slot, 1)), 1, MAX_EQUIPMENT_LEVEL)
	return hero_equipment[hero_id]

func _get_hero_equipment_rarity(hero_id: String) -> Dictionary:
	if not _valid_growth_hero(hero_id):
		return {"weapon": "일반", "armor": "일반", "accessory": "일반"}
	if not hero_equipment_rarity.has(hero_id) or not hero_equipment_rarity[hero_id] is Dictionary:
		hero_equipment_rarity[hero_id] = {"weapon": "일반", "armor": "일반", "accessory": "일반"}
	for slot in EQUIPMENT_SLOTS:
		if str(hero_equipment_rarity[hero_id].get(slot, "")) not in ["일반", "희귀", "전설"]:
			hero_equipment_rarity[hero_id][slot] = "일반"
	return hero_equipment_rarity[hero_id]

func _get_hero_equipment_names(hero_id: String) -> Dictionary:
	if not _valid_growth_hero(hero_id):
		return {"weapon": "초보자의 검", "armor": "초보자의 가죽갑옷", "accessory": "빛바랜 부적"}
	if not hero_equipment_names.has(hero_id) or not hero_equipment_names[hero_id] is Dictionary:
		hero_equipment_names[hero_id] = {"weapon": "초보자의 검", "armor": "초보자의 가죽갑옷", "accessory": "빛바랜 부적"}
	for slot in EQUIPMENT_SLOTS:
		if not hero_equipment_names[hero_id].has(slot):
			hero_equipment_names[hero_id][slot] = "초보자의 " + _equipment_slot_name(slot)
	return hero_equipment_names[hero_id]

func _get_hero_equipment_sets(hero_id: String) -> Dictionary:
	if not _valid_growth_hero(hero_id):
		return {"weapon": "초보자", "armor": "초보자", "accessory": "초보자"}
	if not hero_equipment_sets.has(hero_id) or typeof(hero_equipment_sets[hero_id]) != TYPE_DICTIONARY:
		hero_equipment_sets[hero_id] = {"weapon": "초보자", "armor": "초보자", "accessory": "초보자"}
	var sets: Dictionary = hero_equipment_sets[hero_id]
	for slot in ["weapon", "armor", "accessory"]:
		if not sets.has(slot):
			sets[slot] = "초보자"
	hero_equipment_sets[hero_id] = sets
	return sets

func _equipment_set_profile(hero_id: String, replacement_sets: Dictionary = {}) -> Dictionary:
	var sets := _get_hero_equipment_sets(hero_id) if replacement_sets.is_empty() else replacement_sets
	var profile: Dictionary = GEAR.set_profile(sets)
	var equipped: Array = []
	for slot in EQUIPMENT_SLOTS:
		equipped.append(_gear_item("", hero_id, slot))
	var options: Dictionary = GEAR.affix_profile(equipped)
	profile["attack_mult"] = float(profile.get("attack_mult", 1.0)) * (1.0 + float(options.get("attack_pct", 0)) / 100.0)
	profile["hp_mult"] = float(profile.get("hp_mult", 1.0)) * (1.0 + float(options.get("hp_pct", 0)) / 100.0)
	profile["defense_bonus"] = int(profile.get("defense_bonus", 0)) + int(options.get("defense", 0))
	profile["haste_pct"] = minf(18.0, float(profile.get("haste_pct", 0)) + float(options.get("haste_pct", 0)))
	profile["ultimate_pct"] = minf(26.0, float(profile.get("ultimate_pct", 0)) + float(options.get("ultimate_pct", 0)))
	return profile

func _rarity_multiplier(rarity: String) -> float:
	return {"일반": 1.0, "희귀": 1.45, "전설": 2.2}.get(rarity, 1.0)

func _rarity_color(rarity: String) -> Color:
	return {"일반": Color("#b8c0d1"), "희귀": Color("#58a6ff"), "전설": Color("#ffb84d")}.get(rarity, TEXT)

func _rarity_rank(rarity: String) -> int:
	return {"일반": 1, "희귀": 2, "전설": 3}.get(rarity, 1)

func _equipment_power(hero_id: String) -> int:
	var equipment: Dictionary = _get_hero_equipment(hero_id)
	var rarities: Dictionary = _get_hero_equipment_rarity(hero_id)
	return int((int(equipment["weapon"]) * 22 * _rarity_multiplier(str(rarities["weapon"]))) + (int(equipment["armor"]) * 16 * _rarity_multiplier(str(rarities["armor"]))) + (int(equipment["accessory"]) * 12 * _rarity_multiplier(str(rarities["accessory"]))))

func _item_power(item: Dictionary) -> int:
	if str(item.get("item_type", "equipment")) != "equipment":
		return 0
	var slot := str(item.get("slot", "weapon"))
	if slot not in EQUIPMENT_SLOTS:
		return 0
	var base: int = int({"weapon": 22, "armor": 16, "accessory": 12}.get(slot, 22))
	return int(clampi(int(item.get("level", 1)), 1, MAX_EQUIPMENT_LEVEL) * base * _rarity_multiplier(str(item.get("rarity", "일반"))))

func _equipment_upgrade_cost(slot: String, level: int) -> int:
	if slot not in EQUIPMENT_SLOTS:
		return 0
	return preload("res://scripts/progression/GrowthEconomyRules.gd").equipment_cost(slot,level)

func _equipment_summary(hero_id: String) -> String:
	var equipment: Dictionary = _get_hero_equipment(hero_id)
	var rarities: Dictionary = _get_hero_equipment_rarity(hero_id)
	var sets := _get_hero_equipment_sets(hero_id)
	var set_bonus := _equipment_set_profile(hero_id)
	return "무기 %s +%d [%s] · 방어구 %s +%d [%s] · 장신구 %s +%d [%s]\n전투력 +%d · %s" % [rarities["weapon"], equipment["weapon"], sets["weapon"], rarities["armor"], equipment["armor"], sets["armor"], rarities["accessory"], equipment["accessory"], sets["accessory"], _equipment_power(hero_id), set_bonus["summary"]]

func _enhance_equipment(hero: Dictionary, slot: String) -> void:
	var hero_id := str(hero.get("id", ""))
	if not _valid_growth_hero(hero_id) or slot not in EQUIPMENT_SLOTS:
		return
	var item := _gear_item("", hero_id, slot)
	var result := _gear_enhance_item(str(item.get("id", "")), hero_id, slot)
	if hero_hint != null:
		hero_hint.text = str(result.get("reason", ""))

func _equipment_slot_name(slot: String) -> String:
	return {"weapon": "무기", "armor": "방어구", "accessory": "장신구"}.get(slot, slot)

func _inventory_item_score(item: Dictionary) -> int:
	var normalized := _normalize_inventory_item(item)
	if normalized.is_empty():
		return -1
	# Upgraded common gear must not be discarded for a weaker rare +1.
	return _item_power(normalized) * 10 + _rarity_rank(str(normalized["rarity"]))

func _inventory_salvage_value(item: Dictionary) -> int:
	var normalized := _normalize_inventory_item(item)
	if normalized.is_empty():
		return 0
	return 25 + int(normalized["level"]) * 20 + _rarity_rank(str(normalized["rarity"])) * 35

func _store_or_salvage_loot(item: Dictionary) -> String:
	var normalized := _normalize_inventory_item(item)
	if normalized.is_empty():
		return "유효하지 않은 장비"
	var protected: bool = GEAR.protected(normalized)
	var threshold := _rarity_rank(auto_salvage_min_rarity)
	if not protected and threshold > 0 and _rarity_rank(str(normalized["rarity"])) < threshold:
		var auto_value := _inventory_salvage_value(normalized)
		wallet_gold += auto_value
		return "자동 분해 설정 · +%dG" % auto_value
	if loot_inventory.size() < INVENTORY_CAP:
		loot_inventory.append(normalized)
		return "인벤토리에 보관"
	if preload("res://scripts/equipment/EquipmentMailService.gd").deliver(self, normalized):
		return "우편함으로 배송"
	return "우편함이 가득 찼습니다. 장비 지급을 보류합니다."

func _roll_equipment_drop(zone: Dictionary) -> Dictionary:
	if not SAVE_SAFETY.mutation_error(self).is_empty() or preload("res://scripts/equipment/EquipmentMailService.gd").available(self)<1:
		last_drop_text="우편함이 가득 찼습니다. 장비 지급 대기"
		return {}
	if deployed_heroes.is_empty():
		last_drop_text = "장비를 획득할 원정대가 없습니다."
		return {}
	var difficulty := clampi(int(zone.get("difficulty", 1)), 1, 3)
	var roll := loot_rng.randf()
	var rarity := ""
	if roll < 0.03 + difficulty * 0.01:
		rarity = "전설"
	elif roll < 0.15 + difficulty * 0.02:
		rarity = "희귀"
	elif roll < minf(0.97, (0.70 + difficulty * 0.04) * (1.0 + _guardian_bonus("item_drop"))):
		rarity = "일반"
	else:
		last_drop_text = "장비 드랍 없음"
		return {}
	var slots := ["weapon", "armor", "accessory"]
	var slot: String = slots[loot_rng.randi_range(0, slots.size() - 1)]
	var role: String = GEAR.HUNT_ROLES[loot_rng.randi_range(0, GEAR.HUNT_ROLES.size() - 1)]
	var item: Dictionary = GEAR.hunt_item(zone, slot, rarity, loot_rng, role)
	item = _normalize_inventory_item(item)
	var hero_id := _best_auto_equipment_target(item, deployed_heroes) if gear_auto_equip else ""
	if not hero_id.is_empty():
		# One temporary slot enables the same atomic swap used by manual equip;
		# the old item is then kept or salvaged by the ordinary inventory policy.
		loot_inventory.append(item)
		_equip_item_direct(loot_inventory.size() - 1, hero_id)
		var old_item: Dictionary = loot_inventory.pop_back()
		var stored := _store_or_salvage_loot(old_item)
		_update_equipment_card(hero_id)
		last_drop_text = "%s 획득! [%s] → %s 자동 장착 · 기존 장비 %s" % [item["name"], rarity, _hero_short_name(hero_id), stored]
	else:
		var result := _store_or_salvage_loot(item)
		last_drop_text = "%s 획득! [%s] · %s" % [item["name"], rarity, result]
	return item

func _update_equipment_card(hero_id: String) -> void:
	var candidate = equipment_labels.get(hero_id)
	if is_instance_valid(candidate) and candidate is Label:
		(candidate as Label).text = _equipment_summary(hero_id)

func _normalize_inventory_item(item: Dictionary) -> Dictionary:
	var normalized: Dictionary = GEAR.normalize(item)
	if not normalized.is_empty():
		normalized["power"] = _item_power(normalized)
	return normalized

func _inventory_action_valid(index: int, expected_id: String = "") -> bool:
	if index < 0 or index >= loot_inventory.size() or not loot_inventory[index] is Dictionary:
		return false
	if not expected_id.is_empty() and str(loot_inventory[index].get("id", "")) != expected_id:
		return false
	return not _normalize_inventory_item(loot_inventory[index]).is_empty()

func _inventory_upgrade_cost(item: Dictionary) -> int:
	var normalized := _normalize_inventory_item(item)
	if normalized.is_empty() or str(normalized.get("item_type", "equipment")) != "equipment":
		return 0
	return _equipment_upgrade_cost(str(normalized["slot"]), int(normalized["level"]))

func _enhance_inventory_item(index: int, expected_id: String = "") -> void:
	if not _inventory_action_valid(index, expected_id):
		return
	var item: Dictionary = _normalize_inventory_item(loot_inventory[index])
	# Keep legacy index callers safe while the detail UI uses stable item IDs.
	loot_inventory[index] = item
	var result := _gear_enhance_item(str(item.get("id", "")))
	_show_toast(str(result.get("reason", "")))
	if not bool(result.get("ok", false)):
		return
	if active_screen not in ["combat", "raid"]:
		_build_inventory_screen()
	else:
		_update_reward_labels()

func _equip_inventory_item(index: int, hero_id: String, expected_id: String = "") -> void:
	if not _inventory_action_valid(index, expected_id) or not _valid_growth_hero(hero_id):
		return
	loot_inventory[index] = _normalize_inventory_item(loot_inventory[index])
	var result := _gear_equip_item(str(loot_inventory[index].get("id", "")), hero_id)
	if not bool(result.get("ok", false)):
		_show_toast(str(result.get("reason", "장착할 수 없습니다.")))
		return
	_show_toast(str(result.get("reason", "")))
	if active_screen not in ["combat", "raid"]:
		_build_inventory_screen()
	else:
		_update_reward_labels()

func _decompose_inventory_item(index: int, expected_id: String = "", confirmed := false) -> void:
	if not _inventory_action_valid(index, expected_id):
		return
	loot_inventory[index] = _normalize_inventory_item(loot_inventory[index])
	var result := _gear_decompose_item(str(loot_inventory[index].get("id", "")), confirmed)
	_show_toast(str(result.get("reason", "")))
	if not bool(result.get("ok", false)):
		return
	if active_screen not in ["combat", "raid"]:
		_build_inventory_screen()
	else:
		_update_reward_labels()

func _build_inventory_screen() -> void:
	GROWTH_UI.inventory(self)

func _get_hero_progress(hero_id: String) -> Dictionary:
	return _HERO_PROGRESS.get_hero_progress(self, hero_id)

func _grant_hero_xp(amount: int) -> void:
	_HERO_PROGRESS.grant_hero_xp(self, amount)

func _hero_skill_profile(hero_id: String) -> Dictionary:
	return preload("res://scripts/heroes/HeroCombatRules.gd").skill_profile(hero_id)

func _formation_row_for_slot(slot: int) -> String:
	if slot < 3:
		return "front"
	if slot < 7:
		return "middle"
	return "rear"

func _hero_attack_range(hero_id: String, role_group: String, row: String) -> int:
	if str(HERO_ROSTER.HEROES.get(hero_id, {}).get("reach", "ranged")) == "melee":
		return 1 if row == "front" else 2
	if role_group in ["서포터", "컨트롤러"]:
		return 3
	return 3 if row == "rear" else 2

func _guardian_ensure_starter() -> void:
	_GUARDIAN_PROGRESS.guardian_ensure_starter(self)

func _pet_profile() -> Dictionary:
	return _GUARDIAN_PROGRESS.pet_profile(self)

func _guardian_bonus(key: String) -> float:
	return _GUARDIAN_PROGRESS.guardian_bonus(self, key)

func _guardian_reward(value: int, key: String) -> int:
	return _GUARDIAN_PROGRESS.guardian_reward(self, value, key)

func _guardian_equip(id: String) -> bool:
	return _GUARDIAN_PROGRESS.guardian_equip(self, id)

func _summon_guardian() -> Dictionary:
	return _SUMMONS.summon_guardian(self)

func _pet_progress_key() -> String:
	return _GUARDIAN_PROGRESS.pet_progress_key(self)

func _get_pet_progress() -> Dictionary:
	return _GUARDIAN_PROGRESS.get_pet_progress(self)

func _pet_xp_to_next(level: int) -> int:
	return _GUARDIAN_PROGRESS.pet_xp_to_next(self, level)

func _pet_evolution_for_level(level: int) -> int:
	return _GUARDIAN_PROGRESS.pet_evolution_for_level(self, level)

func _pet_evolution_name(evolution: int) -> String:
	return _GUARDIAN_PROGRESS.pet_evolution_name(self, evolution)

func _grant_pet_xp(amount: int) -> String:
	return _GUARDIAN_PROGRESS.grant_pet_xp(self, amount)

func _setup_pet_runtime() -> void:
	_GUARDIAN_PROGRESS.setup_pet_runtime(self)

func _gain_ultimate(hero_id: String, amount: float) -> void:
	if not hero_battle_state.has(hero_id):
		return
	var state: Dictionary = hero_battle_state[hero_id]
	if int(state.get("hp", 0)) <= 0:
		return
	var tree := _get_skill_tree(hero_id)
	var adjusted := amount * (1.0 + float(tree.get("utility", 0)) * 0.05) * float(state.get("ult_gain_mult", 1.0))
	state["ultimate"] = clampf(float(state.get("ultimate", 0.0)) + adjusted, 0.0, 100.0)

func _ultimate_ready(hero_id: String) -> bool:
	return hero_battle_state.has(hero_id) and int(hero_battle_state[hero_id].get("hp", 0)) > 0 and float(hero_battle_state[hero_id].get("ultimate", 0.0)) >= 100.0

func _cast_combat_ultimate(hero_id: String, target_index: int) -> int:
	return HERO_KITS.cast(self, hero_id, "ultimate", target_index)

func _cast_raid_ultimate(hero_id: String) -> int:
	return HERO_KITS.cast(self, hero_id, "ultimate")

func _advance_combat_pet(delta: float) -> void:
	if pet_runtime.is_empty() or str(pet_runtime.get("kind", "none")) == "none" or _enemy_wave_alive_count() <= 0:
		return
	pet_runtime["remaining"] = maxf(0.0, float(pet_runtime.get("remaining", 0.0)) - delta)
	if float(pet_runtime["remaining"]) > 0.0:
		return
	pet_runtime["remaining"] = float(pet_runtime.get("interval", 1.8))
	var level := int(pet_runtime.get("level", 1))
	var target_index := _select_enemy_target(_alive_hero_ids()[0]) if not _alive_hero_ids().is_empty() else -1
	if target_index < 0:
		return
	var base := maxi(8, int(float(party_power) / maxf(1.0, float(deployed_heroes.size())) * (0.42 + level * 0.03 + float(pet_runtime.get("evolution", 0)) * 0.10)))
	var dealt := _damage_enemy(target_index, base, -1) # Separate guardian/pet damage from hero slot zero.
	if str(pet_runtime.get("kind", "")) == "support":
		var heal_id := _lowest_hp_hero_id()
		if not heal_id.is_empty():
			_heal_hero(heal_id, maxi(4, int(hero_battle_state[heal_id]["max_hp"] * 0.045)))
	else:
		var heal_id := _lowest_hp_hero_id()
		if not heal_id.is_empty():
			_heal_hero(heal_id, maxi(1, int(dealt * 0.12)))
	skill_event_text = "%s · 자동 지원" % str(pet_runtime.get("name", "수호신"))

func _advance_raid_pet(delta: float) -> int:
	if raid_boss_hp <= 0 or _alive_hero_ids().is_empty() or pet_runtime.is_empty() or str(pet_runtime.get("kind", "none")) == "none":
		return 0
	pet_runtime["remaining"] = maxf(0.0, float(pet_runtime.get("remaining", 0.0)) - delta)
	if float(pet_runtime["remaining"]) > 0.0:
		return 0
	pet_runtime["remaining"] = float(pet_runtime.get("interval", 1.8))
	var level := int(pet_runtime.get("level", 1))
	var damage := maxi(10, int(float(party_power) / maxf(1.0, float(deployed_heroes.size())) * (0.48 + level * 0.03 + float(pet_runtime.get("evolution", 0)) * 0.10)))
	var actual_damage := mini(raid_boss_hp, int(damage * (1.25 if _vulnerable_seconds > 0.0 else 1.0)))
	if str(pet_runtime.get("kind", "")) == "support":
		var heal_id := _lowest_hp_hero_id()
		if not heal_id.is_empty():
			HERO_KITS._credited_heal(self, heal_id, maxi(5, int(hero_battle_state[heal_id]["max_hp"] * 0.05)), "$support")
	else:
		var heal_id := _lowest_hp_hero_id()
		if not heal_id.is_empty():
			HERO_KITS._credited_heal(self, heal_id, int(actual_damage * 0.12), "$support")
	return damage

func _setup_hero_skills() -> void:
	hero_skill_runtime.clear()
	_setup_hero_progress(deployed_heroes)
	var synergy := _calculate_party_synergy()
	party_max_hp = int(round((1000 + deployed_heroes.size() * 240) * float(synergy["hp_multiplier"])))
	party_hp = party_max_hp
	_guard_seconds = 0.0
	_weaken_seconds = 0.0
	_vulnerable_seconds = 0.0
	_stun_seconds = 0.0
	_skill_spacing = 0.0
	for index in deployed_heroes.size():
		var hero: Dictionary = deployed_heroes[index]
		var hero_id := str(hero["id"])
		var profile: Dictionary = preload("res://scripts/heroes/HeroCombatRules.gd").adjusted_profile(hero_id, hero_identity_catalog.profile(hero_id), _get_skill_tree(hero_id))
		hero_skill_runtime[hero_id] = {
			"hero": hero, "profile": profile, "remaining": float(index) * 0.12,
			"secondary_remaining": 1.2 + float(index) * 0.12, "passive_remaining": 0.0, "cast_secondary": false,
			"kit_last_move_position": _hero_field_position(hero_id),
			"attack_remaining": 0.1 + index * 0.11, "windup": -1.0, "cast": false, "cast_ultimate": false, "target_index": -1
		}
	_setup_hero_battle_state()
	_setup_pet_runtime()

func _refresh_hero_growth_stats() -> void:
	if hero_battle_state.is_empty():
		return
	var previous := hero_battle_state.duplicate(true)
	_setup_hero_battle_state()
	for hero_id in hero_battle_state.keys():
		if not previous.has(hero_id):
			continue
		var fresh: Dictionary = hero_battle_state[hero_id]
		var old: Dictionary = previous[hero_id]
		var ratio := clampf(float(old.get("hp", 0)) / maxf(1.0, float(old.get("max_hp", 1))), 0.0, 1.0)
		var merged: Dictionary = old.duplicate(true)
		for key in ["max_hp", "attack", "defense", "role_group", "slot", "row", "range", "ai_style", "attack_interval_mult", "ult_gain_mult"]:
			merged[key] = fresh[key]
		merged["hp"] = maxi(1, int(round(float(fresh["max_hp"]) * ratio))) if int(old.get("hp", 0)) > 0 else 0
		merged["alive"] = int(merged["hp"]) > 0
		hero_battle_state[hero_id] = merged
		if hero_skill_runtime.has(hero_id):
			hero_skill_runtime[hero_id]["profile"] = preload("res://scripts/heroes/HeroCombatRules.gd").adjusted_profile(str(hero_id), hero_identity_catalog.profile(str(hero_id)), _get_skill_tree(str(hero_id)))
	if not pet_runtime.is_empty():
		var progress := _get_pet_progress()
		pet_runtime["level"] = int(progress.get("level", 1))
		pet_runtime["evolution"] = int(progress.get("evolution", 0))
	_sync_party_hp_from_heroes()

func _apply_enemy_status(enemy_index: int, kind: String, duration: float) -> bool:
	if enemy_index < 0 or enemy_index >= enemy_wave.size():
		return false
	var applied: bool = preload("res://scripts/combat/CombatStatusRules.gd").apply(enemy_wave[enemy_index], kind, duration)
	if applied and kind == "stun" and challenge_session != null:
		preload("res://scripts/combat/ChallengePatternRuntime.gd").interrupt(self, enemy_index)
	return applied

func _enemy_status_remaining(enemy_index: int, kind: String) -> float:
	if enemy_index < 0 or enemy_index >= enemy_wave.size():
		return 0.0
	return preload("res://scripts/combat/CombatStatusRules.gd").remaining(enemy_wave[enemy_index], kind)

func _hero_skill_enemy_targets(hero_id: String, target_index: int, profile: Dictionary) -> Array[int]:
	var targets: Array[int] = combat_decisions.rank_skill_targets(hero_battle_state.get(hero_id, {}), enemy_wave, profile, _combat_enemy_distances(hero_id), target_index)
	# Explicit casts retain their valid primary target. Automatic actions choose
	# that target by profile; additional area hits use the same useful-target ranking.
	if targets.has(target_index):
		targets.erase(target_index)
		targets.push_front(target_index)
	var limit := maxi(1, int(profile.get("max_targets", enemy_wave.size()))) if bool(profile.get("aoe", false)) else 1
	if targets.size() > limit:
		targets.resize(limit)
	return targets

func _perform_hero_healing(profile: Dictionary, visual_allies = null, source_id: String = "") -> int:
	var healed := 0
	for ally_id in preload("res://scripts/heroes/HeroCombatRules.gd").healing_targets(profile, hero_battle_state, _alive_hero_ids()):
		var actual := _heal_hero(ally_id, preload("res://scripts/heroes/HeroCombatRules.gd").heal_amount(profile, hero_battle_state[ally_id]))
		healed += actual
		RAID_REPORT.add(self, source_id, "healing_given", actual)
		if actual > 0 and visual_allies is Array: visual_allies.append({"hero_id":ally_id, "mode":"heal"})
	return healed

func _perform_hero_guard(hero_id: String, profile: Dictionary, visual_allies = null) -> void:
	var state: Dictionary = hero_battle_state[hero_id]
	var duration := float(profile.get("duration", 2.4))
	if str(profile.get("guard_scope", "self")) == "party":
		for ally_id in _alive_hero_ids():
			hero_battle_state[ally_id]["guard"] = maxf(float(hero_battle_state[ally_id].get("guard", 0.0)), duration)
			if visual_allies is Array: visual_allies.append({"hero_id":ally_id,"mode":"guard"})
	else:
		state["guard"] = maxf(float(state.get("guard", 0.0)), duration)
		if visual_allies is Array: visual_allies.append({"hero_id":hero_id,"mode":"guard"})
		state["taunt"] = maxf(float(state.get("taunt", 0.0)), duration + 0.8)
	if float(profile.get("self_heal", 0.0)) > 0.0:
		var actual := _heal_hero(hero_id, int(float(state["max_hp"]) * float(profile["self_heal"])))
		RAID_REPORT.add(self, hero_id, "healing_given", actual)
		if actual > 0 and visual_allies is Array: visual_allies.append({"hero_id":hero_id,"mode":"heal"})

func _hero_combat_stats(hero_id: String, slot: int = 0, party_hp_multiplier: float = 1.0) -> Dictionary:
	var role_group := str(_hero_skill_profile(hero_id).get("role_group", "딜러"))
	var level: int = _effective_combat_level(hero_id)
	var equipment := _equipment_power(hero_id)
	var base_hp := 360
	var defense := 6
	match role_group:
		"탱커":
			base_hp = 560
			defense = 18
		"서포터":
			base_hp = 405
			defense = 9
		"컨트롤러":
			base_hp = 390
			defense = 8
	var tree := _get_skill_tree(hero_id)
	var set_profile := _equipment_set_profile(hero_id)
	var grade_mult := _hero_grade_multiplier(hero_id)
	var identity := hero_identity_catalog.profile(hero_id)
	var max_hp := maxi(120, int((base_hp + level * 42 + equipment * 0.45) * party_hp_multiplier * (1.0 + float(tree.get("survival", 0)) * 0.05) * grade_mult * float(set_profile.get("hp_mult", 1.0)) * float(identity.get("hp_mult", 1.0))))
	max_hp = maxi(120, int(round(float(max_hp) * _goal_hp_multiplier(hero_id))))
	var attack := maxi(12, int((24 + level * 5 + int(equipment * 0.18)) * (1.0 + float(tree.get("offense", 0)) * 0.04) * grade_mult * float(set_profile.get("attack_mult", 1.0)) * float(identity.get("attack_mult", 1.0))))
	defense += int(tree.get("survival", 0)) + int(set_profile.get("defense_bonus", 0)) + int(identity.get("defense_bonus", 0))
	if role_group == "딜러":
		attack = int(attack * 1.18)
	elif role_group == "탱커":
		attack = int(attack * 0.84)
	attack = int(round(float(attack) * (1.0 + _guardian_bonus("attack"))))
	var row := _formation_row_for_slot(slot)
	var formation: Dictionary = FORMATIONS.profile(formation_id)
	max_hp = maxi(1, roundi(max_hp * float(formation.hp)))
	attack = maxi(1, roundi(attack * float(formation.attack)))
	return {
		"hp": max_hp, "max_hp": max_hp, "attack": attack, "defense": defense,
		"role_group": role_group, "slot": slot, "row": row,
		"range": _hero_attack_range(hero_id, role_group, row), "ultimate": 0.0,
		"ai_style": str(identity.get("ai_style", "balanced")),
		"attack_interval_mult": float(identity.get("attack_interval_mult", 1.0)) / (1.0 + float(set_profile.get("haste_pct", 0)) / 100.0) / float(formation.speed),
		"ult_gain_mult": float(identity.get("ult_gain_mult", 1.0)) * (1.0 + float(set_profile.get("ultimate_pct", 0)) / 100.0),
		"guard": 0.0, "taunt": 0.0, "alive": true
	}

func _setup_hero_battle_state() -> void:
	hero_battle_state.clear()
	var hp_multiplier := float(_calculate_party_synergy().get("hp_multiplier", 1.0))
	for index in deployed_heroes.size():
		var hero_id := str(deployed_heroes[index]["id"])
		hero_battle_state[hero_id] = _hero_combat_stats(hero_id, index, hp_multiplier)
	_sync_party_hp_from_heroes()

func _sync_party_hp_from_heroes() -> void:
	if hero_battle_state.is_empty():
		return
	party_hp = 0
	party_max_hp = 0
	for state in hero_battle_state.values():
		party_hp += maxi(0, int(state.get("hp", 0)))
		party_max_hp += maxi(1, int(state.get("max_hp", 1)))

func _alive_hero_ids() -> Array[String]:
	var result: Array[String] = []
	for hero in deployed_heroes:
		var hero_id := str(hero["id"])
		if hero_battle_state.has(hero_id) and int(hero_battle_state[hero_id].get("hp", 0)) > 0:
			result.append(hero_id)
	return result

func _lowest_hp_hero_id() -> String:
	var best_id := ""
	var best_ratio := 2.0
	for hero_id in _alive_hero_ids():
		var state: Dictionary = hero_battle_state[hero_id]
		var ratio := float(state["hp"]) / maxf(1.0, float(state["max_hp"]))
		if ratio < best_ratio:
			best_ratio = ratio
			best_id = hero_id
	return best_id

func _advance_skill_cooldowns(delta: float) -> void:
	if delta <= 0.0 or not is_finite(delta):
		return
	HERO_KITS.tick(self, delta)
	for runtime in hero_skill_runtime.values():
		runtime["remaining"] = maxf(0.0, float(runtime["remaining"]) - delta)
	for hero_id in hero_battle_state.keys():
		var state: Dictionary = hero_battle_state[hero_id]
		state["guard"] = maxf(0.0, float(state.get("guard", 0.0)) - delta)
		state["taunt"] = maxf(0.0, float(state.get("taunt", 0.0)) - delta)
	_guard_seconds = maxf(0.0, _guard_seconds - delta)
	_weaken_seconds = maxf(0.0, _weaken_seconds - delta)
	_vulnerable_seconds = maxf(0.0, _vulnerable_seconds - delta)
	_stun_seconds = maxf(0.0, _stun_seconds - delta)
	_skill_spacing = maxf(0.0, _skill_spacing - delta)
	if active_screen == "combat":
		for enemy in enemy_wave:
			for status_key in ["stun_seconds", "weaken_seconds", "vulnerable_seconds"]:
				enemy[status_key] = maxf(0.0, float(enemy.get(status_key, 0.0)) - delta)

func _combat_tactic_bundle(hero_id: String) -> Dictionary:
	var state: Dictionary = hero_battle_state.get(hero_id, {})
	var party_ctx := combat_tactics.party_context(hero_battle_state)
	var boss_ctx := combat_tactics.boss_context(
		active_screen == "raid",
		boss_telegraph_pending,
		boss_telegraph_remaining,
		raid_boss_hp,
		raid_boss_max_hp
	)
	var enemy_ctx := combat_tactics.enemy_context(enemy_wave)
	if active_screen == "raid":
		enemy_ctx = {
			"alive": 1 if raid_boss_hp > 0 else 0,
			"elites": 0,
			"supports": 0,
			"assassins": 0,
			"total_attack": raid_boss_attack,
			"lowest_hp": float(raid_boss_hp) / maxf(1.0, float(raid_boss_max_hp))
		}
	return {"state": state, "party": party_ctx, "enemy": enemy_ctx, "boss": boss_ctx}

func _should_use_skill(hero_id: String) -> bool:
	if not skill_auto:return false
	if not preload("res://scripts/heroes/HeroCombatRules.gd").SKILLS.has(hero_id):
		return HERO_KITS.should_use(self, hero_id, "a1")
	if not hero_skill_runtime.has(hero_id):
		return false
	var runtime: Dictionary = hero_skill_runtime[hero_id]
	if float(runtime["remaining"]) > 0.0:
		return false
	if not hero_battle_state.has(hero_id) or int(hero_battle_state[hero_id].get("hp", 0)) <= 0:
		return false
	var profile: Dictionary = runtime["profile"]
	var kind := str(profile.get("kind", "damage"))
	if active_screen == "raid" and raid_boss_hp <= 0:
		return false
	if kind == "guard":
		if active_screen == "combat" and _enemy_wave_alive_count() <= 0:
			return false
		if str(profile.get("guard_scope", "self")) == "party":
			var all_guarded := true
			for ally_id in _alive_hero_ids():
				if float(hero_battle_state[ally_id].get("guard", 0.0)) < 0.5:
					all_guarded = false
			if all_guarded:
				return false
		elif float(hero_battle_state[hero_id].get("guard", 0.0)) > 0.0:
			return false
	if kind in ["weaken", "vulnerable", "stun"]:
		if active_screen == "combat":
			var useful_target := false
			for enemy_index in enemy_wave.size():
				if _can_attack_enemy(hero_id, enemy_index) and _enemy_status_remaining(enemy_index, kind) <= 0.0:
					useful_target = true
					break
			if not useful_target:
				return false
		else:
			if kind == "weaken" and _weaken_seconds > 0.0:
				return false
			if kind == "vulnerable" and _vulnerable_seconds > 0.0:
				return false
			if kind == "stun" and _stun_seconds > 0.0:
				return false
	var bundle := _combat_tactic_bundle(hero_id)
	return combat_tactics.should_use_skill(profile, bundle["state"], bundle["party"], bundle["enemy"], bundle["boss"]) and HERO_KITS.should_use(self, hero_id, "a1")

func _should_use_ultimate(hero_id: String) -> bool:
	if not ultimate_auto:return false
	if not preload("res://scripts/heroes/HeroCombatRules.gd").SKILLS.has(hero_id):
		return HERO_KITS.should_use(self, hero_id, "ultimate")
	if not _ultimate_ready(hero_id) or not hero_battle_state.has(hero_id):
		return false
	if active_screen == "raid" and raid_boss_hp <= 0:
		return false
	var state: Dictionary = hero_battle_state[hero_id]
	var role_group := preload("res://scripts/heroes/HeroCombatRules.gd").ultimate_role(hero_id, str(state.get("role_group", "딜러")))
	# Preserve a second tank's ultimate while the entire living party is protected.
	if role_group == "탱커":
		var all_guarded := true
		for ally_id in _alive_hero_ids():
			if float(hero_battle_state[ally_id].get("guard", 0.0)) < 1.0:
				all_guarded = false
				break
		if all_guarded:
			return false
	var bundle := _combat_tactic_bundle(hero_id)
	var ultimate_profile: Dictionary = HERO_ROSTER.skill(hero_id, "ultimate")
	return HERO_KITS.should_use(self, hero_id, "ultimate") and combat_tactics.should_use_ultimate(
		role_group,
		state,
		bundle["party"],
		bundle["enemy"],
		bundle["boss"],
		ultimate_profile
	)

func _cast_hero_skill(hero_id: String) -> int:
	if not preload("res://scripts/heroes/HeroCombatRules.gd").SKILLS.has(hero_id):
		return HERO_KITS.cast(self, hero_id, "a1")
	if not _should_use_skill(hero_id):
		return 0
	var runtime: Dictionary = hero_skill_runtime[hero_id]
	var hero: Dictionary = runtime["hero"]
	var profile: Dictionary = runtime["profile"]
	var state: Dictionary = hero_battle_state[hero_id]
	var attack := maxi(1, int(state.get("attack", 20)))
	var dealt := 0
	var visual_allies: Array[Dictionary] = []
	var visual_targets: Array[int] = []
	var detail := str(profile["effect"])
	var kind := str(profile.get("kind", "damage"))
	var target := {"hp":raid_boss_hp if active_screen == "raid" else maxi(1, enemy_hp), "max_hp":raid_boss_max_hp if active_screen == "raid" else maxi(1, enemy_max_hp), "elite":active_screen == "raid"}
	match kind:
		"guard":
			_perform_hero_guard(hero_id, profile, visual_allies)
			if active_screen != "raid":
				_guard_seconds = maxf(_guard_seconds, float(profile.get("duration", 2.4)))
		"heal":
			var healed := _perform_hero_healing(profile, visual_allies, hero_id)
			if healed <= 0:
				return 0
			detail = "%s · HP +%d" % [detail, healed]
		"weaken":
			visual_targets.append(-1)
			_weaken_seconds = maxf(_weaken_seconds, float(profile.get("duration", 3.0)))
		"vulnerable":
			visual_targets.append(-1)
			_vulnerable_seconds = maxf(_vulnerable_seconds, float(profile.get("duration", 3.0)))
		_:
			visual_targets.append(-1)
			dealt = preload("res://scripts/heroes/HeroCombatRules.gd").hit_damage(profile, attack, target)
			if kind == "stun":
				if active_screen == "raid" and has_method("_raid_apply_control"):
					call("_raid_apply_control", float(profile.get("duration", 0.5)))
				else:
					_stun_seconds = maxf(_stun_seconds, float(profile.get("duration", 0.5)))
			if float(profile.get("self_guard", 0.0)) > 0.0:
				state["guard"] = maxf(float(state.get("guard", 0.0)), float(profile["self_guard"]))
				visual_allies.append({"hero_id":hero_id, "mode":"guard"})
			if kind == "lifesteal":
				var actual := mini(maxi(0, int(target["hp"])), int(float(dealt) * (1.25 if _vulnerable_seconds > 0.0 else 1.0)))
				var healed := _heal_hero(hero_id, preload("res://scripts/heroes/HeroCombatRules.gd").lifesteal_amount(profile, state, actual))
				if healed > 0: visual_allies.append({"hero_id":hero_id, "mode":"return"})
				detail = "%s · HP +%d" % [detail, healed]
	runtime["remaining"] = float(profile["cooldown"])
	_gain_ultimate(hero_id, 15.0 + float(profile.get("extra_ultimate", 0.0)))
	skill_event_text = "%s · %s · %s" % [hero["name"], profile["skill"], detail]
	var visual_profile := profile.duplicate(true)
	visual_profile["id"] = hero_id + "_a1"
	visual_profile["slot"] = "a1"
	visual_profile["fx_targets"] = visual_targets
	visual_profile["fx_target_hits"] = {-1:1}
	visual_profile["fx_allies"] = visual_allies
	_emit_skill_cast_fx(hero_id, -1, bool(profile.get("aoe",false)), visual_profile)
	_emit_skill_fx(hero, profile, dealt)
	runtime["casts_a1"] = int(runtime.get("casts_a1", 0)) + 1
	dealt += HERO_KITS.event(self, hero_id, "cast", -1)
	return dealt

func _enemy_wave_alive_count() -> int:
	var count := 0
	for enemy in enemy_wave:
		if int(enemy.get("hp", 0)) > 0:
			count += 1
	return count

func _sync_enemy_wave_summary() -> void:
	if enemy_wave.is_empty():
		enemy_hp = 0
		enemy_max_hp = 0
		enemy_attack = 0
		return
	enemy_hp = 0
	enemy_max_hp = 0
	enemy_attack = 0
	var first_alive := -1
	for index in enemy_wave.size():
		var enemy: Dictionary = enemy_wave[index]
		enemy_hp += maxi(0, int(enemy.get("hp", 0)))
		enemy_max_hp += maxi(1, int(enemy.get("max_hp", 1)))
		if int(enemy.get("hp", 0)) > 0:
			enemy_attack += int(enemy.get("attack", 0))
			if first_alive < 0:
				first_alive = index
	if first_alive >= 0:
		var lead: Dictionary = enemy_wave[first_alive]
		var alive_count := _enemy_wave_alive_count()
		var prefix := ""
		if bool(lead.get("treasure", false)) and not bool(lead.get("treasure_expired", false)):
			prefix = "보물 "
		elif bool(lead.get("elite", false)):
			var affix_label := HUNT_VARIETY.affix_label(str(lead.get("elite_affix", "")))
			prefix = "광폭 %s 정예 " % affix_label if bool(lead.get("rage_triggered", false)) else "%s 정예 " % affix_label
		var lead_name := prefix + str(lead.get("name", "몬스터"))
		enemy_name = lead_name + (" 외 %d" % (alive_count - 1) if alive_count > 1 else "")
		if first_alive < enemy_wave_sprites.size() and is_instance_valid(enemy_wave_sprites[first_alive]):
			monster_sprite = enemy_wave_sprites[first_alive]

func _combat_enemy_distances(hero_id: String = "") -> Array:
	var distances: Array = []
	if active_screen == "combat" and roaming_hunt.enemy_positions.size() == enemy_wave.size():
		var origin := _hero_field_position(hero_id) if not hero_id.is_empty() else expedition_position
		for index in enemy_wave.size():
			distances.append(INF if roaming_hunt.is_returning(index) else origin.distance_to(roaming_hunt.enemy_position(index)))
	return distances

func _can_attack_enemy(hero_id: String, target_index: int) -> bool:
	return combat_decisions.can_attack_enemy(hero_battle_state.get(hero_id, {}), enemy_wave, target_index, _combat_enemy_distances(hero_id))

func _select_enemy_target(hero_id: String) -> int:
	if active_screen == "combat" and challenge_session == null and party_movement.independent_hunt:
		var personal_target := int(party_movement.targets.get(hero_id, -1))
		if _can_attack_enemy(hero_id, personal_target): return preload("res://scripts/hunting/HuntDamageReservations.gd").choose(self,hero_id,personal_target)
	var runtime: Dictionary = hero_skill_runtime.get(hero_id, {})
	var selected: int = combat_decisions.select_enemy_target(
		hero_battle_state.get(hero_id, {}), enemy_wave, _combat_enemy_distances(hero_id), int(runtime.get("target_index", -1))
	)
	return preload("res://scripts/hunting/HuntDamageReservations.gd").choose(self,hero_id,selected)

func _select_hero_target_for_enemy(enemy_index: int, require_reachable := false) -> String:
	if enemy_index < 0 or enemy_index >= enemy_wave.size():
		return ""
	var enemy: Dictionary = enemy_wave[enemy_index]
	var candidates := _alive_hero_ids()
	if require_reachable and active_screen == "combat":
		var reachable: Array[String] = []
		for hero_id in candidates:
			if _hero_field_position(hero_id).distance_to(roaming_hunt.enemy_position(enemy_index)) <= _enemy_attack_range(enemy):
				reachable.append(hero_id)
		candidates = reachable
	var target_id := preload("res://scripts/hunting/HuntingTargetDirector.gd").select(self, enemy_index, candidates) if active_screen == "combat" and challenge_session == null and party_movement.independent_hunt else combat_decisions.select_hero_target(enemy, enemy_index, hero_battle_state, candidates, str(enemy.get("target_id", "")))
	enemy["target_id"] = target_id
	return target_id

func _enemy_attack_range(enemy: Dictionary) -> float:
	var archetype := str(enemy.get("archetype", ""))
	return 1.65 if archetype == "ranged" else (1.80 if archetype == "support" else (0.82 if archetype == "assassin" else 0.92))

func _combat_action_needs_enemy(hero_id: String, use_skill: bool, use_ultimate: bool, use_secondary := false) -> bool:
	if use_secondary:
		return HERO_KITS.needs_enemy(HERO_ROSTER.skill(hero_id, "a2"))
	if use_ultimate:
		return HERO_KITS.needs_enemy(HERO_ROSTER.skill(hero_id, "ultimate"))
	if use_skill:
		var runtime: Dictionary = hero_skill_runtime.get(hero_id, {})
		return str(runtime.get("profile", {}).get("kind", "damage")) not in ["heal", "guard", "taunt", "barrier"]
	return true

func _heal_enemy(enemy_index: int, amount: int) -> int:
	if enemy_index < 0 or enemy_index >= enemy_wave.size():
		return 0
	var enemy: Dictionary = enemy_wave[enemy_index]
	if int(enemy.get("hp", 0)) <= 0:
		return 0
	var healed := mini(int(enemy["max_hp"]) - int(enemy["hp"]), maxi(0, amount))
	enemy["hp"] = int(enemy["hp"]) + healed
	if enemy_index < enemy_hp_bars.size() and is_instance_valid(enemy_hp_bars[enemy_index]):
		enemy_hp_bars[enemy_index].value = 100.0 * float(enemy["hp"]) / maxf(1.0, float(enemy["max_hp"]))
	_sync_enemy_wave_summary()
	return healed

func _combat_hero_screen_position(hero_id: String) -> Vector2:
	if hero_battle_state.has(hero_id):
		var slot := int(hero_battle_state[hero_id].get("slot", -1))
		if slot >= 0 and slot < hero_map_sprites.size() and is_instance_valid(hero_map_sprites[slot]):
			return hero_map_sprites[slot].position
	return _map_world_position(expedition_position)

func _combat_enemy_screen_position(enemy_index: int) -> Vector2:
	if enemy_index >= 0 and enemy_index < enemy_wave_sprites.size() and is_instance_valid(enemy_wave_sprites[enemy_index]):
		return enemy_wave_sprites[enemy_index].position
	if active_screen == "raid" and is_instance_valid(raid_boss_sprite):
		return raid_boss_sprite.position
	return _map_world_position(expedition_position + Vector2(1.5, 0.0))

func _enemy_group_screen_center() -> Vector2:
	var total := Vector2.ZERO
	var count := 0
	for index in enemy_wave.size():
		if int(enemy_wave[index].get("hp", 0)) <= 0:
			continue
		total += _combat_enemy_screen_position(index)
		count += 1
	if count > 0:
		return total / float(count)
	return _map_world_position(expedition_position + Vector2(1.5, 0.0))

func _emit_basic_attack_fx(hero_id: String, target_index: int) -> void:
	if target_index >= 0:
		_presentation_event("sword" if int(hero_battle_state.get(hero_id, {}).get("range", 1)) <= 1 else "bow")
	if not combat_effects_enabled or target_index < 0:
		return
	var terrain: Control = combat_labels.get("terrain")
	# The live battlefield draws the release on the simulation windup, before damage.
	if active_screen == "combat" and challenge_session == null and is_instance_valid(terrain) and terrain.has_method("hunt_hit"): return
	var state: Dictionary = hero_battle_state.get(hero_id, {})
	var attack_range := int(state.get("range", 1))
	var start := _combat_hero_screen_position(hero_id) + Vector2(20, -12)
	var finish := _combat_enemy_screen_position(target_index) + Vector2(-10, -18)
	var color := _hero_accent_color(hero_id)
	if attack_range <= 1:
		combat_fx.hit_spark(finish, color, false, false)
		return
	combat_fx.projectile(start, finish, color, "•", 0.18, false)

func _notify_hunt_frame_release(index: int, hero: bool, action: String, windup: float) -> void:
	if active_screen != "combat" or challenge_session != null: return
	var terrain: Control = combat_labels.get("terrain")
	var sources: Array = hero_map_sprites if hero else enemy_wave_sprites
	if index >= 0 and index < sources.size() and is_instance_valid(terrain) and terrain.has_method("frame_release"):
		terrain.frame_release(sources[index], hero, action, windup)

func _hero_skill_fx_position(hero_id: String) -> Vector2:
	if active_screen == "raid":
		var view := content_root.get_node_or_null("PortraitRaidView") if is_instance_valid(content_root) else null
		if is_instance_valid(view) and view.hero_actors.has(hero_id):
			return view.hero_actors[hero_id].position + Vector2(0, -42)
		var label = combat_labels.get("raid_hero_%s" % hero_id)
		if is_instance_valid(label):
			# Raid heroes live in party cards; anchor the effect to their portrait.
			return content_root.get_global_transform().affine_inverse() * (label.get_global_transform() * Vector2(-17, 28))
	return _combat_hero_screen_position(hero_id) + Vector2(0, -18)

func _hero_skill_fx_bounds() -> Rect2:
	if active_screen == "combat":
		return combat_field_rect
	if active_screen == "raid" and is_instance_valid(content_root) and is_instance_valid(content_root.get_node_or_null("PortraitRaidView")):
		return Rect2(Vector2(205, 190), Vector2(630, 310))
	return Rect2(Vector2(32, 174), Vector2(maxf(1.0, _layout_width() - 64.0), 496))

func _emit_skill_cast_fx(hero_id: String, target_index: int, _aoe: bool, profile: Dictionary, ultimate := false) -> void:
	if ultimate: _presentation_event("ultimate")
	if not combat_effects_enabled or _application_suspended or active_screen not in ["combat", "raid"] or not is_instance_valid(skill_fx_layer):
		return
	# Legacy callers without a catalog slot retain the compact generic indicator.
	if not profile.has("slot") and not profile.has("id"):
		var target_point := _combat_enemy_screen_position(target_index)
		var accent := _hero_accent_color(hero_id)
		if _aoe: combat_fx.aoe_indicator(target_point, 36.0, accent, .42, false)
		combat_fx.projectile(_hero_skill_fx_position(hero_id), target_point, accent, "◆", .2, ultimate)
		return
	var points: Array[Dictionary] = []
	var enemy_targets: Array = profile.get("fx_targets", [target_index] if target_index >= 0 or active_screen == "raid" else [])
	for index in enemy_targets:
		var point := _combat_enemy_screen_position(int(index)) + Vector2(0, -18)
		points.append({"point":point, "mode":"enemy", "hits":int(profile.get("fx_target_hits", {}).get(int(index), profile.get("hits", 1)))})
	for item in profile.get("fx_allies", []):
		points.append({"point":_hero_skill_fx_position(str(item["hero_id"])), "mode":str(item["mode"])})
	var slot := str(profile.get("slot", "ultimate" if ultimate else "a1"))
	combat_fx.hero_skill(self, hero_id, slot, _hero_skill_fx_position(hero_id), points, profile, _hero_skill_fx_bounds())
	var accent := _hero_accent_color(hero_id)
	for item in points:
		if str(item.get("mode", "")) == "enemy":
			combat_fx.hit_spark(Vector2(item["point"]), accent, false, ultimate)
	if ultimate:
		combat_fx.camera_impact(3.6, 0.16, 0.008)
	skill_fx_sequence += 1

func _emit_passive_proc_fx(hero_id: String, target_index: int, profile: Dictionary, lowest_id: String) -> void:
	if not combat_effects_enabled or _application_suspended or active_screen not in ["combat", "raid"] or not is_instance_valid(skill_fx_layer):
		return
	var action := str(profile.get("action", "energy"))
	var target_id := lowest_id if action.begins_with("ally_") else hero_id
	var point := _hero_skill_fx_position(target_id)
	var mode := action.trim_prefix("ally_")
	if action == "damage":
		# The proc counter can advance after a finishing blow: never invent a hit on a dead target.
		if active_screen != "raid" and not _can_attack_enemy(hero_id, target_index): return
		point = _combat_enemy_screen_position(target_index) + Vector2(0, -18)
		mode = "enemy"
	elif action in ["heal", "ally_heal"]:
		if not hero_battle_state.has(target_id) or int(hero_battle_state[target_id]["hp"]) >= int(hero_battle_state[target_id]["max_hp"]): return
	elif action == "energy" and float(hero_battle_state[hero_id].get("ultimate", 0.0)) >= 100.0:
		return
	elif action == "cooldown" and float(hero_skill_runtime[hero_id].get("secondary_remaining", 0.0)) <= 0.0:
		return
	var points: Array[Dictionary] = [{"point":point, "mode":mode}]
	combat_fx.hero_skill(self, hero_id, "passive", _hero_skill_fx_position(hero_id), points, profile, _hero_skill_fx_bounds())

func _should_dodge_hit(hero_id: String, base_damage: int) -> bool:
	if not hero_battle_state.has(hero_id):
		return false
	var state: Dictionary = hero_battle_state[hero_id]
	var role_group := str(state.get("role_group", ""))
	if role_group == "탱커" or float(state.get("taunt", 0.0)) > 0.0:
		return false
	var slot := int(state.get("slot", 0))
	var cadence := 19 if role_group == "딜러" else 27
	state["incoming_hits"] = int(state.get("incoming_hits", 0)) + 1
	return ((int(state["incoming_hits"]) + slot * 7) % cadence) == 0

func _damage_enemy(enemy_index: int, damage: int, source_index := 0) -> int:
	if challenge_session != null and not CHALLENGE_DRIVER._report_active(self): return 0
	if damage <= 0 or enemy_index < 0 or enemy_index >= enemy_wave.size():
		return 0
	if active_screen == "combat" and roaming_hunt.is_returning(enemy_index):
		return 0
	var enemy: Dictionary = enemy_wave[enemy_index]
	if int(enemy.get("hp", 0)) <= 0:
		return 0
	var vulnerable := float(enemy.get("vulnerable_seconds", 0.0)) > 0.0 if active_screen == "combat" else _vulnerable_seconds > 0.0
	var multiplier := 1.25 if vulnerable else 1.0
	var critical := _guardian_bonus("crit") > 0.0 and loot_rng.randf() < _guardian_bonus("crit")
	if critical:multiplier *= 1.5
	# Clamp in floating point before converting to avoid int64 overflow.
	var actual := int(minf(float(enemy["hp"]), minf(float(damage), 1000000000.0) * multiplier))
	if critical and actual > 0: _presentation_event("critical")
	var hp_before: int = int(enemy["hp"])
	enemy["hp"] = maxi(0, hp_before - actual)
	if int(enemy["hp"])<=0:preload("res://scripts/hunting/HuntEfficiency.gd").kill(self)
	if challenge_session != null and int(enemy["hp"]) <= 0:
		preload("res://scripts/combat/ChallengePatternRuntime.gd").enemy_defeated(self, enemy_index)
	if challenge_session != null:
		CHALLENGE_DRIVER.record_damage(self, str(enemy.get("id", "")), hp_before, int(enemy["hp"]), source_index, critical)
	if enemy_index < enemy_hp_bars.size() and is_instance_valid(enemy_hp_bars[enemy_index]):
		enemy_hp_bars[enemy_index].value = 100.0 * float(enemy["hp"]) / maxf(1.0, float(enemy["max_hp"]))
	if enemy_index < enemy_wave_sprites.size() and is_instance_valid(enemy_wave_sprites[enemy_index]):
		var sprite: MonsterSpriteController = enemy_wave_sprites[enemy_index]
		var killed := int(enemy["hp"]) <= 0
		# Preserve the victim's facing; a hit from another direction is not a turn command.
		if killed:
			sprite.play_death()
		else:
			sprite.play_hit()
		combat_fx.hit_flash(sprite, Color("#fff0e2") if critical else Color("#ffd4d4"))
		var terrain: Control = combat_labels.get("terrain")
		if active_screen == "combat" and challenge_session == null and is_instance_valid(terrain) and terrain.has_method("hunt_hit"):
			var source_id := str(deployed_heroes[source_index].get("id", "")) if source_index >= 0 and source_index < deployed_heroes.size() else ""
			terrain.hunt_hit(roaming_hunt.enemy_position(enemy_index), _hero_field_position(source_id), GOLD if critical else _hero_accent_color(source_id), critical)
			if actual > 0 and terrain.has_method("frame_hit"):
				terrain.frame_hit(sprite, false, roaming_hunt.enemy_position(enemy_index) - _hero_field_position(source_id))
		else:
			combat_fx.impact(sprite.position - Vector2(0, 12), GOLD if critical else RED, 24.0 if critical else 16.0)
		if critical:
			combat_fx.hit_spark(sprite.position - Vector2(0, 12), GOLD, true, false)
			combat_fx.camera_impact(2.2, 0.10, 0.004)
		if killed and bool(enemy.get("treasure", false)) and not bool(enemy.get("treasure_expired", false)) and not bool(enemy.get("treasure_captured", false)):
			enemy["treasure_captured"] = true
			hunt_treasure_captured = true
			hunt_event_text = "보물 몬스터 포획 성공"
			_spawn_floating_combat_text("보물 포획!", GOLD, sprite.position - Vector2(70, 94))
			combat_fx.camera_impact(4.0, 0.14, 0.006)
		if killed and not bool(enemy.get("v72_death_fx", false)):
			enemy["v72_death_fx"] = true
			var death_color := GOLD if bool(enemy.get("treasure", false)) else (GOLD if bool(enemy.get("elite", false)) else Color("#dce9dd"))
			if active_screen != "combat" or bool(enemy.get("elite", false)) or bool(enemy.get("treasure", false)):
				combat_fx.death_burst(sprite.position - Vector2(0, 10), death_color, true)
			if bool(enemy.get("elite", false)) or bool(enemy.get("treasure", false)):
				combat_fx.camera_impact(4.4, 0.14, 0.007)
		_spawn_floating_combat_text(("치명! " if critical else "") + "-%d" % actual, GOLD if critical else RED, sprite.position - Vector2(90, 60) + Vector2(0, maxi(0, source_index) * 3))
	_sync_enemy_wave_summary()
	return actual

func _heal_hero(target_id: String, amount: int) -> int:
	if target_id.is_empty() or not hero_battle_state.has(target_id):
		return 0
	var state: Dictionary = hero_battle_state[target_id]
	if int(state.get("hp", 0)) <= 0:
		return 0
	var healed := mini(int(state["max_hp"]) - int(state["hp"]), maxi(0, amount))
	state["hp"] = int(state["hp"]) + healed
	RAID_REPORT.healed(self, target_id, healed)
	if challenge_session != null:
		CHALLENGE_DRIVER.record_healing(self, target_id, healed, int(state["hp"]))
	if hero_hp_bars.has(target_id) and is_instance_valid(hero_hp_bars[target_id]):
		hero_hp_bars[target_id].value = 100.0 * float(state["hp"]) / maxf(1.0, float(state["max_hp"]))
	_sync_party_hp_from_heroes()
	var slot := int(state.get("slot", 0))
	if healed > 0 and slot < hero_map_sprites.size() and is_instance_valid(hero_map_sprites[slot]):
		_spawn_floating_combat_text("+%d" % healed, GREEN, hero_map_sprites[slot].position - Vector2(90, 78))
	return healed

func _incoming_damage_to_hero(hero_id: String, base_damage: int, enemy_index: int = -1) -> int:
	if challenge_session != null and not CHALLENGE_DRIVER._report_active(self): return 0
	# The raid dodge promises party-wide immunity, including basic hits and add pulses.
	if active_screen == "raid" and raid_dodge_remaining > 0.0: return 0
	if base_damage <= 0 or hero_id.is_empty() or not hero_battle_state.has(hero_id):
		return 0
	var state: Dictionary = hero_battle_state[hero_id]
	if int(state.get("hp", 0)) <= 0:
		return 0
	var dodge_slot := int(state.get("slot", -1))
	if _should_dodge_hit(hero_id, base_damage):
		if dodge_slot >= 0 and dodge_slot < hero_map_sprites.size() and is_instance_valid(hero_map_sprites[dodge_slot]):
			var dodge_sprite: HeroSpriteController = hero_map_sprites[dodge_slot]
			combat_fx.dodge(dodge_sprite.position)
			combat_fx.hit_flash(dodge_sprite, Color("#9fe5ff"))
		_gain_ultimate(hero_id, 5.0)
		return 0
	var multiplier := 1.0
	if _guard_seconds > 0.0:
		multiplier *= 0.70
	var weakened := _weaken_seconds > 0.0
	if active_screen == "combat" and enemy_index >= 0 and enemy_index < enemy_wave.size():
		weakened = float(enemy_wave[enemy_index].get("weaken_seconds", 0.0)) > 0.0
	if weakened:
		multiplier *= 0.65
	if float(state.get("guard", 0.0)) > 0.0:
		multiplier *= 0.48
	var defense := int(state.get("defense", 0))
	var incoming := maxi(1, int(minf(float(base_damage), 1000000000.0) * multiplier) - int(defense * 0.35))
	var absorbed := mini(incoming, int(state.get("shield", 0)))
	state["shield"] = maxi(0, int(state.get("shield", 0)) - absorbed)
	var received := mini(int(state["hp"]), incoming - absorbed)
	var report_hp_before: int = int(state["hp"])
	state["hp"] = maxi(0, report_hp_before - received)
	RAID_REPORT.incoming(self, hero_id, report_hp_before, int(state["hp"]), absorbed)
	if challenge_session != null:
		CHALLENGE_DRIVER.record_incoming(self, hero_id, report_hp_before, int(state["hp"]), absorbed)
	state["alive"] = int(state["hp"]) > 0
	_gain_ultimate(hero_id, 8.0 + minf(6.0, float(received) / 35.0))
	if hero_hp_bars.has(hero_id) and is_instance_valid(hero_hp_bars[hero_id]):
		hero_hp_bars[hero_id].value = 100.0 * float(state["hp"]) / maxf(1.0, float(state["max_hp"]))
	var slot := int(state.get("slot", 0))
	if slot < hero_map_sprites.size() and is_instance_valid(hero_map_sprites[slot]):
		var sprite: HeroSpriteController = hero_map_sprites[slot]
		combat_fx.hit_flash(sprite, Color("#ffd0d0"))
		combat_fx.impact(sprite.position - Vector2(0, 8), RED, 15.0)
		if received >= maxi(8, int(float(state.get("max_hp", 1)) * 0.08)):
			combat_fx.camera_impact(2.4, 0.11, 0.004)
		_spawn_floating_combat_text("-%d HP" % received, RED, sprite.position - Vector2(90, 78))
		if int(state["hp"]) <= 0:
			sprite.play_death()
		elif received>0:
			sprite.play_hit()
		if received > 0 and active_screen == "combat" and challenge_session == null and enemy_index >= 0 and enemy_index < enemy_wave.size():
			var terrain: Control = combat_labels.get("terrain")
			if is_instance_valid(terrain) and terrain.has_method("frame_hit"):
				terrain.frame_hit(sprite, true, _hero_field_position(hero_id) - roaming_hunt.enemy_position(enemy_index))
	_sync_party_hp_from_heroes()
	if received > 0:
		var counter := HERO_KITS.event(self, hero_id, "hit", enemy_index)
		if active_screen == "raid":
			_apply_raid_damage(counter, hero_id)
	return received

func _cast_combat_skill(hero_id: String, target_index: int) -> int:
	if not preload("res://scripts/heroes/HeroCombatRules.gd").SKILLS.has(hero_id):
		return HERO_KITS.cast(self, hero_id, "a1", target_index)
	if not _should_use_skill(hero_id) or not hero_skill_runtime.has(hero_id):
		return 0
	if _combat_action_needs_enemy(hero_id, true, false) and not _can_attack_enemy(hero_id, target_index):
		return 0
	var runtime: Dictionary = hero_skill_runtime[hero_id]
	var hero: Dictionary = runtime["hero"]
	var profile: Dictionary = runtime["profile"]
	var state: Dictionary = hero_battle_state[hero_id]
	var attack := maxi(1, int(state.get("attack", 20)))
	var dealt := 0
	var visual_allies: Array[Dictionary] = []
	var visual_targets: Array[int] = []
	var visual_target_hits: Dictionary = {}
	var detail := str(profile.get("effect", ""))
	var kind := str(profile.get("kind", "damage"))
	var aoe := bool(profile.get("aoe", false))
	var targeting_profile := profile.duplicate(true)
	targeting_profile["avoid_active_status"] = true
	var targets := _hero_skill_enemy_targets(hero_id, target_index, targeting_profile)
	match kind:
		"guard":
			_perform_hero_guard(hero_id, profile, visual_allies)
		"heal":
			var healed := _perform_hero_healing(profile, visual_allies, hero_id)
			if healed <= 0:
				return 0
			detail = "%s · HP +%d" % [detail, healed]
		"weaken", "vulnerable":
			var applied := false
			for index in targets:
				var just_applied := _apply_enemy_status(index, kind, float(profile.get("duration", 3.0)))
				applied = just_applied or applied
				if just_applied:
					visual_targets.append(index)
					visual_target_hits[index] = 1
			if not applied:
				return 0
		_:
			if targets.is_empty():
				return 0
			var hits := maxi(1, int(profile.get("hits", 1)))
			for hit in hits:
				if not aoe and not _can_attack_enemy(hero_id, targets[0]):
					var replacement := _select_enemy_target(hero_id)
					if not _can_attack_enemy(hero_id, replacement):
						break
					targets[0] = replacement
				for index in targets:
					if not _can_attack_enemy(hero_id, index):
						continue
					if not visual_targets.has(index): visual_targets.append(index)
					visual_target_hits[index] = int(visual_target_hits.get(index, 0)) + 1
					if kind == "stun":
						_apply_enemy_status(index, "stun", float(profile.get("duration", 0.5)))
					var scale := float(profile.get("aoe_scale", 1.0)) / float(hits)
					dealt += _damage_enemy(index, preload("res://scripts/heroes/HeroCombatRules.gd").hit_damage(profile, attack, enemy_wave[index], scale), int(state.get("slot", 0)))
			if kind == "lifesteal":
				var healed := _heal_hero(hero_id, preload("res://scripts/heroes/HeroCombatRules.gd").lifesteal_amount(profile, state, dealt))
				if healed > 0: visual_allies.append({"hero_id":hero_id, "mode":"return"})
				detail = "%s · 자신 HP +%d" % [detail, healed]
			if float(profile.get("self_guard", 0.0)) > 0.0:
				state["guard"] = maxf(float(state.get("guard", 0.0)), float(profile["self_guard"]))
				visual_allies.append({"hero_id":hero_id, "mode":"guard"})
	var visual_profile := profile.duplicate(true)
	visual_profile["id"] = hero_id + "_a1"
	visual_profile["slot"] = "a1"
	visual_profile["fx_targets"] = visual_targets
	visual_profile["fx_target_hits"] = visual_target_hits
	visual_profile["fx_allies"] = visual_allies
	_emit_skill_cast_fx(hero_id, target_index, aoe, visual_profile, false)
	runtime["remaining"] = float(profile["cooldown"])
	_gain_ultimate(hero_id, 15.0 + float(profile.get("extra_ultimate", 0.0)))
	skill_event_text = "%s · %s · %s" % [hero["name"], profile["skill"], detail]
	_emit_skill_fx(hero, profile, dealt)
	runtime["casts_a1"] = int(runtime.get("casts_a1", 0)) + 1
	dealt += HERO_KITS.event(self, hero_id, "cast", target_index)
	return dealt

func _hero_short_name(hero_id: String) -> String:
	for hero in deployed_heroes:
		if str(hero["id"]) == hero_id:
			return str(hero["name"]).get_slice(" ", 0)
	return hero_id

func _run_hero_skills(delta := 0.5) -> int:
	# Raid/legacy adapter. Prioritize emergency healing, then damage, then utility.
	_advance_skill_cooldowns(delta)
	var ready_ids: Array[String] = []
	for hero_id in hero_skill_runtime.keys():
		if _should_use_skill(str(hero_id)):
			ready_ids.append(str(hero_id))
	var ordered_ids: Array[String] = []
	var priority_groups := [
		["heal"],
		["damage", "lifesteal", "stun"],
		["guard"],
		["weaken", "vulnerable"]
	]
	for kinds in priority_groups:
		for hero_id in ready_ids:
			var kind := str(hero_skill_runtime[hero_id]["profile"].get("kind", "damage"))
			if kind in kinds and hero_id not in ordered_ids:
				ordered_ids.append(hero_id)
	for hero_id in ready_ids:
		if hero_id not in ordered_ids:
			ordered_ids.append(hero_id)
	var damage := 0
	var casts := 0
	for hero_id in ordered_ids:
		damage += _cast_hero_skill(hero_id)
		casts += 1
		if casts >= 2:
			break
	return damage

func _incoming_damage(base_damage: int) -> int:
	if base_damage <= 0 or _stun_seconds > 0.0:
		return 0
	var multiplier := 1.0
	if _guard_seconds > 0.0:
		multiplier *= 0.55
	if _weaken_seconds > 0.0:
		multiplier *= 0.65
	return maxi(1, int(minf(float(base_damage), 1000000000.0) * multiplier))

func _update_skill_label() -> void:
	var label: Label = combat_labels.get("skills")
	if not is_instance_valid(label):
		return
	var ready := 0
	var healing_ready := 0
	var cooling := 0
	for hero_id in hero_skill_runtime.keys():
		var runtime: Dictionary = hero_skill_runtime[hero_id]
		if float(runtime.get("secondary_remaining", 0.0)) <= 0.0:
			ready += 1
		if float(runtime["remaining"]) <= 0.0:
			ready += 1
			if str(runtime["profile"].get("kind", "damage")) == "heal":
				healing_ready += 1
		else:
			cooling += 1
	var synergy := _calculate_party_synergy()
	var recent := skill_event_text if not skill_event_text.is_empty() else "첫 스킬 대기 중"
	var ultimate_ready := 0
	var ultimate_total := 0.0
	for hero_id in _alive_hero_ids():
		ultimate_total += float(hero_battle_state[hero_id].get("ultimate", 0.0))
		if _ultimate_ready(hero_id):
			ultimate_ready += 1
	var ultimate_avg := int(ultimate_total / maxf(1.0, float(_alive_hero_ids().size())))
	var pet_name := str(pet_runtime.get("name", "수호신 없음"))
	label.text = "스킬 %d/%d · 궁극기 READY %d · 평균 게이지 %d%% · x%d\n%s\n수호신 %s · 시너지 %s" % [ready, hero_skill_runtime.size() * 2, ultimate_ready, ultimate_avg, int(battle_speed), recent, pet_name, synergy["summary"]]

func _build_raid_screen() -> void:
	preload("res://scripts/raid/RaidScreen.gd").build(self)

func _raid_zone() -> Dictionary:
	return _zone_data().get(selected_raid_id, _current_zone())

func _boss_pattern_profile(zone_id: String) -> Dictionary:
	return preload('res://scripts/raid/RaidBossDesign.gd').pattern(zone_id,raid_phase)

func _boss_cast_profile(zone_id: String) -> Dictionary:
	return preload('res://scripts/raid/RaidBossDesign.gd').pattern(zone_id,raid_phase,raid_pattern_sequence)

func _raid_phase_hint(zone_id: String = '') -> String:
	var id := raid_encounter_zone if zone_id.is_empty() else zone_id
	return str(_boss_pattern_profile(id).get('phase_hint','패턴 예고를 보고 안전 지대로 이동하세요.'))

func _reset_raid_encounter() -> void:
	raid_encounter_zone = selected_raid_id if _zone_data().has(selected_raid_id) else current_zone_id
	raid_reward_settled = false
	raid_outcome = "ready"
	raid_elapsed = 0.0
	raid_phase = 1
	raid_enraged = false
	raid_control_immunity = 0.0
	raid_interrupt_count = 0
	raid_pattern_count = 0
	raid_pattern_sequence = 0
	raid_damage_dealt = 0
	raid_event_text = ""
	raid_reward_receipt = {}
	raid_last_result = ""
	raid_boss_turns = 0
	raid_boss_attack_remaining = 0.8
	boss_telegraph_remaining = 0.0
	boss_telegraph_pending = false
	boss_telegraph_skill = ""
	raid_cast_profile.clear()
	raid_pattern_shape.clear()
	raid_second_wave_shape.clear()
	raid_positions.clear()
	raid_boss_position = RAID_FIELD.ENTRY
	raid_rally_active = false
	raid_dodge_remaining = 0.0
	raid_dodge_cooldown = 0.0
	raid_evaded_hits = 0
	raid_second_wave_profile.clear()
	raid_second_wave_remaining = 0.0
	raid_hit_fx_remaining = 0.0
	raid_break_gauge = 0.0
	raid_guard_hp = 0
	raid_guard_max_hp = 0
	raid_guard_breaks = 0
	raid_add_hp = 0
	raid_add_max_hp = 0
	raid_add_count = 0
	raid_add_attack_remaining = 0.0
	raid_add_waves_cleared = 0
	raid_dps_check_remaining = 0.0
	raid_dps_check_target = 0
	raid_dps_check_damage = 0
	raid_dps_checks_passed = 0
	raid_dps_checks_failed = 0
	raid_mechanic_rage_stacks = 0
	raid_last_mechanic_phase = 0
	skill_event_text = ""
	combat_tick_count = 0

func _raid_mechanic_profile(zone_id: String = "", phase: int = -1) -> Dictionary:
	var id: String = raid_encounter_zone if zone_id.is_empty() else zone_id
	var resolved_phase: int = raid_phase if phase < 0 else phase
	return preload("res://scripts/raid/RaidBossDesign.gd").mechanic(id, resolved_phase)

func _raid_activate_phase_mechanic(phase: int) -> void:
	if phase <= 0 or raid_last_mechanic_phase == phase:
		return
	raid_last_mechanic_phase = phase
	raid_guard_hp = 0
	raid_guard_max_hp = 0
	raid_add_hp = 0
	raid_add_max_hp = 0
	raid_add_count = 0
	raid_add_attack_remaining = 0.0
	raid_dps_check_remaining = 0.0
	raid_dps_check_target = 0
	raid_dps_check_damage = 0
	var profile: Dictionary = _raid_mechanic_profile(raid_encounter_zone, phase)
	var kind: String = str(profile.get("kind", "none"))
	if kind == "guard":
		raid_guard_max_hp = maxi(1, int(float(raid_boss_max_hp) * float(profile.get("ratio", 0.10))))
		raid_guard_hp = raid_guard_max_hp
		raid_event_text = "%s 전개 · 보호막 %d" % [str(profile.get("name", "보호막")), raid_guard_max_hp]
	elif kind == "adds":
		raid_add_count = maxi(1, int(profile.get("count", 2)))
		raid_add_max_hp = maxi(1, int(float(raid_boss_max_hp) * float(profile.get("ratio", 0.08))))
		raid_add_hp = raid_add_max_hp
		raid_add_attack_remaining = maxf(0.8, float(profile.get("pulse", 3.0)) * 0.60)
		raid_event_text = "%s %d개 소환 · 먼저 파괴하세요" % [str(profile.get("name", "소환체")), raid_add_count]
	elif kind == "dps_check":
		raid_dps_check_remaining = maxf(1.0, float(profile.get("duration", 8.0)))
		raid_dps_check_target = maxi(1, int(float(raid_boss_max_hp) * float(profile.get("ratio", 0.08))))
		raid_dps_check_damage = 0
		raid_event_text = "%s 시작 · %.1f초 안에 피해 %d" % [str(profile.get("name", "의식")), raid_dps_check_remaining, raid_dps_check_target]
	if kind != "none" and combat_effects_enabled and is_instance_valid(raid_boss_sprite):
		var accent: Color = preload("res://scripts/raid/RaidBossDesign.gd").raid(raid_encounter_zone)["accent"]
		combat_fx.aoe_indicator(raid_boss_position, 118.0, accent, 0.72, false, str(profile.get("name", "기믹")))
		combat_fx.camera_impact(2.6, 0.14, 0.006)

func _raid_mechanic_status() -> Dictionary:
	if boss_telegraph_pending or raid_second_wave_remaining > 0.0:
		return {"active": true, "kind": "break", "label": "차단 게이지 %d%%" % roundi(100.0 * raid_break_gauge / maxf(1.0, raid_break_gauge_max)), "value": 100.0 * raid_break_gauge / maxf(1.0, raid_break_gauge_max)}
	if raid_guard_hp > 0:
		return {"active": true, "kind": "guard", "label": "대지 갑주 %d / %d" % [raid_guard_hp, raid_guard_max_hp], "value": 100.0 * float(raid_guard_hp) / maxf(1.0, float(raid_guard_max_hp))}
	if raid_add_hp > 0:
		return {"active": true, "kind": "adds", "label": "수정핵 %d개 · 내구 %d / %d" % [raid_add_count, raid_add_hp, raid_add_max_hp], "value": 100.0 * float(raid_add_hp) / maxf(1.0, float(raid_add_max_hp))}
	if raid_dps_check_remaining > 0.0 and raid_dps_check_target > 0:
		return {"active": true, "kind": "dps_check", "label": "월식 의식 %.1f초 · 피해 %d / %d" % [raid_dps_check_remaining, raid_dps_check_damage, raid_dps_check_target], "value": 100.0 * float(raid_dps_check_damage) / maxf(1.0, float(raid_dps_check_target))}
	return {"active": false, "kind": "none", "label": "", "value": 0.0}

func _raid_performance_crystal_bonus() -> int:
	# Performance currency is earned only by successfully resolving authored mechanics.
	# A synthetic/manual victory with no mechanics therefore retains the legacy reward exactly.
	return mini(12, raid_guard_breaks * 2 + raid_add_waves_cleared * 2 + raid_dps_checks_passed * 3 + mini(3, raid_interrupt_count))

func _raid_record_dps_check(actual_damage: int) -> void:
	if actual_damage <= 0 or raid_dps_check_remaining <= 0.0 or raid_dps_check_target <= 0:
		return
	raid_dps_check_damage = mini(raid_dps_check_target, raid_dps_check_damage + actual_damage)
	if raid_dps_check_damage < raid_dps_check_target:
		return
	raid_dps_checks_passed += 1
	raid_dps_check_remaining = 0.0
	_vulnerable_seconds = maxf(_vulnerable_seconds, 3.0)
	raid_event_text = "월식 의식 파훼! · 3초 약점 노출"
	if combat_effects_enabled and is_instance_valid(raid_boss_sprite):
		var accent: Color = preload("res://scripts/raid/RaidBossDesign.gd").raid(raid_encounter_zone)["accent"]
		combat_fx.impact(raid_boss_position - Vector2(0, 56), accent, 54.0)
		combat_fx.camera_impact(4.2, 0.18, 0.010)

func _raid_advance_mechanics(delta: float) -> void:
	if raid_add_hp > 0 and raid_add_count > 0:
		raid_add_attack_remaining = maxf(0.0, raid_add_attack_remaining - delta)
		if raid_add_attack_remaining <= 0.00001:
			var profile: Dictionary = _raid_mechanic_profile()
			raid_add_attack_remaining = maxf(1.2, float(profile.get("pulse", 3.0)))
			var target_id: String = _select_raid_hero_target("rear")
			if not target_id.is_empty():
				var pulse_multiplier: float = 0.28 + 0.10 * float(raid_add_count)
				var actual: int = _incoming_damage_to_hero(target_id, int(float(raid_boss_attack) * pulse_multiplier * _raid_attack_multiplier()))
				raid_event_text = "수정핵 폭발 · %s 피해 %d" % [_hero_short_name(target_id), actual]
	if raid_dps_check_remaining > 0.0:
		raid_dps_check_remaining = maxf(0.0, raid_dps_check_remaining - delta)
		if raid_dps_check_remaining <= 0.00001 and raid_dps_check_damage < raid_dps_check_target:
			var profile: Dictionary = _raid_mechanic_profile()
			var recovered: int = mini(raid_boss_max_hp - raid_boss_hp, maxi(1, int(float(raid_boss_max_hp) * float(profile.get("heal_ratio", 0.04)))))
			raid_boss_hp += recovered
			raid_dps_checks_failed += 1
			raid_mechanic_rage_stacks = mini(2, raid_mechanic_rage_stacks + 1)
			if bool(profile.get("enrage_on_fail", false)):
				raid_enraged = true
			raid_event_text = "월식 의식 실패 · 보스 HP +%d · 공격 압박 상승" % recovered

func _raid_attack_multiplier() -> float:
	return (1.0 + 0.12 * float(raid_phase - 1)) * (1.0 + 0.12 * float(raid_mechanic_rage_stacks)) * (1.60 if raid_enraged else 1.0)

func _raid_attack_interval() -> float:
	return (0.9 - 0.08 * float(raid_phase - 1)) * (0.75 if raid_enraged else 1.0)

func _raid_control_window() -> bool:
	# Reserve control for a cast that can actually be interrupted; finish low HP bosses.
	return raid_boss_hp <= int(raid_boss_max_hp * 0.12) or ((boss_telegraph_pending or raid_second_wave_remaining > 0.0) and raid_control_immunity <= 0.0)

func _raid_apply_control(duration: float, source_id: String = "") -> bool:
	if not raid_running or raid_boss_hp <= 0 or raid_control_immunity > 0.0 or duration <= 0.0:
		return false
	var interruptible: bool = boss_telegraph_pending or raid_second_wave_remaining > 0.0
	if interruptible:
		raid_break_gauge = minf(raid_break_gauge_max, raid_break_gauge + maxf(18.0, duration * 160.0))
		if raid_break_gauge < raid_break_gauge_max - 0.001:
			_stun_seconds = maxf(_stun_seconds, minf(0.20, duration * 0.25))
			raid_event_text = "차단 게이지 %d%% · 제어 스킬을 이어서 사용하세요" % roundi(100.0 * raid_break_gauge / raid_break_gauge_max)
			return true
		_stun_seconds = maxf(_stun_seconds, minf(duration, 1.5))
		raid_control_immunity = 6.0
		raid_break_gauge = 0.0
		if boss_telegraph_pending:
			boss_telegraph_pending = false
			boss_telegraph_remaining = 0.0
			raid_cast_profile.clear()
			raid_pattern_shape.clear()
			raid_boss_attack_remaining = _raid_attack_interval()
			raid_interrupt_count += 1
			RAID_REPORT.add(self, source_id, "interrupts", 1)
			_vulnerable_seconds = maxf(_vulnerable_seconds, 2.0)
			raid_event_text = "%s 차단 성공! · 2초 약점 노출 · 제어 면역 6초" % boss_telegraph_skill
		elif raid_second_wave_remaining > 0.0:
			raid_second_wave_remaining = 0.0
			raid_second_wave_profile.clear()
			raid_second_wave_shape.clear()
			_vulnerable_seconds = maxf(_vulnerable_seconds, 2.0)
			raid_interrupt_count += 1
			RAID_REPORT.add(self, source_id, "interrupts", 1)
			raid_event_text = "후속 충격 차단 성공! · 2초 약점 노출"
		return true
	# Preserve the old low-HP control window for controller finishers.
	_stun_seconds = maxf(_stun_seconds, minf(duration, 1.5))
	raid_control_immunity = 6.0
	return true

func _apply_boss_pattern(profile: Dictionary) -> String:
	if raid_boss_hp <= 0 or _alive_hero_ids().is_empty() or _stun_seconds > 0.0:
		return "시전 취소"
	if is_instance_valid(raid_boss_sprite):raid_boss_sprite.play_attack('left')
	var kind := str(profile.get("kind", "aoe"))
	var multiplier := float(profile.get("multiplier", 1.4))
	var actual_damage := 0
	var targets: Array[String] = _alive_hero_ids()
	var shape: Dictionary = raid_pattern_shape if not raid_pattern_shape.is_empty() else _raid_create_pattern_shape(kind,profile)
	var avoided := 0
	for hero_id in targets:
		# A hit passive may kill the boss during this area attack. Later targets
		# cannot be hit by a dead actor, and life drain must not revive it.
		if raid_boss_hp <= 0:
			break
		if raid_dodge_remaining > 0.0 or not RAID_FIELD.contains(shape, raid_positions.get(hero_id, RAID_FIELD.hero_entry(0))):
			avoided += 1
			continue
		actual_damage += _incoming_damage_to_hero(hero_id,int(raid_boss_attack*multiplier*_raid_attack_multiplier()))
	raid_evaded_hits += avoided
	raid_pattern_count += 1
	if kind=='earthquake' and raid_boss_hp>0 and not _alive_hero_ids().is_empty():
		raid_second_wave_profile=profile.duplicate(true)
		raid_second_wave_shape=shape.duplicate(true)
		raid_second_wave_remaining=.42
		raid_break_gauge=0.0
	if kind in ['curse','moon_mark'] and raid_boss_hp > 0:
		# Drain is based on actual HP removed, so guard and mitigation reduce healing.
		var recovered := mini(raid_boss_max_hp - raid_boss_hp, mini(int(raid_boss_max_hp * (0.025 if kind=='moon_mark' else 0.04)), int(actual_damage * (0.30 if kind=='moon_mark' else 0.40))))
		raid_boss_hp += recovered
		return "%s · 피해 %d · 회피 %d · 보스 HP +%d" % ['두 영웅 표식' if kind=='moon_mark' else '월식 저주',actual_damage,avoided,recovered]
	var shape_text: String={'front_blast':'낙석 통로','rear_blast':'수정 관통','double_lane':'쌍광맥 통로','cross':'십자 균열','cone':'부채꼴 파쇄','earthquake':'연속 지진','aoe':'대지 포효'}.get(kind,'광역 공격')
	return "%s · 피해 %d · 회피 %d" % [shape_text,actual_damage,avoided]

func _raid_create_pattern_shape(kind: String, profile: Dictionary = {}) -> Dictionary:
	var marks: Array[Vector2] = []
	var candidates := _alive_hero_ids()
	if kind == "moon_mark":
		candidates.sort_custom(func(a: String, b: String) -> bool:
			return float(hero_battle_state[a]["hp"]) / maxf(1.0, float(hero_battle_state[a]["max_hp"])) < float(hero_battle_state[b]["hp"]) / maxf(1.0, float(hero_battle_state[b]["max_hp"]))
		)
		var mark_count := clampi(int(profile.get('mark_count',2)),1,3)
		for id in candidates.slice(0, mark_count): marks.append(raid_positions.get(id, RAID_FIELD.hero_entry(0)))
	elif kind in ["front_blast", "rear_blast"]:
		var lane := "front" if kind == "front_blast" else "rear"
		for id in candidates:
			if str(hero_battle_state[id].get("row", "front")) == lane:
				marks.append(raid_positions.get(id, RAID_FIELD.hero_entry(0)))
		if not marks.is_empty():
			var center := Vector2.ZERO
			for point in marks: center += point
			marks.assign([center / float(marks.size())])
	elif kind in ["double_lane", "cross", "cone"]:
		var target_id := _select_raid_hero_target(str(profile.get('basic_target','auto')))
		if not target_id.is_empty(): marks.append(raid_positions.get(target_id,RAID_FIELD.hero_entry(0)))
	return RAID_FIELD.footprint(kind, raid_boss_position, marks, profile)

func _raid_order_move(point: Vector2) -> void:
	if not raid_running: return
	raid_rally_position = RAID_FIELD.clamp_to_floor(point)
	raid_rally_active = true

func _raid_dodge() -> void:
	if not raid_running or raid_dodge_cooldown > 0.0: return
	raid_dodge_cooldown = 5.0
	raid_dodge_remaining = 0.50
	var shape: Dictionary = raid_second_wave_shape if raid_second_wave_remaining > 0.0 else raid_pattern_shape
	for id in _alive_hero_ids():
		var current: Vector2 = raid_positions.get(id, RAID_FIELD.hero_entry(0))
		var destination: Vector2 = RAID_FIELD.escape_position(shape, current) if not shape.is_empty() else current + Vector2(-68.0, 0.0)
		raid_positions[id] = RAID_FIELD.clamp_to_floor(current.move_toward(destination, 90.0))
	raid_event_text = "긴급 회피! · 0.5초 피격 면역"

func _raid_manual_cast(ultimate: bool, selected_id: String = "") -> bool:
	if not raid_running or raid_boss_hp <= 0: return false
	var best_id := ""
	var best_slot := ""
	var best_score := -1
	for id in _alive_hero_ids():
		if not selected_id.is_empty() and id != selected_id: continue
		if raid_positions.get(id, RAID_FIELD.hero_entry(0)).distance_to(raid_boss_position) > 335.0: continue
		for slot in (["ultimate"] if ultimate else ["a1", "a2"]):
			if not HERO_KITS.can_use(self, id, slot): continue
			var score: int = HERO_KITS.priority(self, id, slot)
			if score > best_score:
				best_score = score
				best_id = id
				best_slot = slot
	if best_id.is_empty(): return false
	var damage := _cast_raid_ultimate(best_id) if ultimate else (HERO_KITS.cast(self, best_id, best_slot))
	_apply_raid_damage(damage, best_id)
	if has_method("_raid_play_hero_action"): call("_raid_play_hero_action", best_id, best_slot)
	if raid_boss_hp <= 0: _finish_raid("victory")
	return true

func _raid_party_center() -> Vector2:
	var center := Vector2.ZERO
	var count := 0
	for id in _alive_hero_ids():
		if raid_positions.has(id):
			center += raid_positions[id]
			count += 1
	return center / float(count) if count > 0 else Vector2(420.0,390.0)

func _raid_role_destination(hero_id: String, index: int) -> Vector2:
	var state: Dictionary=hero_battle_state.get(hero_id,{})
	var role := str(state.get('role_group','딜러'))
	var style := str(state.get('ai_style','balanced'))
	var attack_range := maxi(1,int(state.get('range',2)))
	var away := (_raid_party_center()-raid_boss_position).normalized()
	if away.length_squared()<0.01: away=Vector2.LEFT
	var side := Vector2(-away.y,away.x)
	var sign := -1.0 if abs(hash(hero_id))%2==0 else 1.0
	var distance := 188.0 if attack_range>=3 else (154.0 if attack_range==2 else 116.0)
	var lateral := float((index%5)-2)*26.0
	if role=='탱커' or style=='protector':
		distance=112.0;lateral*=.75
	elif role=='서포터' or style=='support':
		distance=284.0;lateral+=sign*18.0
	elif role=='컨트롤러' or style in ['controller','control']:
		distance=238.0;lateral+=sign*64.0
	elif attack_range<=1 and style in ['aggressive','finisher']:
		distance=106.0;lateral+=sign*(52.0 if style=='aggressive' else 42.0)
	elif style=='aggressive':
		distance=maxf(168.0,distance-28.0);lateral+=sign*20.0
	elif style=='finisher':
		distance=minf(278.0,distance+32.0);lateral+=sign*28.0
	return RAID_FIELD.clamp_to_floor(raid_boss_position+away*distance+side*lateral)

func _raid_reaction_window(hero_id: String) -> float:
	var state: Dictionary=hero_battle_state.get(hero_id,{})
	var role := str(state.get('role_group','딜러'))
	var style := str(state.get('ai_style','balanced'))
	if role=='서포터' or style=='support': return 1.05
	if role=='컨트롤러' or style in ['controller','control']: return 0.98
	if maxi(1,int(state.get('range',2)))>=3: return 0.90
	if role=='탱커' or style=='protector': return 0.64
	if style=='aggressive': return 0.58
	return 0.76

func _raid_basic_target_mode() -> String:
	var mode := str(_boss_pattern_profile(raid_encounter_zone).get('basic_target','front'))
	if mode=='row_cycle': return 'rear' if raid_boss_turns%2==0 else 'front'
	return mode

func _raid_auto_evade_allowed(hero_id: String, index: int) -> bool:
	var state: Dictionary=hero_battle_state.get(hero_id,{})
	var role := str(state.get('role_group','딜러'))
	var style := str(state.get('ai_style','balanced'))
	if role in ['서포터','컨트롤러'] or style in ['support','controller','control']:
		return true
	# Keep manual dodge meaningful: committed frontliners do not all abandon the
	# boss automatically, matching the original partial auto-evade behavior.
	if role=='탱커' or style=='protector': return index%3!=0
	if maxi(1,int(state.get('range',2)))<=1 and style=='aggressive': return index%4!=0
	return index%3!=0

func _raid_move_actors(delta: float) -> void:
	raid_dodge_remaining = maxf(0.0, raid_dodge_remaining - delta)
	raid_dodge_cooldown = maxf(0.0, raid_dodge_cooldown - delta)
	var design: Dictionary=preload('res://scripts/raid/RaidBossDesign.gd').raid(raid_encounter_zone)
	var movement := str(design.get('movement','bulwark'))
	var anchor := Vector2(705.0 + sin(raid_elapsed * 0.67) * 54.0, 386.0 + cos(raid_elapsed * 0.93) * 39.0)
	if boss_telegraph_pending:
		anchor = raid_boss_position
	else:
		var chosen := _select_raid_hero_target(_raid_basic_target_mode())
		if raid_positions.has(chosen):
			var target: Vector2=raid_positions[chosen]
			var chase_distance := 185.0
			if movement=='hunter': chase_distance=165.0
			elif movement=='stalker': chase_distance=205.0
			if raid_boss_position.distance_to(target)>chase_distance:
				var offset:=Vector2(112.0,-6.0)
				if movement=='stalker':offset=Vector2(128.0,34.0*sin(raid_elapsed*1.15))
				anchor=target+offset
	var boss_speed := 66.0 if movement=='bulwark' else (86.0 if movement=='hunter' else 78.0)
	if raid_enraged: boss_speed*=1.32
	raid_boss_position = RAID_FIELD.clamp_to_floor(raid_boss_position.move_toward(anchor, delta * boss_speed))
	if is_instance_valid(raid_boss_sprite):
		raid_boss_sprite.set_world_position(raid_boss_position)
		if not boss_telegraph_pending and raid_boss_sprite.state == "idle" and raid_boss_position.distance_to(anchor) > 6.0:
			raid_boss_sprite.play_walk(anchor - raid_boss_position)
		elif raid_boss_sprite.state == "walk" and raid_boss_position.distance_to(anchor) <= 6.0:
			raid_boss_sprite.play_idle("left")
	var followup := raid_second_wave_remaining>0.0
	var shape: Dictionary = raid_second_wave_shape if followup else raid_pattern_shape
	var warning_remaining := raid_second_wave_remaining if followup else boss_telegraph_remaining
	var goals: Dictionary={}
	var speeds: Dictionary={}
	for i in deployed_heroes.size():
		var id: String = str(deployed_heroes[i]["id"])
		if not raid_positions.has(id) or int(hero_battle_state.get(id, {}).get("hp", 0)) <= 0: continue
		var current: Vector2 = raid_positions[id]
		var role_destination: Vector2 = _raid_role_destination(id,i)
		var destination: Vector2 = role_destination
		if raid_rally_active:
			destination = raid_rally_position + Vector2(float(i % 5 - 2) * 48.0, float(i / 5) * 68.0-34.0)
		elif not shape.is_empty() and (boss_telegraph_pending or followup) and warning_remaining <= _raid_reaction_window(id) and _raid_auto_evade_allowed(id,i) and RAID_FIELD.contains(shape,current):
			destination = RAID_FIELD.escape_position(shape, current)
		goals[id]=RAID_FIELD.clamp_to_floor(destination)
		speeds[id]=205.0 if raid_rally_active else (158.0 if destination!=role_destination else 128.0)
	goals=RAID_FIELD.spread_destinations(goals,shape if boss_telegraph_pending or followup else {})
	RAID_FIELD.advance_positions(raid_positions,goals,speeds,raid_boss_position,delta,shape if boss_telegraph_pending or followup else {})

func _apply_raid_second_wave() -> void:
	var profile: Dictionary=raid_second_wave_profile.duplicate(true)
	raid_second_wave_profile.clear()
	if raid_boss_hp<=0 or _alive_hero_ids().is_empty() or _stun_seconds>0.0:return
	if is_instance_valid(raid_boss_sprite):raid_boss_sprite.play_attack('left')
	var total:=0
	var avoided:=0
	for id in _alive_hero_ids():
		if raid_boss_hp<=0:break
		if raid_dodge_remaining>0.0 or not RAID_FIELD.contains(raid_second_wave_shape, raid_positions.get(id,RAID_FIELD.hero_entry(0))):
			avoided+=1
			continue
		total+=_incoming_damage_to_hero(id,int(raid_boss_attack*float(profile.get('multiplier',.88))*_raid_attack_multiplier()))
	raid_evaded_hits+=avoided
	raid_second_wave_shape.clear()
	raid_event_text='2차 지진 · 피해 %d · 회피 %d'%[total,avoided]

func _start_raid() -> void:
	if bool(get_meta("practice_active", false)) or preload("res://scripts/persistence/SaveSafety.gd").pending(self):
		_show_toast("연습을 종료하거나 저장 대기를 먼저 해결해 주세요."); return
	if active_screen != "raid" or raid_running or deployed_heroes.is_empty():
		return
	if equipment_overflow.size()>GEAR_OVERFLOW_CAP-2:
		_show_toast("레이드 보상 배송을 위해 우편함에 빈칸 2개를 확보하세요.")
		return
	if is_instance_valid(combat_timer):
		combat_timer.stop()
		combat_timer.queue_free()
	var old_result := content_root.get_node_or_null("BattleResultPopup") if is_instance_valid(content_root) else null
	if is_instance_valid(old_result):
		old_result.queue_free()
	_reset_raid_encounter()
	raid_encounter_serial += 1
	var zone: Dictionary = _zone_data().get(raid_encounter_zone, _current_zone())
	raid_running = true
	_record_first_session_action("raid_started")
	_save_idle_state()
	raid_outcome = "running"
	raid_boss_name = str(zone["boss"])
	var raid_stats: Dictionary = preload("res://scripts/raid/RaidBalance.gd").stats(zone)
	raid_boss_max_hp = int(raid_stats["max_hp"])
	raid_boss_hp = raid_boss_max_hp
	raid_boss_attack = int(raid_stats["attack"])
	party_power = _calculate_party_power()
	_raid_activate_phase_mechanic(1)
	_setup_hero_skills()
	RAID_REPORT.begin(self)
	for i in deployed_heroes.size():
		raid_positions[str(deployed_heroes[i]["id"])] = RAID_FIELD.hero_entry(i)
	if is_instance_valid(raid_boss_sprite): raid_boss_sprite.set_world_position(raid_boss_position)
	_update_boss_portrait(raid_boss_name)
	var start: Button = combat_labels.get("raid_start")
	if is_instance_valid(start):
		start.disabled = true
		start.text = "레이드 진행 중"
	_update_raid_hud()
	var raid_view := content_root.get_node_or_null("PortraitRaidView") if is_instance_valid(content_root) else null
	if is_instance_valid(raid_view): raid_view.start_entry()
	var timer := Timer.new()
	timer.wait_time = 0.25
	timer.one_shot = false
	timer.timeout.connect(_on_raid_tick.bind(raid_encounter_serial))
	combat_timer = timer
	add_child(timer)
	timer.start()

func _on_raid_tick(expected_serial: int = -1) -> void:
	if not raid_running or active_screen != "raid" or _application_suspended:
		return
	if expected_serial >= 0 and expected_serial != raid_encounter_serial:
		return
	# An encounter keeps its entry zone and never pays a different zone's reward.
	if not selected_raid_id.is_empty() and selected_raid_id != raid_encounter_zone:
		_finish_raid("cancelled")
		return
	var remaining := 0.25 * clampf(battle_speed, 1.0, 2.0)
	var damage_before := raid_damage_dealt
	# Fixed simulation steps make x1/x2/x4 share cooldowns, reaction windows and DPS.
	while remaining > 0.00001 and raid_running:
		var step := minf(RAID_STEP, remaining)
		_advance_raid_encounter(step)
		remaining -= step
	_update_raid_hud(raid_damage_dealt - damage_before)

func _apply_raid_damage(raw_damage: int, source_id: String = "") -> int:
	if not raid_running or raid_boss_hp <= 0 or raw_damage <= 0:
		return 0
	var critical: bool = _guardian_bonus("crit") > 0.0 and loot_rng.randf() < _guardian_bonus("crit")
	var critical_multiplier: float = 1.5 if critical else 1.0
	var remaining_damage: int = maxi(0, int(float(raw_damage) * critical_multiplier))
	var mechanic_damage := 0
	# Forgotten Mine: summoned crystal cores intercept attacks until destroyed.
	if raid_add_hp > 0 and remaining_damage > 0:
		var add_damage: int = mini(raid_add_hp, remaining_damage)
		raid_add_hp -= add_damage
		RAID_REPORT.add(self, source_id, "add_damage", add_damage)
		remaining_damage -= add_damage
		mechanic_damage += add_damage
		raid_damage_dealt += add_damage
		if raid_add_hp <= 0:
			_presentation_event("shield_break")
			raid_add_count = 0
			raid_add_waves_cleared += 1
			_vulnerable_seconds = maxf(_vulnerable_seconds, 2.5)
			raid_event_text = "수정핵 파괴! · 2.5초 약점 노출"
			if combat_effects_enabled and is_instance_valid(raid_boss_sprite):
				combat_fx.death_burst(raid_boss_position - Vector2(36, 40), Color("#f0a15c"), true)
				combat_fx.death_burst(raid_boss_position + Vector2(36, -40), Color("#f0a15c"), true)
		if remaining_damage <= 0:
			_spawn_floating_combat_text(("치명! " if critical else "")+"-%d"%mechanic_damage,GOLD,raid_boss_position)
			return mechanic_damage
	# Gray Meadow: guard HP must be removed before boss HP. Overflow is allowed,
	# but the vulnerability begins after the breaking hit rather than amplifying it.
	var vulnerable_before_break: bool = _vulnerable_seconds > 0.0
	if raid_guard_hp > 0 and remaining_damage > 0:
		var guard_damage: int = mini(raid_guard_hp, remaining_damage)
		raid_guard_hp -= guard_damage
		RAID_REPORT.add(self, source_id, "guard_damage", guard_damage)
		remaining_damage -= guard_damage
		mechanic_damage += guard_damage
		raid_damage_dealt += guard_damage
		if raid_guard_hp <= 0:
			_presentation_event("shield_break")
			raid_guard_breaks += 1
			var mechanic: Dictionary = _raid_mechanic_profile()
			var vulnerability: float = maxf(2.0, float(mechanic.get("vulnerability", 3.0)))
			_vulnerable_seconds = maxf(_vulnerable_seconds, vulnerability)
			raid_event_text = "대지 갑주 파괴! · %.1f초 약점 노출" % vulnerability
			if combat_effects_enabled and is_instance_valid(raid_boss_sprite):
				combat_fx.impact(raid_boss_position - Vector2(0, 58), Color("#e8ba6b"), 60.0)
				combat_fx.camera_impact(4.8, 0.18, 0.012)
		if remaining_damage <= 0:
			_spawn_floating_combat_text(("치명! " if critical else "")+"-%d"%mechanic_damage,GOLD,raid_boss_position)
			return mechanic_damage
	var damage_multiplier: float = 1.25 if vulnerable_before_break else 1.0
	var actual: int = mini(raid_boss_hp, int(float(remaining_damage) * damage_multiplier))
	raid_boss_hp -= actual
	RAID_REPORT.add(self, source_id, "boss_damage", actual)
	raid_damage_dealt += actual
	var dps_passes_before: int = raid_dps_checks_passed
	_raid_record_dps_check(actual)
	if critical and mechanic_damage == 0 and raid_dps_checks_passed == dps_passes_before:
		raid_event_text = "수호신 공명 · 치명타 %d" % actual
	if is_instance_valid(raid_boss_sprite):
		if raid_boss_hp <= 0:
			raid_boss_sprite.play_death()
		else:
			raid_boss_sprite.play_hit()
		if combat_effects_enabled and raid_hit_fx_remaining <= 0.0:
			var accent: Color = preload("res://scripts/raid/RaidBossDesign.gd").raid(raid_encounter_zone)["accent"]
			combat_fx.hit_flash(raid_boss_sprite, Color.WHITE)
			combat_fx.impact(raid_boss_sprite.position - Vector2(0, 60), accent, 27.0)
			if actual >= maxi(30, int(raid_boss_max_hp * .018)):
				combat_fx.camera_impact(3.2, 0.11, 0.007)
			raid_hit_fx_remaining = 0.14
	_spawn_floating_combat_text(("치명! " if critical else "")+"-%d"%(actual+mechanic_damage),GOLD,raid_boss_position)
	return actual + mechanic_damage

func _advance_raid_encounter(delta: float) -> void:
	if not raid_running or active_screen != "raid" or _application_suspended or delta <= 0.0:
		return
	# Resolve wipe before pets/attacks: a dead expedition cannot claim a kill.
	if _alive_hero_ids().is_empty():
		_finish_raid("defeat")
		return
	if raid_boss_hp <= 0:
		_finish_raid("victory")
		return
	raid_elapsed = minf(RAID_TIME_LIMIT, raid_elapsed + delta)
	if raid_elapsed >= RAID_TIME_LIMIT - 0.00001:
		_finish_raid("timeout")
		return
	combat_tick_count += 1
	raid_hit_fx_remaining=maxf(0.0,raid_hit_fx_remaining-delta)
	_advance_skill_cooldowns(delta)
	raid_control_immunity = maxf(0.0, raid_control_immunity - delta)
	_raid_advance_mechanics(delta)
	if _alive_hero_ids().is_empty():
		_finish_raid("defeat")
		return
	_raid_move_actors(delta)
	for hero in deployed_heroes:
		if raid_boss_hp <= 0:
			break
		var hero_id := str(hero["id"])
		if not hero_battle_state.has(hero_id) or int(hero_battle_state[hero_id].get("hp", 0)) <= 0 or not hero_skill_runtime.has(hero_id):
			continue
		var state: Dictionary = hero_battle_state[hero_id]
		var runtime: Dictionary = hero_skill_runtime[hero_id]
		runtime["attack_remaining"] = maxf(0.0, float(runtime.get("attack_remaining", 0.0)) - delta)
		if float(runtime["attack_remaining"]) > 0.00001:
			continue
		# The squad must approach the moving boss before dealing damage.
		if raid_positions.get(hero_id, RAID_FIELD.hero_entry(0)).distance_to(raid_boss_position) > 335.0:
			continue
		runtime["attack_remaining"] = (0.78 + float(int(state.get("slot", 0)) % 3) * 0.08) * float(state.get("attack_interval_mult", 1.0))
		var raw_damage := 0
		var painted_action: String='basic'
		var action: String = HERO_KITS.preferred_slot(self, hero_id) if _skill_spacing <= 0.0 else "basic"
		var control_ultimate := preload("res://scripts/heroes/HeroCombatRules.gd").ultimate_role(hero_id, str(state.get("role_group", ""))) == "컨트롤러" and preload("res://scripts/heroes/HeroCombatRules.gd").ultimate_status(hero_id) == "stun"
		if action == "ultimate" and (not control_ultimate or _raid_control_window()):
			painted_action='ultimate'
			raw_damage = _cast_raid_ultimate(hero_id)
			_skill_spacing = maxf(_skill_spacing, 0.16)
		elif action == "a1" and (str(runtime["profile"].get("kind", "")) != "stun" or _raid_control_window()):
			painted_action='a1'
			raw_damage = _cast_hero_skill(hero_id)
			_skill_spacing = 0.14
		elif action == "a2":
			painted_action='a2'
			raw_damage = HERO_KITS.cast(self, hero_id, "a2")
			_skill_spacing = 0.14
		else:
			raw_damage = int(state.get("attack", 20))
			raw_damage += HERO_KITS.event(self, hero_id, "basic")
			_gain_ultimate(hero_id, 10.0)
		_apply_raid_damage(raw_damage, hero_id)
		if has_method('_raid_play_hero_action'):
			call('_raid_play_hero_action',hero_id,painted_action)
	if raid_boss_hp > 0:
		_apply_raid_damage(_advance_raid_pet(delta), "$support")
	if raid_boss_hp <= 0:
		_finish_raid("victory")
		return
	var ratio := float(raid_boss_hp) / maxf(1.0, float(raid_boss_max_hp))
	var next_phase := 3 if ratio <= 0.30 else (2 if ratio <= 0.60 else 1)
	if next_phase > raid_phase:
		raid_phase = next_phase
		raid_pattern_sequence = 0
		raid_boss_attack_remaining = maxf(raid_boss_attack_remaining,1.05)
		var mechanic_kind: String = str(_raid_mechanic_profile(raid_encounter_zone, raid_phase).get("kind", "none"))
		_raid_activate_phase_mechanic(raid_phase)
		if mechanic_kind == "none":
			raid_event_text = "페이즈 %d · %s" % [raid_phase,_raid_phase_hint()]
		else:
			raid_event_text = "페이즈 %d · %s · %s" % [raid_phase, _raid_phase_hint(), raid_event_text]
	if not raid_enraged and raid_elapsed >= RAID_ENRAGE_TIME:
		raid_enraged = true
		raid_event_text = "광폭화! 공격력·속도 상승 · 남은 시간 60초"
	if raid_second_wave_remaining>0.0:
		raid_second_wave_remaining=maxf(0.0,raid_second_wave_remaining-delta)
		if raid_second_wave_remaining<=0.00001:_apply_raid_second_wave()
	var profile := _boss_pattern_profile(raid_encounter_zone)
	if boss_telegraph_pending:
		if _stun_seconds <= 0.0:
			boss_telegraph_remaining = maxf(0.0, boss_telegraph_remaining - delta)
		if boss_telegraph_remaining <= 0.00001 and _stun_seconds <= 0.0:
			boss_telegraph_pending = false
			raid_break_gauge = 0.0
			raid_event_text = "%s 발동! %s" % [boss_telegraph_skill, _apply_boss_pattern(raid_cast_profile if not raid_cast_profile.is_empty() else profile)]
			raid_cast_profile.clear()
			raid_pattern_shape.clear()
			raid_boss_attack_remaining = _raid_attack_interval()
	elif _stun_seconds <= 0.0:
		raid_boss_attack_remaining = maxf(0.0, raid_boss_attack_remaining - delta)
		if raid_boss_attack_remaining <= 0.00001:
			raid_boss_turns += 1
			if raid_boss_turns % maxi(2, int(profile.get("interval", 6)) - (raid_phase - 1)) == 0:
				var cast_profile := _boss_cast_profile(raid_encounter_zone)
				raid_pattern_sequence += 1
				boss_telegraph_pending = true
				raid_break_gauge = 0.0
				raid_cast_profile=cast_profile.duplicate(true)
				raid_pattern_shape=_raid_create_pattern_shape(str(cast_profile.get("kind", "aoe")),cast_profile)
				boss_telegraph_remaining = float(cast_profile.get("telegraph", 1.2))
				boss_telegraph_skill = str(cast_profile.get("name", "보스 광역기"))
				_emit_boss_telegraph(boss_telegraph_skill, boss_telegraph_remaining)
			else:
				raid_boss_attack_remaining = _raid_attack_interval()
				var target_id := _select_raid_hero_target()
				if not target_id.is_empty():
					if is_instance_valid(raid_boss_sprite):raid_boss_sprite.play_attack('left')
					if raid_positions.get(target_id, RAID_FIELD.hero_entry(0)).distance_to(raid_boss_position) <= 195.0:
						_incoming_damage_to_hero(target_id, int(raid_boss_attack * _raid_attack_multiplier()))
	if _alive_hero_ids().is_empty():
		_finish_raid("defeat")
	elif raid_boss_hp <= 0:
		_finish_raid("victory")

func _update_raid_hud(damage: int = 0) -> void:
	var report_button = combat_labels.get("raid_report")
	if is_instance_valid(report_button): report_button.disabled = raid_running
	_sync_party_hp_from_heroes()
	var alive := _alive_hero_ids()
	var enemy: Label = combat_labels.get("raid_enemy")
	if is_instance_valid(enemy):
		enemy.text = "%s · 페이즈 %d%s\n보스 HP %d / %d · 이번 피해 %d\n생존 %d/%d · 원정대 HP %d / %d\n남은 시간 %.1f초 · 회피 %d · 차단 %d" % [raid_boss_name, raid_phase, " · 광폭화" if raid_enraged else "", raid_boss_hp, raid_boss_max_hp, damage, alive.size(), deployed_heroes.size(), party_hp, party_max_hp, maxf(0.0, RAID_TIME_LIMIT - raid_elapsed), raid_evaded_hits, raid_interrupt_count]
	var progress: ProgressBar = combat_labels.get("raid_progress")
	if is_instance_valid(progress):
		progress.value = 100.0 * float(raid_boss_max_hp - raid_boss_hp) / maxf(1.0, float(raid_boss_max_hp))
	for hero in deployed_heroes:
		var hero_id := str(hero["id"])
		var state: Dictionary = hero_battle_state.get(hero_id, {})
		var hp: ProgressBar = combat_labels.get("raid_hero_hp_%s" % hero_id)
		if is_instance_valid(hp):
			hp.value = 100.0 * float(state.get("hp", 0)) / maxf(1.0, float(state.get("max_hp", 1)))
		var label: Label = combat_labels.get("raid_hero_%s" % hero_id)
		if is_instance_valid(label):
			var action := "전투불능" if int(state.get("hp", 0)) <= 0 else ("궁극기 준비" if _ultimate_ready(hero_id) else ("수호 중" if float(state.get("guard", 0.0)) > 0.0 else str(state.get("role_group", ""))))
			label.text = "%s · %s" % [_hero_short_name(hero_id), action]
			label.add_theme_color_override("font_color", RED if int(state.get("hp", 0)) <= 0 else TEXT)
	var mechanic_status: Dictionary = _raid_mechanic_status()
	var mechanic_bar: ProgressBar = combat_labels.get("raid_mechanic_progress")
	if is_instance_valid(mechanic_bar):
		mechanic_bar.visible = bool(mechanic_status.get("active", false))
		mechanic_bar.value = clampf(float(mechanic_status.get("value", 0.0)), 0.0, 100.0)
	var mechanic_label: Label = combat_labels.get("raid_mechanic_label")
	if is_instance_valid(mechanic_label):
		mechanic_label.visible = bool(mechanic_status.get("active", false))
		mechanic_label.text = str(mechanic_status.get("label", ""))
	var status: Label = combat_labels.get("raid_status")
	if is_instance_valid(status) and raid_running:
		if boss_telegraph_pending:
			status.text = "⚠ %s · %.1f초 후 발동\n%s · 차단 %d%%" % [boss_telegraph_skill, boss_telegraph_remaining, "위험 구역에서 이동·회피하세요" if raid_control_immunity > 0.0 else "이동·회피 또는 제어 스킬", roundi(100.0 * raid_break_gauge / maxf(1.0, raid_break_gauge_max))]
			status.add_theme_color_override("font_color", Color("#ff8f70"))
		else:
			var mechanic_line: String = str(mechanic_status.get("label", ""))
			status.text = "%s\n%s%s" % [skill_event_text if not skill_event_text.is_empty() else "영웅별 스킬·궁극기 자동 전투", raid_event_text, "\n" + mechanic_line if not mechanic_line.is_empty() else ""]
			status.add_theme_color_override("font_color", GREEN)

func _finish_raid(outcome: String) -> void:
	if not raid_running or raid_reward_settled:
		return
	if outcome == "victory" and (raid_boss_hp > 0 or _alive_hero_ids().is_empty()):
		return
	RAID_REPORT.finish(self, outcome)
	# Mark settled before applying any reward or rendering results.
	raid_running = false
	raid_reward_settled = true
	raid_outcome = outcome
	boss_telegraph_pending = false
	boss_telegraph_remaining = 0.0
	raid_pattern_shape.clear()
	raid_second_wave_shape.clear()
	if is_instance_valid(combat_timer):
		combat_timer.stop()
	var start: Button = combat_labels.get("raid_start")
	if is_instance_valid(start):
		start.disabled = deployed_heroes.is_empty()
		start.text = "다시 도전"
	var zone: Dictionary = _zone_data().get(raid_encounter_zone, _current_zone())
	var status: Label = combat_labels.get("raid_status")
	if outcome == "victory":
		var reward_gold := _guardian_reward(500 * int(zone["difficulty"]),"online_gold")
		var reward_xp := _guardian_reward(250 * int(zone["difficulty"]),"online_xp")
		unclaimed_gold += reward_gold
		unclaimed_xp += reward_xp
		_grant_hero_xp(reward_xp)
		var pet_event := _grant_pet_xp(80 + int(zone["difficulty"]) * 30)
		raid_clears[raid_encounter_zone] = int(raid_clears.get(raid_encounter_zone, 0)) + 1
		_goal_record("raid_clear")
		var base_crystal_reward := 6 + 6 * int(zone["difficulty"])
		var performance_bonus := _raid_performance_crystal_bonus()
		var crystal_reward := base_crystal_reward + performance_bonus
		raid_crystals = mini(1000000000, raid_crystals + crystal_reward)
		var raid_item := _roll_raid_equipment(zone)
		var drop_results: Array[String] = ["1. " + last_drop_text]
		var items: Array = [raid_item.duplicate(true)]
		var field_item := _roll_equipment_drop(zone)
		drop_results.append("2. " + last_drop_text)
		if not field_item.is_empty():
			items.append(field_item.duplicate(true))
		var mechanic_successes := raid_guard_breaks + raid_add_waves_cleared + raid_dps_checks_passed
		raid_reward_receipt = {"encounter": raid_encounter_serial, "zone": raid_encounter_zone, "gold": reward_gold, "xp": reward_xp, "raid_crystals": crystal_reward, "base_raid_crystals": base_crystal_reward, "performance_bonus": performance_bonus, "mechanic_successes": mechanic_successes, "mechanic_failures": raid_dps_checks_failed, "items": items, "drop_results": drop_results, "elapsed": raid_elapsed}
		var clear_report := "생존 %d/%d · 패턴 차단 %d회 · 기믹 성공 %d회" % [_alive_hero_ids().size(), deployed_heroes.size(), raid_interrupt_count, mechanic_successes]
		raid_last_result = "%s 격파! · %.1f초 · %s\n골드 +%d · 경험치 +%d · 레이드 정수 +%d\n%s\n%s" % [raid_boss_name, raid_elapsed, clear_report, reward_gold, reward_xp, crystal_reward, "\n".join(drop_results), pet_event]
		_save_idle_state()
		var bonus_text := "기본 %d + 성과 보너스 %d" % [base_crystal_reward, performance_bonus]
		var reward_detail := "%s\n골드 +%d · 경험치 +%d · 레이드 정수 +%d (%s)\n%s\n%s" % [clear_report, reward_gold, reward_xp, crystal_reward, bonus_text, "\n".join(drop_results), pet_event]
		if has_method('_show_raid_victory'):
			call('_show_raid_victory',"%s 격파" % raid_boss_name,reward_detail)
		else:
			_show_battle_result_popup("RAID CLEAR", "%s 격파" % raid_boss_name, reward_detail, GREEN)
		var record: Label = combat_labels.get("raid_record")
		if is_instance_valid(record):
			record.text = "고유 스킬 · %s\n권장 전투력 · %d\n레이드 클리어 · %d회" % [zone["boss_skill"], preload("res://scripts/raid/RaidBalance.gd").stats(zone)["recommended_power"], int(raid_clears[raid_encounter_zone])]
		if is_instance_valid(status):
			status.text = "클리어! %.1f초 · 골드 +%d · 경험치 +%d\n세트 장비 확정 · 레이드 정수 +%d" % [raid_elapsed, reward_gold, reward_xp, crystal_reward]
			status.add_theme_color_override("font_color", GREEN)
	else:
		var boss_remaining := roundi(100.0 * float(maxi(0, raid_boss_hp)) / maxf(1.0, float(raid_boss_max_hp)))
		var reason := "원정대가 전멸했습니다. 전열·수호·회복 영웅을 배치하세요."
		if outcome == "timeout":
			reason = "제한시간 240초를 초과했습니다. 공격 영웅의 장비·훈련을 점검하세요."
		elif outcome == "cancelled":
			reason = "지역이 변경되어 레이드를 종료했습니다."
		raid_last_result = "%s\n보스 체력 %d%% 남음 · %.1f초 · 패턴 차단 %d회\n클리어 보상 없음" % [reason, boss_remaining, raid_elapsed, raid_interrupt_count]
		if outcome in ["defeat", "timeout"]:
			raid_last_result += "\n다음 행동 · " + str(preload("res://scripts/raid/RaidRecoveryGuide.gd").advice(self).text)
		if is_instance_valid(status):
			status.text = raid_last_result
			status.add_theme_color_override("font_color", RED)
	_update_raid_hud()

func _select_raid_hero_target(mode: String = "auto") -> String:
	var alive := _alive_hero_ids()
	if alive.is_empty(): return ""
	var taunting: Array[String] = []
	for hero_id in alive:
		if float(hero_battle_state[hero_id].get("taunt", 0.0)) > 0.0: taunting.append(hero_id)
	if not taunting.is_empty():
		alive=taunting
	elif mode=='auto':
		mode=_raid_basic_target_mode()
	elif mode=='row_cycle':
		mode='rear' if raid_boss_turns%2==0 else 'front'
	var pool: Array[String]=[]
	if mode in ['front','rear']:
		for hero_id in alive:
			var state: Dictionary=hero_battle_state[hero_id]
			var row := str(state.get('row','front'))
			if mode=='front' and (str(state.get('role_group',''))=='탱커' or row=='front'): pool.append(hero_id)
			elif mode=='rear' and row in ['rear','back','middle'] and str(state.get('role_group',''))!='탱커': pool.append(hero_id)
	if pool.is_empty(): pool=alive.duplicate()
	var best_id := pool[0]
	var best_value := INF if mode=='lowest_hp' else -INF
	for hero_id in pool:
		var state: Dictionary=hero_battle_state[hero_id]
		var ratio := float(state.get('hp',0)) / maxf(1.0,float(state.get('max_hp',1)))
		if mode=='lowest_hp':
			if ratio<best_value: best_value=ratio;best_id=hero_id
		elif ratio>best_value:
			best_value=ratio;best_id=hero_id
	return best_id

func _cycle_zone() -> void:
	var ids := ["gray_meadow", "forgotten_mine", "moonrest_forest"]
	var current_index := ids.find(current_zone_id)
	if current_index < 0:
		current_index = 0
	for step in range(1, ids.size() + 1):
		var next_index := (current_index + step) % ids.size()
		var next_id: String = ids[next_index]
		if _is_zone_unlocked(next_id) and next_id != current_zone_id:
			zone_rotation = next_index
			current_zone_id = next_id
			_save_idle_state()
			_build_combat_screen()
			return
	# Only the current region is unlocked. Surface the nearest progression goal.
	for candidate_id in ids:
		if not _is_zone_unlocked(candidate_id):
			var required := int(_zone_data()[candidate_id].get("unlock_stage", 1))
			_show_toast("다음 지역 %s · 사냥 스테이지 %d 해금" % [_zone_data()[candidate_id]["name"], required])
			return

func _update_map_tiles() -> void:
	var zone: Dictionary = _current_zone()
	var monster_cells: Dictionary = {}
	var camera_center_cell := Vector2i(3, 2)
	for enemy_index in enemy_wave.size():
		var enemy: Dictionary = enemy_wave[enemy_index]
		if int(enemy.get("hp", 0)) <= 0 or enemy_index >= roaming_hunt.enemy_positions.size():
			continue
		var relative: Vector2 = roaming_hunt.enemy_position(enemy_index) - expedition_position
		var screen_cell := camera_center_cell + Vector2i(roundi(relative.x), roundi(relative.y))
		if screen_cell.x < 0 or screen_cell.x >= 7 or screen_cell.y < 0 or screen_cell.y >= 5:
			continue
		monster_cells["%d:%d" % [screen_cell.x, screen_cell.y]] = enemy_index
	var current_target: int = roaming_hunt.current_target
	var boss_screen_cell := Vector2i(-99, -99)
	if open_map_boss_active:
		var boss_relative: Vector2 = open_map_boss_position - expedition_position
		boss_screen_cell = camera_center_cell + Vector2i(roundi(boss_relative.x), roundi(boss_relative.y))
	for index in map_tile_labels.size():
		var tile: Label = map_tile_labels[index]
		var x: int = index % 7
		var y: int = index / 7
		var cell := Vector2i(x, y)
		var key := "%d:%d" % [x, y]
		tile.text = "·"
		tile.add_theme_color_override("font_color", Color(MUTED, 0.52))
		if open_map_boss_active and cell == boss_screen_cell:
			tile.text = "☠"
			tile.add_theme_color_override("font_color", Color("#ffb84d"))
		elif cell == camera_center_cell:
			tile.text = "⚑"
			tile.add_theme_color_override("font_color", zone["color"])
		elif monster_cells.has(key):
			var enemy_index: int = int(monster_cells[key])
			tile.text = "◎" if enemy_index == current_target and roaming_hunt.aggro_active else "☠"
			tile.add_theme_color_override("font_color", GOLD if tile.text == "◎" else RED)
		elif (x + y * 3) % 11 == 0:
			tile.text = "▧"
			tile.add_theme_color_override("font_color", Color("#8eaf86"))

func _deployed_names() -> Array[String]:
	var names: Array[String] = []
	for hero in deployed_heroes:
		names.append(hero.name)
	return names

func _acquire_hunt_target() -> void:
	# v20 compatibility wrapper. Encounters are no longer bound to fixed spawn nodes.
	_ensure_roaming_wave()

func _spawn_enemy_wave(zone: Dictionary) -> void:
	_FIELD.spawn_enemy_wave(self, zone)

func _spawn_enemy_wave_sprites(start_index: int = 0) -> void:
	for index in range(start_index, enemy_wave.size()):
		var enemy: Dictionary = enemy_wave[index]
		var monster_scale := _combat_actor_scale() * 1.38
		var sprite := MonsterSpriteFactory.create_monster(str(enemy["name"]), Vector2(monster_scale, monster_scale))
		var field_pos := roaming_hunt.enemy_position(index)
		sprite.set_meta("field_position", field_pos)
		sprite.position = _map_world_position(field_pos)
		sprite.z_index = _field_actor_depth(sprite.position.y)
		_field_actor_parent().add_child(sprite)
		sprite.play_idle("left")
		enemy_wave_sprites.append(sprite)
		var hp_bar := ProgressBar.new()
		hp_bar.min_value = 0.0
		hp_bar.max_value = 100.0
		hp_bar.value = 100.0
		hp_bar.show_percentage = false
		hp_bar.size = Vector2(34, 4)
		hp_bar.position = sprite.position + _sprite_head_offset(sprite) + Vector2(-17, -7)
		hp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hp_bar.z_index = 19
		hp_bar.add_theme_stylebox_override("background", _panel_style(Color("#23151b"), Color("#23151b"), 2, 0))
		var enemy_bar_color := RED
		if bool(enemy.get("treasure", false)):
			enemy_bar_color = GOLD
			sprite.modulate = Color("#ffe7a6")
		elif bool(enemy.get("elite", false)):
			var elite_affix := str(enemy.get("elite_affix", ""))
			enemy_bar_color = Color("#ca78ff") if elite_affix == "keen" else (Color("#ff765f") if elite_affix == "frenzied" else Color("#78b7ff"))
			sprite.modulate = Color("#f4e6ff") if elite_affix == "keen" else (Color("#ffd6ce") if elite_affix == "frenzied" else Color("#dcecff"))
		hp_bar.add_theme_stylebox_override("fill", _panel_style(enemy_bar_color, enemy_bar_color, 2, 0))
		_field_actor_parent().add_child(hp_bar)
		enemy_hp_bars.append(hp_bar)
	monster_sprite = enemy_wave_sprites[0] if not enemy_wave_sprites.is_empty() else null

func _update_roaming_enemy_motion(_delta: float) -> void:
	for index in enemy_wave_sprites.size():
		var sprite: MonsterSpriteController = enemy_wave_sprites[index]
		if not is_instance_valid(sprite) or index >= enemy_wave.size():
			continue
		var enemy: Dictionary = enemy_wave[index]
		var world := roaming_hunt.enemy_position(index)
		var movement := world - Vector2(sprite.get_meta("field_position", world))
		sprite.set_meta("field_position", world)
		sprite.set_world_position(_map_world_position(world))
		sprite.visible = combat_field_rect.grow(-8.0).has_point(sprite.position)
		if int(enemy.get("hp", 0)) > 0:
			if movement.length_squared() > 0.000001 and sprite.state not in ["attack", "hit"]:
				sprite.play_walk(movement)
			elif movement.length_squared() <= 0.000001 and sprite.state == "walk":
				sprite.play_idle()
		sprite.z_index = _field_actor_depth(sprite.position.y)
		if index < enemy_hp_bars.size() and is_instance_valid(enemy_hp_bars[index]):
			var hp_bar: ProgressBar = enemy_hp_bars[index]
			hp_bar.position = sprite.position + _sprite_head_offset(sprite) + Vector2(-17, -7)
			hp_bar.visible = sprite.visible and int(enemy.get("hp", 0)) > 0
	if is_instance_valid(open_map_boss_sprite):
		open_map_boss_sprite.position = _map_world_position(open_map_boss_position)
		open_map_boss_sprite.visible = combat_field_rect.grow(-8.0).has_point(open_map_boss_sprite.position)
		open_map_boss_sprite.z_index = _field_actor_depth(open_map_boss_sprite.position.y)
	_update_combat_target_marker()

func _reset_attack_windups(preserve_healing := false) -> void:
	var index := 0
	for hero_id in hero_skill_runtime:
		var runtime: Dictionary = hero_skill_runtime[hero_id]
		if preserve_healing and int(hero_battle_state.get(hero_id, {}).get("hp", 0)) > 0 and float(runtime.get("windup", -1.0)) >= 0.0 and not _hunt_pending_healing_slot(hero_id).is_empty():
			index += 1
			continue
		runtime["windup"] = -1.0
		runtime["cast"] = false
		runtime["cast_ultimate"] = false
		runtime["cast_secondary"] = false
		runtime["target_index"] = -1
		runtime["attack_remaining"] = 0.1 + index * 0.17
		index += 1

func _on_combat_tick() -> void:
	# Compatibility hook for tools/tests. Runtime uses _physics_process only.
	for _step in 30:
		_advance_auto_hunt(1.0 / 60.0)

func _hunt_recovery_threshold() -> float:
	if party_max_hp <= 0 or deployed_heroes.is_empty():
		return 1.0
	var alive := _alive_hero_ids().size()
	var alive_ratio := float(alive) / maxf(1.0, float(deployed_heroes.size()))
	var has_living_support := false
	for hero_id in _alive_hero_ids():
		var state: Dictionary = hero_battle_state.get(hero_id, {})
		if str(state.get("role_group", "")) == "서포터":
			has_living_support = true
			break
	var threshold := 0.18
	if not has_living_support:
		threshold += 0.08
	if alive_ratio < 0.60:
		threshold += 0.08
	if hunt_ai.state == AutoHuntController.State.MOVING:
		threshold += 0.04
	for enemy in enemy_wave:
		if int(enemy.get("hp", 0)) > 0 and str(enemy.get("archetype", "")) == "assassin":
			threshold += 0.02
			break
	return clampf(threshold, 0.18, 0.42)

func _should_enter_hunt_recovery() -> bool:
	if party_max_hp <= 0:
		return true
	if _alive_hero_ids().is_empty():
		return true
	var hp_ratio := float(party_hp) / maxf(1.0, float(party_max_hp))
	return hp_ratio <= _hunt_recovery_threshold()

func _hunt_recovery_exit_ratio() -> float:
	var has_living_support := false
	for hero_id in _alive_hero_ids():
		var state: Dictionary = hero_battle_state.get(hero_id, {})
		if str(state.get("role_group", "")) == "서포터":
			has_living_support = true
			break
	return 0.82 if has_living_support else 0.92

func _alive_enemy_mask() -> Array:
	var result: Array = []
	for enemy in enemy_wave:
		result.append(int(enemy.get("hp", 0)) > 0)
	return result

func _ensure_roaming_wave() -> void:
	if challenge_session != null:
		CHALLENGE_DRIVER.ensure_wave(self)
		return
	_FIELD.admit(self)

func _advance_roaming_hunt(delta: float, support_actors: Array[String] = []) -> void:
	_FIELD.advance_roaming_hunt(self, delta, support_actors)

func _advance_auto_hunt(delta: float) -> void:
	if active_screen != "combat" and background_hunt.active():
		background_hunt.advance(self, delta)
		return
	if SAVE_SAFETY.pending(self): return
	if active_screen != "combat" or not combat_running or _application_suspended or delta <= 0.0 or not is_finite(delta):
		return
	if deployed_heroes.is_empty():
		if challenge_session != null:
			challenge_session.defeat()
			CHALLENGE_DRIVER.finish(self)
			return
		combat_running = false
		_update_hunt_hud()
		return
	var speed := clampf(battle_speed, 1.0, 2.0) if is_finite(battle_speed) else 1.0
	var remaining := minf(delta, 0.5) * speed
	while remaining > 0.000001 and active_screen == "combat" and combat_running and not _application_suspended and not SAVE_SAFETY.pending(self):
		var step := minf(remaining, 0.12)
		_advance_auto_hunt_step(step)
		remaining -= step

func _advance_auto_hunt_step(step: float) -> void:
	if preload("res://scripts/equipment/EquipmentMailService.gd").pause_hunt(self):return
	_FIELD.advance_auto_hunt_step(self, step)

func _advance_v77_hunt_variety(delta: float) -> void:
	if hunt_combo > 0:
		hunt_combo_remaining = maxf(0.0, hunt_combo_remaining - delta)
		if hunt_combo_remaining <= 0.0:
			hunt_combo = 0
	if not roaming_hunt.aggro_active:
		return
	for index in enemy_wave.size():
		var enemy: Dictionary = enemy_wave[index]
		if not bool(enemy.get("treasure", false)) or int(enemy.get("hp", 0)) <= 0 or bool(enemy.get("treasure_expired", false)):
			continue
		var remaining := maxf(0.0, float(enemy.get("treasure_remaining", 0.0)) - delta)
		enemy["treasure_remaining"] = remaining
		if remaining <= 0.0:
			enemy["treasure_expired"] = true
			hunt_treasure_expired = true
			hunt_event_text = "보물 오라 소멸 · 일반 전리품만 획득"
			if index < enemy_wave_sprites.size() and is_instance_valid(enemy_wave_sprites[index]):
				enemy_wave_sprites[index].modulate = Color("#d7d2bd")
			_spawn_floating_combat_text("보물 오라 소멸", MUTED, _combat_enemy_screen_position(index) - Vector2(82, 82))

func _v77_begin_clear_combo(difficulty: int) -> float:
	if idle_stage < 2:
		hunt_combo = 0
		hunt_combo_remaining = 0.0
		return 0.0
	hunt_combo = hunt_combo + 1 if hunt_combo > 0 and hunt_combo_remaining > 0.0 else 1
	hunt_combo_best = maxi(hunt_combo_best, hunt_combo)
	hunt_combo_remaining = HUNT_VARIETY.combo_window(difficulty)
	return HUNT_VARIETY.combo_bonus(hunt_combo)

func _v77_guaranteed_hunt_drop(zone: Dictionary, source_label: String) -> Dictionary:
	if not SAVE_SAFETY.mutation_error(self).is_empty() or preload("res://scripts/equipment/EquipmentMailService.gd").available(self)<1:return {}
	if deployed_heroes.is_empty():
		return {}
	var difficulty := clampi(int(zone.get("difficulty", 1)), 1, 3)
	var rarity := "전설" if loot_rng.randf() < 0.06 + float(difficulty) * 0.02 else "희귀"
	var slots := ["weapon", "armor", "accessory"]
	var slot: String = slots[loot_rng.randi_range(0, slots.size() - 1)]
	var role: String = GEAR.HUNT_ROLES[loot_rng.randi_range(0, GEAR.HUNT_ROLES.size() - 1)]
	var item: Dictionary = GEAR.hunt_item(zone, slot, rarity, loot_rng, role)
	item = _normalize_inventory_item(item)
	var hero_id := _best_auto_equipment_target(item, deployed_heroes) if gear_auto_equip else ""
	if not hero_id.is_empty():
		loot_inventory.append(item)
		_equip_item_direct(loot_inventory.size() - 1, hero_id)
		var old_item: Dictionary = loot_inventory.pop_back()
		var stored := _store_or_salvage_loot(old_item)
		_update_equipment_card(hero_id)
		last_drop_text = "%s · %s [%s] → %s 자동 장착 · 기존 장비 %s" % [source_label, item["name"], rarity, _hero_short_name(hero_id), stored]
	else:
		var result := _store_or_salvage_loot(item)
		last_drop_text = "%s · %s [%s] · %s" % [source_label, item["name"], rarity, result]
	return item

func _hunt_pending_healing_slot(hero_id: String) -> String:
	var runtime: Dictionary = hero_skill_runtime[hero_id]
	var slot := "ultimate" if bool(runtime.get("cast_ultimate", false)) else ("a2" if bool(runtime.get("cast_secondary", false)) else ("a1" if bool(runtime.get("cast", false)) else "basic"))
	return slot if slot != "basic" and str(HERO_KITS.auto_profile(self, hero_id, slot).get("kind", "")) == "heal" else ""

func _hunt_healing_slot(hero_id: String) -> String:
	var best := ""
	var best_score := 54
	for slot in ["ultimate", "a1", "a2"]:
		if slot=='a2' and not skill_auto:continue
		if str(HERO_KITS.auto_profile(self, hero_id, slot).get("kind", "")) != "heal":
			continue
		if slot == "a1" and not _should_use_skill(hero_id):
			continue
		if slot == "ultimate" and not _should_use_ultimate(hero_id):
			continue
		var score: int = HERO_KITS.priority(self, hero_id, slot)
		if score > best_score:
			best_score = score
			best = slot
	return best

func _advance_hunt_support(delta: float) -> Array[String]:
	# Exploration and loot collection still use the same action clock, windup,
	# resource checks and cast paths as combat. No free or instant healing.
	var handled: Array[String] = []
	for index in deployed_heroes.size():
		var hero_id := str(deployed_heroes[index]["id"])
		if not hero_skill_runtime.has(hero_id) or int(hero_battle_state.get(hero_id, {}).get("hp", 0)) <= 0:
			continue
		var runtime: Dictionary = hero_skill_runtime[hero_id]
		if float(runtime.get("windup", -1.0)) >= 0.0:
			var slot := _hunt_pending_healing_slot(hero_id)
			if slot.is_empty():
				continue
			handled.append(hero_id)
			runtime["windup"] = float(runtime["windup"]) - delta
			if float(runtime["windup"]) > 0.0:
				continue
			runtime["windup"] = -1.0
			runtime["cast"] = false
			runtime["cast_secondary"] = false
			runtime["cast_ultimate"] = false
			var useful: bool = _should_use_ultimate(hero_id) if slot == "ultimate" else (_should_use_skill(hero_id) if slot == "a1" else (skill_auto and HERO_KITS.should_use(self, hero_id, slot)))
			if not useful:
				runtime["attack_remaining"] = 0.0
				continue
			if slot == "ultimate":
				_cast_combat_ultimate(hero_id, -1)
			elif slot == "a1":
				_cast_combat_skill(hero_id, -1)
			else:
				HERO_KITS.cast(self, hero_id, slot, -1)
			runtime["attack_remaining"] = (0.78 + float(index % 3) * 0.08) * float(hero_battle_state[hero_id].get("attack_interval_mult", 1.0))
		else:
			var slot := _hunt_healing_slot(hero_id)
			if slot.is_empty():
				continue
			handled.append(hero_id)
			runtime["attack_remaining"] = maxf(0.0, float(runtime.get("attack_remaining", 0.0)) - delta)
			if float(runtime["attack_remaining"]) > 0.0 or _skill_spacing > 0.0:
				continue
			if not preload("res://scripts/hunting/HuntBodyCollision.gd").can_commit(self,true,hero_id):continue
			runtime["cast_ultimate"] = slot == "ultimate"
			runtime["cast"] = slot == "a1"
			runtime["cast_secondary"] = slot == "a2"
			runtime["target_index"] = -1
			runtime["windup"] = 0.24 if slot == "ultimate" else 0.15
			_skill_spacing = 0.22
			if index < hero_map_sprites.size() and is_instance_valid(hero_map_sprites[index]):
				hero_map_sprites[index].play_attack()
	return handled

func _advance_hunt_attacks(delta: float, support_actors: Array[String] = []) -> void:
	if delta <= 0.0 or not is_finite(delta):
		return
	if _alive_hero_ids().is_empty():
		_begin_hunt_recovery()
		return
	_sync_enemy_wave_summary()
	if enemy_hp <= 0 or _enemy_wave_alive_count() <= 0:
		_finish_hunt_target()
		return
	# Presentation coordinates never gate damage, healing, or other actors' turns.
	combat_engage_settle_remaining = maxf(0.0, combat_engage_settle_remaining - delta)
	for index in deployed_heroes.size():
		var hero_id := str(deployed_heroes[index]["id"])
		if hero_id in support_actors or not hero_skill_runtime.has(hero_id):
			continue
		var runtime: Dictionary = hero_skill_runtime[hero_id]
		if not hero_battle_state.has(hero_id) or int(hero_battle_state[hero_id].get("hp", 0)) <= 0:
			runtime["windup"] = -1.0
			runtime["cast"] = false
			runtime["cast_ultimate"] = false
			runtime["cast_secondary"] = false
			runtime["target_index"] = -1
			continue
		var windup := float(runtime["windup"])
		if windup >= 0.0:
			runtime["windup"] = windup - delta
			if float(runtime["windup"]) <= 0.0:
				runtime["windup"] = -1.0
				var use_ultimate := bool(runtime.get("cast_ultimate", false))
				var use_skill := bool(runtime.get("cast", false))
				var use_secondary := bool(runtime.get("cast_secondary", false))
				# Re-evaluate healing/defense after another hero may have acted.
				if use_ultimate and not _should_use_ultimate(hero_id):
					use_ultimate = false
				if use_secondary and (not skill_auto or not HERO_KITS.should_use(self, hero_id, "a2")):
					use_secondary = false
				if use_skill and not _should_use_skill(hero_id):
					use_skill = false
				var action := "ultimate" if use_ultimate else ("a2" if use_secondary else ("a1" if use_skill else "basic"))
				var target_index: int = preload("res://scripts/hunting/HuntAttackDirector.gd").committed_target(self, hero_id, action, str(runtime.get("prepared_action", action))) if challenge_session == null else HERO_KITS.select_target(self, hero_id, action)
				runtime["target_index"] = target_index
				runtime["cast"] = false
				runtime["cast_ultimate"] = false
				runtime["cast_secondary"] = false
				if _combat_action_needs_enemy(hero_id, use_skill, use_ultimate, use_secondary) and target_index < 0:
					# Out of range is an actor waiting for movement, not a finished wave.
					runtime["attack_remaining"] = 0.0
					continue
				_notify_hunt_frame_release(index, true, "ultimate" if use_ultimate else ("skill" if use_skill or use_secondary else "attack_1"), float(runtime.get("attack_windup_duration", .15)))
				if use_ultimate:
					_cast_combat_ultimate(hero_id, target_index)
				elif use_secondary:
					HERO_KITS.cast(self, hero_id, "a2", target_index)
				elif use_skill:
					_cast_combat_skill(hero_id, target_index)
				else:
					var state: Dictionary = hero_battle_state[hero_id]
					_emit_basic_attack_fx(hero_id, target_index)
					var snapshot: Dictionary = enemy_wave[target_index].duplicate(true) if target_index >= 0 else {}
					_damage_enemy(target_index, int(state.get("attack", 20)), index)
					HERO_KITS.event(self, hero_id, "basic", target_index, snapshot)
					_gain_ultimate(hero_id, 11.0)
				var state_after: Dictionary = hero_battle_state[hero_id]
				runtime["attack_remaining"] = (0.78 + float(index % 3) * 0.08) * float(state_after.get("attack_interval_mult", 1.0))
				if _enemy_wave_alive_count() <= 0:
					_finish_hunt_target()
					return
		else:
			runtime["attack_remaining"] = maxf(0.0, float(runtime["attack_remaining"]) - delta)
			if float(runtime["attack_remaining"]) <= 0.0:
				if not preload("res://scripts/hunting/HuntBodyCollision.gd").can_commit(self,true,hero_id):continue
				var action: String = HERO_KITS.preferred_slot(self, hero_id) if _skill_spacing <= 0.0 else "basic"
				var use_ultimate := action == "ultimate"
				var use_skill := action == "a1"
				var use_secondary := action == "a2"
				var target_index: int = HERO_KITS.select_target(self, hero_id, action)
				runtime["target_index"] = target_index
				var needs_enemy := _combat_action_needs_enemy(hero_id, use_skill, use_ultimate, use_secondary)
				if needs_enemy and target_index < 0:
					continue
				runtime["cast_ultimate"] = use_ultimate
				runtime["cast"] = use_skill
				runtime["cast_secondary"] = use_secondary
				runtime["windup"] = 0.24 if use_ultimate else 0.15
				runtime["prepared_action"] = action
				runtime["attack_windup_duration"] = runtime["windup"]
				if use_skill or use_ultimate or use_secondary:
					_skill_spacing = 0.22
				if index < hero_map_sprites.size() and is_instance_valid(hero_map_sprites[index]):
					var hero_sprite: HeroSpriteController = hero_map_sprites[index]
					hero_sprite.visual_attack_duration = float(runtime["windup"]) / .44
					hero_sprite.visual_state_time = 0.0
					hero_sprite.set_direction_from_vector(roaming_hunt.enemy_position(target_index) - _hero_field_position(hero_id) if target_index >= 0 else Vector2.RIGHT)
					hero_sprite.play_attack()
	# Each surviving monster attacks independently. Tank/taunt priority creates an actual front line.
	for enemy_index in enemy_wave.size():
		var enemy: Dictionary = enemy_wave[enemy_index]
		if int(enemy.get("hp", 0)) <= 0:
			continue
		if bool(enemy.get("elite", false)) and not bool(enemy.get("rage_triggered", false)):
			var elite_ratio := float(enemy.get("hp", 0)) / maxf(1.0, float(enemy.get("max_hp", 1)))
			if elite_ratio <= 0.40:
				enemy["rage_triggered"] = true
				enemy["attack"] = maxi(1, int(float(enemy.get("attack", 1)) * 1.16))
				enemy["attack_speed_mult"] = 0.76
				enemy["attack_remaining"] = minf(float(enemy.get("attack_remaining", 0.9)), 0.35)
				skill_event_text = "⚠ 정예 %s 광폭화 · 공격/속도 상승" % str(enemy.get("name", "몬스터"))
		if challenge_session != null and preload("res://scripts/combat/ChallengePatternRuntime.gd").tick_enemy(self, enemy_index, delta):
			continue
		var enemy_archetype := str(enemy.get("archetype", ""))
		if active_screen == "combat" and roaming_hunt.is_returning(enemy_index):
			continue
		var attack_target := ""
		if challenge_session == null:
			var intent: Dictionary = preload("res://scripts/hunting/HuntAttackDirector.gd").advance_enemy(self, enemy_index, delta)
			if not bool(intent.get("ready", false)): continue
			attack_target = str(intent.get("target", ""))
			_notify_hunt_frame_release(enemy_index, false, "attack_1", .22)
		else:
			attack_target = _select_hero_target_for_enemy(enemy_index, true)
			if attack_target.is_empty() and enemy_archetype != "support": continue
			enemy["attack_remaining"] = maxf(0.0, float(enemy.get("attack_remaining", 0.9)) - delta)
		if float(enemy["attack_remaining"]) <= 0.0:
			if float(enemy.get("stun_seconds", 0.0)) > 0.0:
				continue
			# Existing attack_speed_mult is actually an INTERVAL multiplier.
			# Weekly attack rate is separate so +20% is /1.2, not a slowdown;
			# it also survives the existing rage/return interval reset.
			enemy["attack_remaining"] = (0.92 + float(enemy_index % 3) * 0.12) * float(enemy.get("attack_speed_mult", 1.0)) / maxf(0.1, float(enemy.get("challenge_attack_rate", 1.0)))
			if enemy_archetype == "support":
				var heal_target := -1
				var lowest_ratio := 1.0
				for ally_index in enemy_wave.size():
					var ally: Dictionary = enemy_wave[ally_index]
					if int(ally.get("hp", 0)) <= 0:
						continue
					if active_screen == "combat" and roaming_hunt.enemy_positions.size() == enemy_wave.size():
						if roaming_hunt.is_returning(ally_index) or roaming_hunt.enemy_position(enemy_index).distance_to(roaming_hunt.enemy_position(ally_index)) > float(enemy.get("healing_range", 1.6)):
							continue
					var ratio := float(ally["hp"]) / maxf(1.0, float(ally["max_hp"]))
					if ratio < lowest_ratio:
						lowest_ratio = ratio
						heal_target = ally_index
				if heal_target >= 0:
					_heal_enemy(heal_target, maxi(3, int(enemy.get("attack", 1)) * 2))
				else:
					# An uninjured pack's healer contributes pressure instead of healing full HP.
					var target_id := attack_target
					if not target_id.is_empty():
						_incoming_damage_to_hero(target_id, maxi(1, int(float(enemy.get("attack", 1)) * 0.65)), enemy_index)
			else:
				var target_id := attack_target
				if target_id.is_empty():
					_begin_hunt_recovery()
					return
				var received := _incoming_damage_to_hero(target_id, int(enemy.get("attack", 1)), enemy_index)
				if challenge_session != null and enemy_index < enemy_wave_sprites.size() and is_instance_valid(enemy_wave_sprites[enemy_index]):
					enemy_wave_sprites[enemy_index].set_direction_from_vector(_hero_field_position(target_id) - roaming_hunt.enemy_position(enemy_index))
					enemy_wave_sprites[enemy_index].play_attack()
				if received > 0 and _alive_hero_ids().is_empty():
					_begin_hunt_recovery()
					return
	if _alive_hero_ids().is_empty():
		_begin_hunt_recovery()
		return
	_advance_combat_pet(delta)
	if _enemy_wave_alive_count() <= 0:
		_finish_hunt_target()
		return
	_sync_party_hp_from_heroes()
	combat_progress = 100.0 * (1.0 - float(enemy_hp) / maxf(1.0, float(enemy_max_hp)))

func _begin_hunt_recovery() -> void:
	if challenge_session != null:
		# Dungeon defeat must not silently revive the party as idle hunting does.
		if _alive_hero_ids().is_empty():
			challenge_session.defeat()
		return
	if hunt_combo > 0:
		hunt_event_text = "연속 격파 종료 · 원정대 재정비"
	hunt_combo = 0
	hunt_combo_remaining = 0.0
	_recovery_start_hp = maxi(0, party_hp)
	hunt_ai.retreat_target()
	hunt_ai.set_state(AutoHuntController.State.RECOVERING)
	_reset_attack_windups()
	_guard_seconds = 0.0
	_weaken_seconds = 0.0
	_vulnerable_seconds = 0.0
	_stun_seconds = 0.0
	for hero_id in hero_battle_state.keys():
		var state: Dictionary = hero_battle_state[hero_id]
		state["guard"] = 0.0
		state["taunt"] = 0.0
		state["recovery_heal_carry"] = 0.0
	for sprite in hero_map_sprites:
		if is_instance_valid(sprite):
			sprite.play_idle()
	roaming_hunt.aggro_active = false
	roaming_hunt.mode = RoamingHuntDirector.Mode.RECOVER
	for sprite in enemy_wave_sprites:
		if is_instance_valid(sprite):
			sprite.play_idle()
	skill_event_text = "원정대 재정비 · 위험도에 따라 안전 체력까지 회복한 뒤 다시 방어합니다."

func _hero_roaming_destination(index: int) -> Vector2:
	if index < 0 or index >= deployed_heroes.size():
		return _map_world_position(expedition_position)
	return _map_world_position(_hero_field_position(str(deployed_heroes[index].get("id", ""))))

func _update_map_hero_motion(_delta: float) -> void:
	for index in hero_map_sprites.size():
		var sprite: HeroSpriteController = hero_map_sprites[index]
		if not is_instance_valid(sprite) or index >= deployed_heroes.size():
			continue
		var hero_id := str(deployed_heroes[index]["id"])
		var state: Dictionary = hero_battle_state.get(hero_id, {})
		var alive := int(state.get("hp", 0)) > 0
		var runtime: Dictionary = hero_skill_runtime.get(hero_id, {})
		var movement: Vector2 = party_movement.velocities.get(hero_id, Vector2.ZERO)
		sprite.position = _hero_roaming_destination(index)
		sprite.visible = combat_field_rect.grow(-8.0).has_point(sprite.position)
		if hero_hp_bars.has(hero_id) and is_instance_valid(hero_hp_bars[hero_id]):
			var hp_bar: ProgressBar = hero_hp_bars[hero_id]
			hp_bar.position = sprite.position + _sprite_foot_offset(sprite) + Vector2(-16, 3)
			hp_bar.visible = sprite.visible and alive
			hp_bar.value = 100.0 * float(state.get("hp", 0)) / maxf(1.0, float(state.get("max_hp", 1)))
		if not alive:
			if sprite.state != "death":
				sprite.play_death()
		elif hunt_ai.state in [AutoHuntController.State.RECOVERING, AutoHuntController.State.LOOTING]:
			sprite.play_idle()
		elif float(runtime.get("windup", -1.0)) >= 0.0:
			var target := int(runtime.get("target_index", -1))
			if target >= 0:
				sprite.set_direction_from_vector(roaming_hunt.enemy_position(target) - _hero_field_position(hero_id))
		elif movement.length_squared() > 0.0064 and sprite.state not in ["attack", "hit"]:
			sprite.play_walk(movement)
		elif sprite.state == "walk":
			sprite.play_idle()
		sprite.z_index = _field_actor_depth(sprite.position.y)

func _hunt_state_text() -> String:
	if challenge_session != null:
		return challenge_session.status_text() + (" · 정지" if not combat_running else "")
	if not combat_running:
		return "영웅을 편성해 주세요" if deployed_heroes.is_empty() else "일시정지"
	if hunt_ai.state == AutoHuntController.State.RECOVERING:
		return "안전 재정비"
	if hunt_ai.state == AutoHuntController.State.LOOTING:
		return "처치 · 전리품 회수"
	if roaming_hunt.aggro_active:
		return "교전 중" if roaming_hunt.mode == RoamingHuntDirector.Mode.ENGAGED else "적 부대 접근"
	return "진형 유지 · 다음 부대 대기"

func _update_hunt_hud() -> void:
	if active_screen != "combat":
		return
	_sync_party_hp_from_heroes()
	_sync_enemy_wave_summary()
	var state_text := _hunt_state_text()
	var alive_heroes := _alive_hero_ids().size()
	var alive_enemies := _enemy_wave_alive_count()
	var status: Label = combat_labels.get("status")
	if is_instance_valid(status):
		status.text = "%s · 생존 %d/%d · 원정대 HP %d / %d" % [state_text, alive_heroes, deployed_heroes.size(), party_hp, party_max_hp]
		status.add_theme_color_override("font_color", GOLD if hunt_ai.state == AutoHuntController.State.FIGHTING else GREEN)
	var state_chip: Label = combat_labels.get("combat_state_chip")
	if is_instance_valid(state_chip):
		state_chip.text = "%s · 격파 %d회" % [state_text, combat_kills]
	var party_chip: Label = combat_labels.get("combat_party_chip")
	if is_instance_valid(party_chip):
		var hp_percent := int(round(100.0 * float(party_hp) / maxf(1.0,float(party_max_hp))))
		party_chip.text = "%d/%d명 · HP %d%%" % [alive_heroes,deployed_heroes.size(),hp_percent]
	var enemy_chip: Label = combat_labels.get("combat_enemy_chip")
	if is_instance_valid(enemy_chip):
		enemy_chip.text = "%s · %d기" % [enemy_name if roaming_hunt.aggro_active and alive_enemies > 0 else "탐색 중",alive_enemies]
	var stage_chip: Label = combat_labels.get("combat_stage_chip")
	if is_instance_valid(stage_chip):
		stage_chip.text = "%d-1 · %d/%d" % [idle_stage,idle_stage_kills,idle_stage_target]
	var field_state: Label = combat_labels.get("field_state_chip")
	if is_instance_valid(field_state):
		var combo_text := " · COMBO x%d" % hunt_combo if hunt_combo >= 2 else ""
		field_state.text = "%s · 격파 %d%s" % [state_text, combat_kills, combo_text]
		field_state.add_theme_color_override("font_color", GOLD if hunt_ai.state == AutoHuntController.State.FIGHTING or hunt_combo >= 2 else GREEN)
	var field_party: Label = combat_labels.get("field_party_chip")
	if is_instance_valid(field_party):
		var field_hp_percent := int(round(100.0 * float(party_hp) / maxf(1.0, float(party_max_hp))))
		field_party.text = "%d/%d명 · HP %d%%" % [alive_heroes, deployed_heroes.size(), field_hp_percent]
	var field_enemy: Label = combat_labels.get("field_enemy_chip")
	if is_instance_valid(field_enemy):
		var enemy_percent := int(round(100.0 * float(enemy_hp) / maxf(1.0, float(enemy_max_hp)))) if alive_enemies > 0 else 0
		var treasure_time := -1.0
		for hunt_enemy in enemy_wave:
			if bool(hunt_enemy.get("treasure", false)) and int(hunt_enemy.get("hp", 0)) > 0 and not bool(hunt_enemy.get("treasure_expired", false)):
				treasure_time = float(hunt_enemy.get("treasure_remaining", 0.0))
				break
		field_enemy.text = ("보물 %.1fs · %d기 · HP %d%%" % [treasure_time, alive_enemies, enemy_percent]) if treasure_time >= 0.0 else ("%s · %d기 · HP %d%%" % [enemy_name, alive_enemies, enemy_percent] if roaming_hunt.aggro_active and alive_enemies > 0 else "탐색 중")
		field_enemy.add_theme_color_override("font_color", GOLD if treasure_time >= 0.0 else (RED if roaming_hunt.aggro_active and alive_enemies > 0 else MUTED))
	var field_stage: Label = combat_labels.get("field_stage_chip")
	if is_instance_valid(field_stage):
		var boss_remaining := 0 if open_map_boss_active else 5 - (combat_kills % 5)
		field_stage.text = "%d-1 · %d/%d · %s" % [idle_stage, idle_stage_kills, idle_stage_target, "BOSS 출현" if open_map_boss_active else "BOSS %d" % boss_remaining]
	var map_title: Label = combat_labels.get("map_title")
	if is_instance_valid(map_title):
		map_title.text = "%s · %s" % [_current_zone()["name"], state_text]
	var enemy: Label = combat_labels.get("enemy")
	if is_instance_valid(enemy):
		enemy.text = "현재 조우 · 적 %d기 생존\n%s\n적 HP 합계 %d / %d\n원정대 생존 %d/%d · HP %d / %d" % [alive_enemies, enemy_name, enemy_hp, enemy_max_hp, alive_heroes, deployed_heroes.size(), party_hp, party_max_hp]
	var progress: ProgressBar = combat_labels.get("progress")
	if is_instance_valid(progress):
		progress.value = 100.0 * float(party_hp) / maxf(1.0, float(party_max_hp)) if hunt_ai.state == AutoHuntController.State.RECOVERING else combat_progress
	var hunt_info: Label = combat_labels.get("hunt_info")
	if is_instance_valid(hunt_info):
		var variety_label := str(hunt_variety_profile.get("label", "평온한 순찰"))
		var combo_label := "COMBO x%d · %.0fs" % [hunt_combo, hunt_combo_remaining] if hunt_combo >= 2 else "콤보 대기"
		hunt_info.text = "조우격파 %d회 · 필드 적 %d기 · 실제 이동 %.1f칸\n%s · %s · %s" % [
			combat_kills, alive_enemies, roaming_hunt.distance_walked,
			variety_label, combo_label, _party_composition_summary()
		]
	_update_skill_label()
	_update_combat_tactical_strip()
	_update_combat_target_marker()
	_update_combat_danger_banner()

func _finish_hunt_target() -> void:
	_FIELD.finish_hunt_target(self)

func _on_hunt_reward(_gold: int, _xp: int, _drops: Array[Dictionary], _stage_cleared: bool, _chest_gold := 0, _chest_xp := 0) -> void:
	pass

func _compact_hud_amount(amount: int) -> String:
	if amount >= 1000000000000:
		return "%.1f조" % (float(amount) / 1000000000000.0)
	if amount >= 100000000:
		return "%.1f억" % (float(amount) / 100000000.0)
	if amount >= 10000:
		return "%.1f만" % (float(amount) / 10000.0)
	return str(amount)

func _update_reward_labels() -> void:
	var pending: Label = combat_labels.get("pending")
	if pending != null:
		pending.text = "누적 보상\n골드  %d\n경험치  %d\n장비  %d개\n상자  %s" % [unclaimed_gold, unclaimed_xp, loot_inventory.size(), "획득 가능" if idle_chest_gold > 0 else "진행 중"]
	var gold: Label = combat_labels.get("gold")
	if gold != null:
		gold.text = "골드  %s" % _compact_hud_amount(wallet_gold) if active_screen == "combat" else "골드  %d" % wallet_gold
		gold.tooltip_text = "골드 %d" % wallet_gold
	var gems: Label = combat_labels.get("gems")
	if is_instance_valid(gems):
		gems.text = "보석 %s" % _compact_hud_amount(wallet_gems)
		gems.tooltip_text = "보석 %d" % wallet_gems
	var xp: Label = combat_labels.get("xp")
	if xp != null:
		xp.text = "경험치  %d" % wallet_xp
	var auto_badge: Label = combat_labels.get("auto_badge")
	if auto_badge != null:
		auto_badge.text = "● AUTO  ON" if combat_running else "Ⅱ AUTO  OFF"
		auto_badge.add_theme_color_override("font_color", GREEN if combat_running else MUTED)
	_update_hunt_hud()
	_update_hero_progress_label()

func _update_hero_progress_label() -> void:
	var label: Label = combat_labels.get("growth")
	if label == null:
		return
	var synergy := _calculate_party_synergy()
	if deployed_heroes.size() <= 4:
		var rows: Array[String] = []
		for hero in deployed_heroes:
			var progress: Dictionary = _get_hero_progress(str(hero["id"]))
			var level := int(progress["level"])
			var xp := int(progress["xp"])
			rows.append("%s Lv.%d · XP %d/%d · 장비 %d" % [str(hero["name"]).get_slice(" ", 0), level, xp, _hero_xp_to_next(level), _equipment_power(str(hero["id"]))])
		label.text = "영웅 성장  ·  전투력 %d\n%s" % [party_power, "   |   ".join(rows)]
	else:
		var level_total := 0
		var equipment_total := 0
		for hero in deployed_heroes:
			level_total += int(_get_hero_progress(str(hero["id"]))["level"])
			equipment_total += _equipment_power(str(hero["id"]))
		var average_level := float(level_total) / float(maxi(1, deployed_heroes.size()))
		label.text = "원정대 성장  ·  %d인 · 평균 Lv.%.1f · 전투력 %d · 장비력 %d\n%s" % [deployed_heroes.size(), average_level, party_power, equipment_total, str(synergy.get("summary", "시너지 없음"))]
	var pet := _get_pet_progress()
	label.text += "\n수호신 %s Lv.%d · %s · XP %d/%d" % [str(_pet_profile().get("name", "없음")), int(pet.get("level", 1)), _pet_evolution_name(int(pet.get("evolution", 0))), int(pet.get("xp", 0)), _pet_xp_to_next(int(pet.get("level", 1)))]
	if not hero_level_event.is_empty():
		label.text += "\n" + hero_level_event

func _update_stage_label() -> void:
	var stage: Label = combat_labels.get("stage")
	if is_instance_valid(stage):
		stage.text = "사냥 스테이지 %d-1\n무리 격파 %d / %d\n추적 · %s" % [idle_stage, idle_stage_kills, idle_stage_target, _tracked_quest_text()]
	var header: Label = combat_labels.get("header_stage")
	if is_instance_valid(header):
		header.text = "%s  ·  %d 스테이지" % [_current_zone()["name"], idle_stage]
	var progress: Label = combat_labels.get("header_progress")
	if is_instance_valid(progress):
		progress.text = "무리 격파  %d / %d" % [idle_stage_kills, idle_stage_target]

func _format_idle_time(seconds: int) -> String:
	var hours := seconds / 3600
	var minutes := (seconds % 3600) / 60
	return "%d시간 %d분" % [hours, minutes]

func _maybe_show_offline_reward_popup() -> void:
	if not _offline_notice_pending or active_screen != "combat" or challenge_session != null or _application_suspended or bool(get_meta("practice_active", false)):
		return
	if not is_instance_valid(content_root): return
	if content_root.has_node("OfflineRewardPopup"):
		_offline_notice_pending = false
		return
	_show_offline_reward_popup()

func _show_offline_reward_popup() -> void:
	if not is_instance_valid(content_root): return
	RewardDialogs.offline(self)
	_offline_notice_pending = false

func _claim_rewards() -> void:
	_REWARD_CLAIMS.claim_rewards(self)

func _toggle_combat(button: Button) -> void:
	if active_screen != "combat" or deployed_heroes.is_empty():
		return
	combat_running = not combat_running
	if is_instance_valid(button):
		button.text = "자동사냥 켬" if combat_running else "자동사냥 끔"
	for sprite in hero_map_sprites:
		if is_instance_valid(sprite):
			sprite.speed_scale = 1.0 if combat_running else 0.0
	for sprite in enemy_wave_sprites:
		if is_instance_valid(sprite):
			sprite.speed_scale = 1.0 if combat_running else 0.0
			sprite.set_process(combat_running)
	if is_instance_valid(open_map_boss_sprite):
		open_map_boss_sprite.speed_scale = 1.0 if combat_running else 0.0
		open_map_boss_sprite.set_process(combat_running)
	_update_reward_labels()
	_save_idle_state()




func _week_key() -> String:
	return str(int((Time.get_unix_time_from_system() + 9 * 3600 - 4 * 86400) / 604800.0))

func _reset_weekly_if_needed() -> void:
	var key := _week_key()
	if weekly_content_key.is_empty() or not weekly_content_key.is_valid_int() or int(key) > int(weekly_content_key):
		weekly_content_key = key
		weekly_trial_runs = 0
		weekly_trial_best = 0

func _weekly_entry_context() -> Dictionary:
	return CHALLENGE_DRIVER.weekly_entry_context(self)

func _weekly_entry_error() -> String:
	return CHALLENGE_DRIVER.weekly_entry_error(self)

func _run_weekly_trial(expected: Dictionary = {}) -> bool:
	return CHALLENGE_DRIVER.start_weekly(self, expected)

func _quest_status(quest_id: String) -> Dictionary:
	return _LEGACY_QUESTS.quest_status(self, quest_id)

func _auto_track_quest() -> void:
	_LEGACY_QUESTS.auto_track_quest(self)

func _tracked_quest_text() -> String:
	return GOALS.tracked_text(self)

func _legacy_tracked_quest_text() -> String:
	return _LEGACY_QUESTS.legacy_tracked_quest_text(self)

func _refresh_tutorial_state() -> void:
	_LEGACY_QUESTS.refresh_tutorial_state(self)

func _record_first_session_action(action: String) -> void:
	preload("res://scripts/app/FirstSessionGuide.gd").record(self, action)

func _follow_first_session_guide() -> void:
	preload("res://scripts/app/FirstSessionGuide.gd").follow(self)

func _tutorial_text() -> String:
	return _LEGACY_QUESTS.tutorial_text(self)

func _add_onboarding_hint() -> void:
	if tutorial_completed or not is_instance_valid(content_root):
		return
	if active_screen != "lobby" and content_root.get_node_or_null("ScreenHeader") == null:
		return
	var guide := _button("?", Vector2(44, 44))
	guide.name = "OnboardingHint"
	guide.position = Vector2(_layout_width() - 523, 31) if active_screen == "lobby" else Vector2(1181, 93)
	guide.tooltip_text = _tutorial_text()
	guide.pressed.connect(func(): UI_CHROME.guide(self))
	content_root.add_child(guide)

func _hero_base_grade_index(hero_id: String) -> int:
	return _HERO_PROGRESS.hero_base_grade_index(self, hero_id)

func _hero_ascension_rank(hero_id: String) -> int:
	return _HERO_PROGRESS.hero_ascension_rank(self, hero_id)

func _hero_grade(hero_id: String) -> String:
	return _HERO_PROGRESS.hero_grade(self, hero_id)

func _hero_grade_multiplier(hero_id: String) -> float:
	return _HERO_PROGRESS.hero_grade_multiplier(self, hero_id)

func _ascension_requirement(hero_id: String) -> Dictionary:
	return _HERO_PROGRESS.ascension_requirement(self, hero_id)

func _try_ascend_hero(hero_id: String) -> bool:
	return _HERO_PROGRESS.try_ascend_hero(self, hero_id)

func _hero_shard_count(hero_id: String) -> int:
	return _HERO_PROGRESS.hero_shard_count(self, hero_id)

func _hero_breakthrough_rank(hero_id: String) -> int:
	return _HERO_PROGRESS.hero_breakthrough_rank(self, hero_id)

func _breakthrough_cost(rank: int) -> int:
	return _HERO_PROGRESS.breakthrough_cost(self, rank)

func _try_breakthrough(hero_id: String) -> bool:
	return _HERO_PROGRESS.try_breakthrough(self, hero_id)

func _summon_once() -> Dictionary:
	return _SUMMONS.summon_once(self)

func _claim_quest(quest_id: String) -> bool:
	return _LEGACY_QUESTS.claim_quest(self, quest_id)

func _reset_daily_dungeon_if_needed() -> void:
	var today := _today_key()
	if daily_dungeon_day.is_empty() or today > daily_dungeon_day:
		daily_dungeon_day = today
		daily_dungeon_runs = 0

func _run_daily_dungeon(variant: String = "gold_rush") -> bool:
	return CHALLENGE_DRIVER.start_daily(self, variant)

func _daily_dungeon_entry_context() -> Dictionary:
	return CHALLENGE_DRIVER.entry_context(self)

func _daily_sweep_error(variant: String) -> String:
	return CHALLENGE_DRIVER.sweep_error(self, variant)

func _sweep_daily_dungeon(variant: String, expected: Dictionary) -> bool:
	return CHALLENGE_DRIVER.sweep_daily(self, variant, expected)

func _tower_entry_context() -> Dictionary:
	return CHALLENGE_DRIVER.tower_entry_context(self)

func _tower_entry_error() -> String:
	return CHALLENGE_DRIVER.tower_entry_error(self)

func _challenge_tower(expected: Dictionary = {}) -> bool:
	return CHALLENGE_DRIVER.start_tower(self, expected)

func _set_auto_salvage(rarity: String) -> void:
	if not SAVE_SAFETY.allow_mutation(self): return
	auto_salvage_min_rarity = rarity
	_show_toast("자동 분해 기준: %s 미만" % rarity)
	_save_idle_state()

func _build_meta_hub_screen() -> void:
	ContentScreens.meta(self)

func _build_summon_screen() -> void:
	ContentScreens.summon(self)

func _quest_ready_count() -> int:
	return _LEGACY_QUESTS.quest_ready_count(self)

func _add_bottom_nav(active_id: String) -> void:
	UI_CHROME.navigation(self, active_id)

func _open_hero_menu() -> void:
	if selected_faction.is_empty():
		_build_faction_screen()
	else:
		_build_hero_select_screen()

func _world_party_snapshot() -> Array:
	var result: Array = []
	var synergy := _calculate_party_synergy()
	var hp_multiplier := float(synergy.get("hp_multiplier", 1.0))
	for index in deployed_heroes.size():
		var hero: Dictionary = deployed_heroes[index]
		var hero_id := str(hero["id"])
		var role_group := str(_hero_skill_profile(hero_id).get("role_group", "딜러"))
		var progress: Dictionary = _get_hero_progress(hero_id)
		var level := int(progress.get("level", 1))
		var equipment := _equipment_power(hero_id)
		var base_hp := 360
		var defense := 6
		match role_group:
			"탱커":
				base_hp = 560
				defense = 18
			"서포터":
				base_hp = 405
				defense = 9
			"컨트롤러":
				base_hp = 390
				defense = 8
		var tree := _get_skill_tree(hero_id)
		var set_profile := _equipment_set_profile(hero_id)
		var grade_mult := _hero_grade_multiplier(hero_id)
		var identity := hero_identity_catalog.profile(hero_id)
		var max_hp := maxi(120, int((base_hp + level * 42 + equipment * 0.45) * hp_multiplier * (1.0 + float(tree.get("survival", 0)) * 0.05) * grade_mult * float(set_profile.get("hp_mult", 1.0)) * float(identity.get("hp_mult", 1.0))))
		max_hp = maxi(120, int(round(float(max_hp) * _goal_hp_multiplier(hero_id))))
		var attack := maxi(12, int((24 + level * 5 + int(equipment * 0.18)) * (1.0 + float(tree.get("offense", 0)) * 0.04) * grade_mult * float(set_profile.get("attack_mult", 1.0)) * float(identity.get("attack_mult", 1.0))))
		defense += int(tree.get("survival", 0)) + int(set_profile.get("defense_bonus", 0)) + int(identity.get("defense_bonus", 0))
		if role_group == "딜러":
			attack = int(attack * 1.18)
		elif role_group == "탱커":
			attack = int(attack * 0.84)
		var formation: Dictionary = FORMATIONS.profile(formation_id)
		max_hp = maxi(1, roundi(max_hp * float(formation.hp)))
		attack = maxi(1, roundi(attack * float(formation.attack)))
		var row_code := _formation_row_for_slot(index)
		var row_name := "전열"
		if row_code == "middle":
			row_name = "중열"
		elif row_code == "rear":
			row_name = "후열"
		var world_role := role_group
		if hero_id in ["fenris", "veyra", "ragna"]:
			world_role = "암살자"
		result.append({
			"id": hero_id,
			"name": str(hero.get("name", _hero_short_name(hero_id))),
			"role": world_role,
			"row": row_name,
			"max_hp": max_hp,
			"hp": max_hp,
			"attack": attack,
			"defense": defense,
			"ai_style": str(identity.get("ai_style","balanced")),
			"identity": str(identity.get("identity","균형 전투"))
		})
	return result

func _open_faction_war_menu() -> void:
	if selected_faction.is_empty():
		_build_faction_screen()
	elif deployed_heroes.is_empty():
		_build_hero_select_screen()
	else:
		_build_faction_war_screen()

func _build_faction_war_screen() -> void:
	_clear_screen()
	active_screen = "faction_war"
	faction_war_state.ensure_initialized(selected_faction)
	world_season_state.ensure_started(world_authority.server_now())
	world_authority.bind_season(world_season_state)
	var screen := WorldWarScreen.new()
	var war_snapshot := _world_party_snapshot()
	var war_power := _calculate_party_power()
	world_authority.register_trusted_party("local_player", selected_faction, war_snapshot, war_power)
	world_war_client_session.bind(faction_war_state, faction_march_state, faction_conflict_state, world_authority, world_server_gateway, selected_faction, "local_player", world_season_state)
	screen.setup(faction_war_state, faction_march_state, faction_conflict_state, world_season_state, world_war_client_session, selected_faction, war_power, war_snapshot)
	screen.back_requested.connect(func():
		_save_idle_state()
		_build_lobby_screen()
	)
	screen.state_changed.connect(func():
		_save_idle_state()
	)
	content_root.add_child(screen)
	_add_bottom_nav("war")

func _open_world_menu() -> void:
	if selected_faction.is_empty():
		_build_faction_screen()
	elif deployed_heroes.is_empty():
		_build_hero_select_screen()
	else:
		_build_world_map_screen()

func _build_world_map_screen() -> void:
	ContentScreens.world(self)

func _select_zone_for_hunt(zone_id: String) -> void:
	if not _is_zone_unlocked(zone_id):
		_show_toast("아직 해금되지 않은 지역입니다.")
		return
	current_zone_id = zone_id
	_save_idle_state()
	if deployed_heroes.is_empty():
		_build_hero_select_screen()
	else:
		_build_combat_screen()

func _select_zone_for_raid(zone_id: String) -> void:
	if not _is_zone_unlocked(zone_id):
		_show_toast("아직 해금되지 않은 지역입니다.")
		return
	selected_raid_id = zone_id
	_build_raid_screen()

func _build_boss_select_screen() -> void:
	ContentScreens.bosses(self)

func _is_hero_deployed(hero_id: String) -> bool:
	for hero in deployed_heroes:
		if str(hero.get("id", "")) == hero_id:
			return true
	return false

func _build_hero_detail_screen(hero_id: String) -> void:
	if not _hero_belongs_to_selected_faction(hero_id):
		_show_toast("선택한 진영의 영웅만 확인할 수 있습니다.")
		_build_hero_select_screen()
		return
	HeroScreens.detail(self, hero_id)

func _equipped_slot_power(hero_id: String, slot: String) -> int:
	return _EQUIPMENT_COMMANDS.equipped_slot_power(self, hero_id, slot)

func _automatic_equipment_gain(item: Dictionary, hero_id: String) -> int:
	return _EQUIPMENT_COMMANDS.automatic_equipment_gain(self, item, hero_id)

func _best_auto_equipment_target(item: Dictionary, roster: Array) -> String:
	return _EQUIPMENT_COMMANDS.best_auto_equipment_target(self, item, roster)

func _gear_role_matches(item: Dictionary, hero_id: String) -> bool:
	return _EQUIPMENT_COMMANDS.gear_role_matches(self, item, hero_id)

func _equip_item_direct(index: int, hero_id: String) -> bool:
	return _EQUIPMENT_COMMANDS.equip_item_direct(self, index, hero_id)

func _recommend_equip_all() -> void:
	_EQUIPMENT_COMMANDS.recommend_equip_all(self)

func _bulk_enhance_equipped() -> void:
	preload("res://scripts/equipment/BulkEnhancePreview.gd").show(self)

func _show_summon_reveal(result: Dictionary) -> void:
	_presentation_event("summon")
	RewardDialogs.summon(self, result)

func _show_guardian_reveal(result: Dictionary) -> void:
	_presentation_event("summon")
	RewardDialogs.guardian(self, result)

func _build_codex_screen() -> void:
	ContentScreens.codex(self)

func _hero_accent_color(hero_id: String) -> Color:
	for hero in _hero_roster_for_faction():
		if str(hero.get("id", "")) == hero_id:
			return Color(hero.get("color", GOLD))
	return GOLD

func _emit_ultimate_cutin(hero_id: String, detail: String) -> void:
	if not combat_effects_enabled or not is_instance_valid(content_root):
		return
	if active_screen == "combat":
		var existing := content_root.get_node_or_null("FieldUltimateNotice")
		if is_instance_valid(existing):
			content_root.remove_child(existing)
			existing.queue_free()
		var notice := PanelContainer.new()
		notice.name = "FieldUltimateNotice"
		notice.position = combat_field_rect.position + Vector2(12, 64)
		notice.size = Vector2(240, 34)
		notice.z_index = 25
		notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
		notice.add_theme_stylebox_override("panel", _panel_style(Color("#ede8dce8"), _hero_accent_color(hero_id), 10, 1))
		content_root.add_child(notice)
		var text := _label("%s 궁극기" % _hero_short_name(hero_id), 16, Color("#203858"))
		text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		notice.add_child(text)
		var fade := content_root.create_tween()
		fade.tween_interval(0.55)
		fade.tween_property(notice, "modulate:a", 0.0, 0.18)
		fade.tween_callback(notice.queue_free)
		return
	var accent := _hero_accent_color(hero_id)
	var banner := PanelContainer.new()
	banner.position = Vector2(230, 86)
	banner.size = Vector2(820, 94)
	banner.z_index = 45
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.modulate = Color(1, 1, 1, 0)
	banner.scale = Vector2(0.88, 1.0)
	banner.pivot_offset = Vector2(410, 47)
	banner.add_theme_stylebox_override("panel", _panel_style(Color("#111827dd"), accent, 12, 2))
	content_root.add_child(banner)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	banner.add_child(box)
	var title := _label("ULTIMATE  ·  %s" % _hero_short_name(hero_id), 25, accent)
	box.add_child(title)
	var subtitle := _label(detail, 14, TEXT)
	subtitle.custom_minimum_size = Vector2(0, 32)
	box.add_child(subtitle)
	var flash := ColorRect.new()
	flash.color = Color(accent, 0.12)
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.z_index = 44
	content_root.add_child(flash)
	var tween := content_root.create_tween().set_parallel(true)
	tween.tween_property(banner, "modulate", Color.WHITE, 0.08)
	tween.tween_property(banner, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(flash, "color", Color(accent, 0.0), 0.28)
	tween.chain().tween_interval(0.38)
	tween.chain().tween_property(banner, "modulate:a", 0.0, 0.18)
	tween.chain().tween_callback(banner.queue_free)
	tween.chain().tween_callback(flash.queue_free)

func _emit_boss_telegraph(skill_name: String, seconds: float) -> void:
	_presentation_event("boss_warning")
	if not is_instance_valid(content_root):
		return
	var range_center := Vector2(_layout_width() * 0.52, 395.0)
	if is_instance_valid(raid_boss_sprite):
		range_center = raid_boss_sprite.position
	elif active_screen == "combat" and combat_field_rect.size.x > 0.0:
		range_center = combat_field_rect.position + combat_field_rect.size * Vector2(0.58, 0.55)
	if combat_effects_enabled:
		combat_fx.boss_telegraph(range_center, 126.0 if _mobile_wide_layout() else 105.0, Color("#ff5f55"), seconds, skill_name)
		combat_fx.camera_impact(3.0, 0.12, 0.006)
	# The raid status card already reports the countdown. Preserve the ten HP
	# cards below it instead of covering them with a second warning panel.
	if active_screen == "raid":
		return
	var previous_warning := content_root.get_node_or_null("BossTelegraphWarning")
	if is_instance_valid(previous_warning):previous_warning.free()
	var warning := PanelContainer.new()
	warning.name = "BossTelegraphWarning"
	var warning_width := minf(630.0, get_viewport_rect().size.x - 44.0)
	warning.position = Vector2((get_viewport_rect().size.x - warning_width) * 0.5, 555)
	warning.size = Vector2(warning_width, 74)
	warning.z_index = 46
	warning.mouse_filter = Control.MOUSE_FILTER_IGNORE
	warning.add_theme_stylebox_override("panel", _panel_style(Color("#3a1720e8"), Color("#ff765f"), 12, 2))
	content_root.add_child(warning)
	var label := _label("⚠ 위험 · %s · %.1f초 후 발동" % [skill_name, seconds], 19, Color("#ffb199"))
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	warning.add_child(label)
	var tween := content_root.create_tween()
	tween.set_loops(3)
	tween.tween_property(warning, "modulate", Color(1, 0.65, 0.65, 1), 0.12)
	tween.tween_property(warning, "modulate", Color.WHITE, 0.12)
	tween.finished.connect(warning.queue_free)

func _show_battle_result_popup(title_text: String, headline: String, detail: String, accent: Color) -> void:
	_presentation_event("victory")
	RewardDialogs.battle(self, title_text, headline, detail, accent)

func _show_toast(message: String) -> void:
	# Actions may rebuild a menu immediately after reporting their outcome.
	# Attach the notice to the resulting screen on the next frame.
	_display_toast.call_deferred(message)

func _display_toast(message: String) -> void:
	if not is_instance_valid(content_root):
		return
	var existing := content_root.get_node_or_null("ToastNotice")
	if is_instance_valid(existing):
		content_root.remove_child(existing)
		existing.queue_free()
	var toast := _label(message, 16, UI.INK)
	toast.name = "ToastNotice"
	toast.position = Vector2((_layout_width() - 700) * 0.5, 574)
	toast.size = Vector2(700, 54)
	toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast.z_index = 125
	var style := UI.panel(UI.SURFACE, UI.GOLD, 13)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	toast.add_theme_stylebox_override("normal", style)
	content_root.add_child(toast)
	var tween := content_root.create_tween()
	tween.tween_interval(2.2)
	tween.tween_property(toast, "modulate:a", 0.0, 0.35)
	tween.tween_callback(toast.queue_free)

func _spawn_floating_combat_text(message: String, color: Color, origin: Vector2) -> void:
	preload('res://scripts/presentation/CombatTextPresenter.gd').legacy(self,message,color,origin)

func _load_ui_preferences() -> void:
	var saved: Dictionary = PresentationSettings.load_preferences(presentation_preferences_path)
	combat_effects_enabled = saved["effects"]
	sound_effects_enabled = saved["sound"]
	presentation_options = saved["options"]
	if is_instance_valid(presentation_runtime): presentation_runtime.apply()

func _save_ui_preferences() -> void:
	presentation_settings_error = PresentationSettings.save_preferences(combat_effects_enabled, sound_effects_enabled, presentation_options, presentation_preferences_path)
	if is_instance_valid(presentation_runtime):
		presentation_runtime.settings_error = presentation_settings_error
		presentation_runtime.apply()
	_refresh_presentation_save_notice()

func _set_presentation_option(key: String, value: Variant, persist: bool = true) -> void:
	if not PresentationSettings.DEFAULTS.has(key): return
	presentation_options[key] = value
	presentation_options = PresentationSettings.sanitize(presentation_options)
	if is_instance_valid(presentation_runtime): presentation_runtime.apply()
	if persist: _save_ui_preferences()
	if key == "orientation": preload("res://scripts/app/DisplayOrientation.gd").apply(self)

func _refresh_presentation_save_notice() -> void:
	if not is_instance_valid(content_root): return
	var notice: Label = content_root.find_child("PresentationSettingsSaveStatus", true, false) as Label
	if notice != null: notice.text = "이 기기의 설정에 저장됩니다." if presentation_settings_error == OK else "설정을 저장하지 못했습니다. 현재 적용값은 앱 종료 시 사라질 수 있습니다."
	var retry: Node = content_root.find_child("PresentationRetrySave", true, false)
	if retry != null: retry.visible = presentation_settings_error != OK

func _open_presentation_settings() -> void:
	preload("res://scripts/presentation/PresentationSettingsScreen.gd").open(self)

func _presentation_event(kind: String) -> void:
	if is_instance_valid(presentation_runtime): presentation_runtime.event(kind)

func _presentation_profile() -> Dictionary:
	return presentation_runtime.profile if is_instance_valid(presentation_runtime) else PresentationSettings.PROFILES["balanced"]

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and is_instance_valid(content_root):
		if active_screen == "equipment_detail":
			_back_from_equipment_detail()
			get_viewport().set_input_as_handled()
			return
		var settings := content_root.get_node_or_null("PresentationSettingsOverlay")
		if settings != null:
			_save_ui_preferences()
			settings.queue_free()
			get_viewport().set_input_as_handled()
			return
		var modal := content_root.get_node_or_null("MenuOverlay")
		if is_instance_valid(modal):
			modal.queue_free()
			get_viewport().set_input_as_handled()

func _gear_inventory_index(item_id: String) -> int:
	return _EQUIPMENT_COMMANDS.gear_inventory_index(self, item_id)

func _gear_item(item_id: String, hero_id: String = "", slot: String = "") -> Dictionary:
	return _EQUIPMENT_COMMANDS.gear_item(self, item_id, hero_id, slot)

func _gear_update_item(item: Dictionary, hero_id: String = "", slot: String = "") -> bool:
	return _EQUIPMENT_COMMANDS.gear_update_item(self, item, hero_id, slot)

func _gear_enhance_item(item_id: String, hero_id: String = "", slot: String = "") -> Dictionary:
	return _EQUIPMENT_COMMANDS.gear_enhance_item(self, item_id, hero_id, slot)

func _gear_equip_item(item_id: String, hero_id: String) -> Dictionary:
	return _EQUIPMENT_COMMANDS.gear_equip_item(self, item_id, hero_id)

func _gear_decompose_item(item_id: String, confirmed: bool = false) -> Dictionary:
	return _EQUIPMENT_COMMANDS.gear_decompose_item(self, item_id, confirmed)

func _gear_workshop_action(item_id: String, action: String, args: Dictionary = {}, hero_id: String = "", slot: String = "") -> Dictionary:
	return _EQUIPMENT_COMMANDS.gear_workshop_action(self, item_id, action, args, hero_id, slot)

func _gear_option_matches(item: Dictionary, index: int, expected_option: Dictionary) -> bool:
	return _EQUIPMENT_COMMANDS.gear_option_matches(self, item, index, expected_option)

func _gear_extract_option(item_id: String, index: int, hero_id: String = "", slot: String = "", expected_option: Dictionary = {}) -> Dictionary:
	return _EQUIPMENT_COMMANDS.gear_extract_option(self, item_id, index, hero_id, slot, expected_option)

func _gear_apply_crystal(crystal_id: String, target_item_id: String, hero_id: String = "", slot: String = "") -> Dictionary:
	return _EQUIPMENT_COMMANDS.gear_apply_crystal(self, crystal_id, target_item_id, hero_id, slot)

func _set_gear_auto_equip(value: bool) -> void:
	_EQUIPMENT_COMMANDS.set_gear_auto_equip(self, value)

func _gear_claim_overflow(item_id: String) -> Dictionary:
	return _EQUIPMENT_COMMANDS.gear_claim_overflow(self, item_id)

func _gear_claim_overflow_many(item_ids: Array) -> Dictionary:
	return _EQUIPMENT_COMMANDS.gear_claim_overflow_many(self, item_ids)

func _roll_raid_equipment(zone: Dictionary) -> Dictionary:
	return _EQUIPMENT_COMMANDS.roll_raid_equipment(self, zone)

func _gear_market_ready() -> Dictionary:
	return _EQUIPMENT_COMMANDS.gear_market_ready(self)

func _market_snapshot() -> Dictionary:
	return _EQUIPMENT_COMMANDS.market_snapshot(self)

func _market_submit(action: String, params: Dictionary = {}) -> Dictionary:
	return _EQUIPMENT_COMMANDS.market_submit(self, action, params)

func _build_equipment_detail(item_id: String, hero_id: String = "", slot: String = "", tab: String = "info") -> void:
	var return_hero_id := str(gear_workshop_context.get("return_hero_id", "")) if active_screen == "equipment_detail" else (hero_id if active_screen == "hero_detail" else "")
	var return_scroll := int(gear_workshop_context.get("return_scroll", 0)) if active_screen == "equipment_detail" else 0
	if active_screen != "equipment_detail" and is_instance_valid(content_root):
		var scroll: ScrollContainer = content_root.get_node_or_null("PortraitContentScroll")
		if is_instance_valid(scroll):
			return_scroll = scroll.scroll_vertical
	gear_workshop_context = {"item_id": item_id, "hero_id": hero_id, "slot": slot, "tab": tab, "return_hero_id": return_hero_id, "return_scroll": return_scroll}
	GEAR_UI.detail(self, item_id, hero_id, slot, tab)

func _back_from_equipment_detail() -> void:
	var hero_id := str(gear_workshop_context.get("return_hero_id", ""))
	if not hero_id.is_empty() and _valid_growth_hero(hero_id):
		_build_hero_detail_screen(hero_id)
	else:
		_build_inventory_screen()
	var scroll: ScrollContainer = content_root.get_node_or_null("PortraitContentScroll")
	if is_instance_valid(scroll):
		scroll.set_deferred("scroll_vertical", int(gear_workshop_context.get("return_scroll", 0)))

func _build_equipment_workshop(item_id: String, hero_id: String = "", slot: String = "") -> void:
	_build_equipment_detail(item_id, hero_id, slot, "options")

func _build_option_crystal(crystal_id: String) -> void:
	_build_equipment_detail(crystal_id, "", "", "implant")

func _build_equipment_market() -> void:
	GEAR_UI.market(self)

func _build_equipment_stash() -> void:
	GEAR_UI.stash(self)


# v81 goal entry points. Graphical theme and assets are not changed.
func _goal_record(event: String, amount: int = 1) -> void:
	GOALS.record(self, event, amount)

func _open_goal_screen() -> void:
	if challenge_session != null or raid_running:
		_show_toast("전투를 마친 뒤 목표를 확인해 주세요.")
		return
	set_meta("content_meta_tab", "quests")
	_build_meta_hub_screen()

func _goal_claim_context(scope: String) -> Dictionary:
	return GOALS.context(self, scope)

func _claim_goal(scope: String, id: String, expected: Dictionary) -> Dictionary:
	return GOALS.claim(self, scope, id, expected)

func _claim_all_goals(scope: String, expected: Dictionary) -> Dictionary:
	return GOALS.claim_all(self, scope, expected)

func _goal_route(route: String) -> void:
	if challenge_session != null or raid_running:
		_show_toast("전투를 마친 뒤 이동해 주세요.")
		return
	match route:
		"hunt":
			if deployed_heroes.is_empty(): _build_hero_select_screen()
			else: _build_combat_screen()
		"growth": _build_growth_screen()
		"codex": _build_codex_screen()
		"goals": _open_goal_screen()
		"daily", "tower", "weekly", "raids":
			set_meta("content_meta_tab", route)
			_build_meta_hub_screen()

func _goal_hp_multiplier(hero_id: String) -> float:
	if str(HERO_ROSTER.HEROES.get(hero_id, {}).get("faction", "")) != selected_faction: return 1.0
	return 1.0 + float(LongTermGoalState.collection_tier(long_term_goals, selected_faction)) * 0.005


# v83-2: observational challenge analysis; runtime-only, no automatic purchases.
func _open_challenge_report(expected_serial: int = -1) -> void:
	var report: Dictionary = get_meta("last_challenge_report", {})
	if challenge_session != null or raid_running or report.is_empty(): return
	if str(report.get("entry", {}).get("faction", "")) != selected_faction: return
	if expected_serial >= 0 and int(report.get("serial", -1)) != expected_serial: return
	preload("res://scripts/ui/ChallengeReportScreens.gd").build(self, report.duplicate(true))

func _challenge_report_action(action: String, serial: int, hero_id: String = "") -> void:
	var report: Dictionary = get_meta("last_challenge_report", {})
	if active_screen != "challenge_report" or challenge_session != null or raid_running: return
	if int(report.get("serial", -1)) != serial or str(report.get("entry", {}).get("faction", "")) != selected_faction: return
	set_meta("content_meta_tab", str(report.get("mode", "daily")))
	match action:
		"back": _build_meta_hub_screen()
		"formation": _open_content_party("meta")
		"growth":
			if hero_id not in report.get("entry", {}).get("hero_ids", []): return
			set_meta("growth_hero_id", hero_id)
			_build_growth_screen()

# v83-3 lab and unified loadout entry points. No account/server work.
func _retry_pending_save() -> void:
	SAVE_SAFETY.retry(self)

func _open_practice_screen() -> void:
	if challenge_session != null or raid_running: return
	preload("res://scripts/progression/PracticeScreens.gd").build(self)

func _start_practice(mode: String, difficulty: int = 1, variant: String = "gold_rush", expected: Dictionary = {}, level_mode: String = "actual", match_level: int = 1) -> bool:
	return PRACTICE.start(self, mode, difficulty, variant, expected, level_mode, match_level)

func _effective_combat_level(hero_id: String) -> int:
	return preload("res://scripts/progression/PracticeLevelRules.gd").effective_level(self, hero_id)

func _open_research_allocation(hero_id: String) -> void:
	preload("res://scripts/progression/ResearchAllocationScreens.gd").build(self, hero_id)

func _preview_party_preset(index: int) -> void:
	if challenge_session != null or raid_running: return
	preload("res://scripts/progression/PracticeScreens.gd").preview(self, index)

func _open_combat_presets() -> void:
	if challenge_session != null or raid_running: return
	preload("res://scripts/progression/PracticeScreens.gd").presets(self)

func _open_raid_report(index: int = 0) -> void:
	if raid_running or challenge_session != null: return
	preload("res://scripts/raid/RaidContributionScreens.gd").build(self, index)

func _open_battle_formation() -> void:
	preload("res://scripts/ui/FormationScreen.gd").open(self)
