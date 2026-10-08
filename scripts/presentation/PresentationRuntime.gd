class_name PresentationRuntime
extends Node
## Presentation feedback keeps the combat clock running at its selected speed.
var game: Node
var audio: GameAudioDirector
var contact_time: Node
var haptics := HapticDirector.new()
var profile: Dictionary = PresentationSettings.profile({})
var _elapsed: float = 0.0
var _original_fps: int = 0
var _applied_fps: int = 0
var _frame_samples := PackedFloat32Array()
var _sample_cursor: int = 0
var settings_error: int = OK
var _last_scene: String = ""
var _last_frame_us: int = 0

func bind(host: Node) -> void:
	game = host; name = "PresentationRuntime"
	process_mode = Node.PROCESS_MODE_ALWAYS
	_original_fps = Engine.max_fps
	audio = GameAudioDirector.new(); audio.name = "GameAudio"; add_child(audio)
	contact_time=preload('res://scripts/presentation/ContactTimeDilation.gd').new();contact_time.name='ContactTimeDilation';contact_time.game=game;add_child(contact_time)
	var loot_feedback:=preload('res://scripts/presentation/LootRewardFeedback.gd').new();loot_feedback.name='LootRewardFeedback';loot_feedback.bind(game);add_child(loot_feedback)
	var celebration:=preload('res://scripts/presentation/HeroCelebrationFeedback.gd').new();celebration.name='HeroCelebrationFeedback';celebration.bind(game);add_child(celebration)
	apply()
	get_tree().node_added.connect(_on_node_added)
	_wire_buttons(game)

func apply() -> void:
	if not is_instance_valid(game) or not is_instance_valid(audio): return
	game.presentation_options = PresentationSettings.sanitize(game.presentation_options)
	profile = PresentationSettings.profile(game.presentation_options)
	audio.configure(game.presentation_options, game.sound_effects_enabled)
	haptics.mode = str(game.presentation_options["haptics"])
	game.combat_fx.optional_node_limit = int(profile["fx_limit"])
	_applied_fps = int(profile["fps"])
	# Headless simulations should not be throttled by a render-only setting.
	if DisplayServer.get_name() != "headless": Engine.max_fps = _applied_fps
	sync_context()

func _record_frame(now: int) -> float:
	# Hit-stop scales delta and can end before this callback. Measure the wall
	# interval directly so slow motion cannot report fictitious render FPS.
	if game._application_suspended:
		_last_frame_us = 0
		return 0.0
	var previous := _last_frame_us
	_last_frame_us = now
	if previous <= 0 or now <= previous: return 0.0
	var seconds := float(now - previous) / 1000000.0
	if _frame_samples.size() < 180: _frame_samples.append(seconds * 1000.0)
	else: _frame_samples[_sample_cursor] = seconds * 1000.0; _sample_cursor = (_sample_cursor + 1) % 180
	return seconds

func _process(_delta: float) -> void:
	if not is_instance_valid(game): return
	_elapsed += _record_frame(Time.get_ticks_usec())
	if _elapsed >= 0.20: _elapsed = 0.0; sync_context()

func sync_context() -> void:
	if not is_instance_valid(game): return
	var paused: bool = bool(game._application_suspended)
	# Some mobile platforms stop callbacks as soon as the pause notification
	# arrives; clear the origin here even if no suspended frame is processed.
	if paused: _last_frame_us = 0
	if not is_instance_valid(audio): return
	haptics.suspended = paused
	var combat_pause: bool = str(game.active_screen) == "combat" and not bool(game.combat_running)
	var audio_pause: bool = paused
	audio.combat_paused = combat_pause
	haptics.combat_paused = combat_pause or (str(game.active_screen)=='raid' and not bool(game.raid_running))
	if audio.suspended != audio_pause: audio.set_suspended(audio_pause)
	# Legacy toggles remain supported even when old code changes them directly.
	if audio.sound_enabled != bool(game.sound_effects_enabled): audio.configure(game.presentation_options, game.sound_effects_enabled)
	var zone: String = {"gray_meadow": "meadow", "forgotten_mine": "mine", "moonrest_forest": "forest"}.get(str(game.current_zone_id), "meadow")
	var boss: bool = str(game.active_screen) == "raid" and bool(game.raid_running)
	if game.challenge_session != null and game.challenge_session.is_running():
		boss = boss or game.challenge_session.mode == "weekly" or game.challenge_session.variant == "boss"
	var scene: String = ("boss" if boss else zone)
	var ambient: String = "ambient_" + zone if str(game.active_screen) in ["combat", "raid"] and not boss else ""
	for view in get_tree().get_nodes_in_group("game_battlefields"):
		if view.game==game:view.set_presentation_suspended(paused);view.apply_render_profile()
	audio.set_scene(scene, ambient)
	_last_scene = scene

func event(kind: String) -> void:
	if not is_instance_valid(game) or bool(game._application_suspended): return
	sync_context()
	if is_instance_valid(audio): audio.play_cue(kind)
	# Haptics do not depend on speaker volume but respect pause and opt-out.
	if not audio.suspended and (not audio.combat_paused or kind in ["ui_click", "equip", "upgrade", "reward", "summon", "victory"]): haptics.pulse(kind)

func _wire_buttons(node: Node) -> void:
	_on_node_added(node)
	for child in node.get_children(): _wire_buttons(child)

func _on_node_added(node: Node) -> void:
	if not node is BaseButton or not is_instance_valid(game) or not game.is_ancestor_of(node): return
	if int(node.get_meta("v82_feedback_owner", 0)) == get_instance_id(): return
	node.set_meta("v82_feedback_owner", get_instance_id())
	var call: Callable = _button_feedback.bind(weakref(node))
	node.pressed.connect(call)

func _button_feedback(ref: WeakRef) -> void:
	var button: BaseButton = ref.get_ref() as BaseButton
	if button != null and not button.disabled: event("ui_click")

func diagnostics() -> Dictionary:
	var samples: PackedFloat32Array = _frame_samples.duplicate(); samples.sort()
	var average: float = 0.0
	for value in samples: average += value
	return {"render_target_fps": _applied_fps, "headless": DisplayServer.get_name() == "headless",
		"sample_count": samples.size(), "frame_ms_mean": average / maxf(1.0, samples.size()),
		"frame_ms_p95": samples[int(floor((samples.size() - 1) * 0.95))] if not samples.is_empty() else 0.0,
		"physics_ticks_per_second": Engine.physics_ticks_per_second, "audio": audio.diagnostics() if audio != null else {},
		"settings_error": settings_error, "haptic_mode": haptics.mode}

func _exit_tree() -> void:
	if DisplayServer.get_name() != "headless" and Engine.max_fps == _applied_fps: Engine.max_fps = _original_fps
