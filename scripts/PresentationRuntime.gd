class_name PresentationRuntime
extends Node
## Owns only presentation. Never changes physics cadence, time_scale or rewards.
var game: Node
var audio: GameAudioDirector
var haptics := HapticDirector.new()
var profile: Dictionary = PresentationSettings.profile({})
var _elapsed: float = 0.0
var _original_fps: int = 0
var _applied_fps: int = 0
var _frame_samples := PackedFloat32Array()
var _sample_cursor: int = 0
var settings_error: int = OK
var _last_scene: String = ""

func bind(host: Node) -> void:
	game = host; name = "PresentationRuntime"
	process_mode = Node.PROCESS_MODE_ALWAYS
	_original_fps = Engine.max_fps
	audio = GameAudioDirector.new(); audio.name = "GameAudio"; add_child(audio)
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

func _process(delta: float) -> void:
	if not is_instance_valid(game): return
	if not game._application_suspended and is_finite(delta) and delta > 0.0:
		if _frame_samples.size() < 180: _frame_samples.append(delta * 1000.0)
		else: _frame_samples[_sample_cursor] = delta * 1000.0; _sample_cursor = (_sample_cursor + 1) % 180
	_elapsed += delta
	if _elapsed >= 0.20: _elapsed = 0.0; sync_context()

func sync_context() -> void:
	if not is_instance_valid(game) or not is_instance_valid(audio): return
	var paused: bool = bool(game._application_suspended)
	haptics.suspended = paused
	var combat_pause: bool = str(game.active_screen) == "combat" and not bool(game.combat_running)
	var audio_pause: bool = paused
	audio.combat_paused = combat_pause
	if audio.suspended != audio_pause: audio.set_suspended(audio_pause)
	# Legacy toggles remain supported even when old code changes them directly.
	if audio.sound_enabled != bool(game.sound_effects_enabled): audio.configure(game.presentation_options, game.sound_effects_enabled)
	var zone: String = {"gray_meadow": "meadow", "forgotten_mine": "mine", "moonrest_forest": "forest"}.get(str(game.current_zone_id), "meadow")
	var boss: bool = str(game.active_screen) == "raid" and bool(game.raid_running)
	if game.challenge_session != null and game.challenge_session.is_running():
		boss = boss or game.challenge_session.mode == "weekly" or game.challenge_session.variant == "boss"
	var scene: String = ("boss" if boss else zone)
	var ambient: String = "ambient_" + zone if str(game.active_screen) in ["combat", "raid"] and not boss else ""
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
