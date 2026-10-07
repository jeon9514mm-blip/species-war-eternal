extends "res://scripts/heroes/HeroSpriteController.gd"
## Presentation only. All combat time, movement, damage and RNG remain in the v32 code.
## Uses 1--3 extracted source key poses per action. It does NOT claim hand-drawn in-betweens
## or new rear/up/down art. Vertical directions reuse the 3/4 source; left is mirrored.
const ACTIONS: Array[String] = ["idle", "walk", "run", "attack_1", "attack_2", "skill", "ultimate", "hit", "knockback", "dodge", "guard", "buff", "debuff", "victory", "death", "spawn"]
const FRAME_PATHS: Dictionary = {"leonhardt":"res://assets/heroes/actions-v37/leonhardt/frames.tres", "valeria":"res://assets/heroes/actions-v37/valeria/frames.tres"}
const PIVOT := Vector2(144,264)
const BODY_HEIGHT: float = 128.0
const CONTINUOUS: Array[String] = ["idle","walk","run","debuff"]
static var _frames_cache: Dictionary = {}
var visual_action: String = "idle"
var playback_log: Array[String] = []
var observe_game: bool = true
var hold_demo: bool = false
var _main_ref: WeakRef
var _locked: bool = false
var _clock: float = 0.0
var _strike: int = 0
var _last_hp: int = -1
var _last_guard: float = 0.0
var _last_shield: int = 0
var _last_hits: int = 0
var _last_kills: int = -1
var _last_stun: float = 0.0
var _demo_override: bool = false
signal visual_action_finished(action_name: String)

func configure_actions(hero_id: String) -> void:
	assert(hero_id in ["leonhardt", "valeria"])
	atlas_key = hero_id
	sheet_layout = "two_hero_actions_v37"
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	material = null
	_build_sprite_frames()
	play_visual("idle")

func _build_sprite_frames() -> void:
	if atlas_key not in ["leonhardt", "valeria"]:
		_frames_ready = false
		return
	if not _frames_cache.has(atlas_key):
		var frames: SpriteFrames = load(str(FRAME_PATHS[atlas_key])) as SpriteFrames
		assert(frames != null, "Action asset missing: " + atlas_key)
		# The legacy public API remains queryable by pre-existing screens and tests.
		for facing: String in DIRECTIONS:
			for legacy: String in STATES:
				var from_action: String = "attack_1" if legacy == "attack" else legacy
				var alias: String = "%s_%s" % [legacy, facing]
				if not frames.has_animation(alias):
					frames.add_animation(alias)
					frames.set_animation_speed(alias, frames.get_animation_speed(from_action))
					frames.set_animation_loop(alias, frames.get_animation_loop(from_action))
					for i: int in frames.get_frame_count(from_action):
						frames.add_frame(alias, frames.get_frame_texture(from_action,i), frames.get_frame_duration(from_action,i))
		_frames_cache[atlas_key] = frames
	sprite_frames = (_frames_cache[atlas_key] as SpriteFrames).duplicate(false) as SpriteFrames
	preload("res://scripts/portrait/HeroRigMotionCatalog.gd").add_spawn_track(sprite_frames)
	native_visual_height = BODY_HEIGHT
	centered = false
	offset = -PIVOT
	_frames_ready = true

func _ready() -> void:
	super._ready()
	_find_game()

func _find_game() -> Node:
	if _main_ref != null:
		var existing: Node = _main_ref.get_ref() as Node
		if is_instance_valid(existing): return existing
	var p: Node = get_parent()
	while p != null:
		if p.has_method("_deployed_hero_ids"):
			_main_ref = weakref(p)
			return p
		p = p.get_parent()
	return null

func _legacy_state(action: String) -> String:
	if action in ["walk","run"]: return "walk"
	if action == "death": return "death"
	if action in ["hit","knockback"]: return "hit"
	if action in ["attack_1","attack_2","skill","ultimate"]: return "attack"
	return "idle"

func play_visual(action: String, restart: bool = true) -> bool:
	if not _frames_ready or action not in ACTIONS or not sprite_frames.has_animation(action): return false
	if action == visual_action and is_playing() and not restart: return true
	visual_sequence += 1
	visual_action = action
	state = _legacy_state(action)
	_locked = action not in CONTINUOUS and action != "death"
	_clock = 0.0
	_death_time = 0.0
	_hit_flash_time = 0.16 if action in ["hit","knockback"] else 0.0
	modulate.a = 1.0
	flip_h = direction == "left"
	offset = -PIVOT
	rotation = 0.0
	stop()
	play(action)
	playback_log.append(action)
	if playback_log.size() > 128: playback_log.pop_front()
	return true

func _intent_action() -> String:
	var game: Node = _find_game()
	if observe_game and game != null:
		var runtimes: Dictionary = game.get("hero_skill_runtime")
		var rt: Dictionary = runtimes.get(atlas_key,{})
		if bool(rt.get("cast_ultimate",false)): return "ultimate"
		if bool(rt.get("cast_secondary",false)) or bool(rt.get("cast",false)): return "skill"
	_strike += 1
	return "attack_1" if _strike % 2 == 1 else "attack_2"

func play_state(next_state: String, next_direction := "") -> void:
	if next_direction in DIRECTIONS: direction = next_direction
	flip_h = direction == "left"
	if not _frames_ready: return
	if next_state == "death":
		if visual_action != "death": play_visual("death")
		return
	if visual_action == "death":
		# A real gameplay revival calls idle/walk. The sprite never revives the unit.
		if next_state in ["idle","walk"]: play_visual(next_state)
		return
	if _locked and next_state in ["idle","walk","attack"]: return
	if next_state == "attack": play_visual(_intent_action()); return
	if next_state == "hit": play_visual("hit"); return
	if next_state in ACTIONS: play_visual(next_state,false)
	else: play_visual("idle",false)

func play_attack(next_direction := "") -> void:
	if next_direction in DIRECTIONS: direction = next_direction
	if visual_action == "death": return
	play_visual(_intent_action())

func play_walk(velocity := Vector2.ZERO) -> void:
	# Never moves the body; Main/PartyMovementController still owns position.
	if velocity.length_squared() > 0.01:
		if absf(velocity.x) > absf(velocity.y): direction = "right" if velocity.x > 0 else "left"
		else: direction = "down" if velocity.y > 0 else "up"
	flip_h = direction == "left"
	if _locked or visual_action == "death": return
	var action: String = "run" if velocity.length() >= 1.25 else "walk"
	play_visual(action,false)

func _on_animation_finished() -> void:
	var finished: String = visual_action
	_locked = false
	visual_action_finished.emit(finished)
	var legacy: String = _legacy_state(finished)
	if legacy in ["attack","hit"]: action_finished.emit(legacy)
	if finished == "death" or hold_demo: return
	play_visual("idle")

func _observe_main_state() -> void:
	if not observe_game: return
	var game: Node = _find_game()
	if game == null or str(game.get("active_screen")) != "combat": return
	var sprites: Array = game.get("hero_map_sprites")
	if not sprites.has(self): return # Hero detail/menu portraits must not observe combat leftovers.
	var states: Dictionary = game.get("hero_battle_state")
	var record: Dictionary = states.get(atlas_key,{})
	if record.is_empty(): return
	var hp: int = int(record.get("hp",0))
	var max_hp: int = maxi(1,int(record.get("max_hp",1)))
	var guard_time: float = float(record.get("guard",0.0))
	var shield: int = int(record.get("shield",0))
	var hits: int = int(record.get("incoming_hits",0))
	var kills: int = int(game.get("combat_kills"))
	var stun: float = maxf(float(record.get("stun_seconds",0.0)),float(record.get("stun",0.0)))
	var chosen: String = ""
	if hp <= 0:
		if visual_action != "death": chosen = "death"
	elif _last_hp >= 0 and hp < _last_hp:
		chosen = "knockback" if _last_hp-hp >= int(max_hp*0.12) else "hit"
	elif hits > _last_hits and str(record.get("role_group","")) != "탱커":
		# Observe the existing deterministic dodge counter. No RNG or hit counter writes.
		var cadence: int = 19 if str(record.get("role_group","")) == "딜러" else 27
		if (hits + int(record.get("slot",0))*7) % cadence == 0: chosen = "dodge"
	elif stun > 0 and _last_stun <= 0: chosen = "debuff"
	elif not _locked:
		if _last_kills >= 0 and kills > _last_kills: chosen = "victory"
		elif guard_time > 0 and _last_guard <= 0: chosen = "guard"
		elif shield > _last_shield: chosen = "buff"
		elif visual_action == "debuff" and stun <= 0: chosen = "idle"
	if not chosen.is_empty(): play_visual(chosen,visual_action!=chosen)
	_last_hp = hp; _last_guard = guard_time; _last_shield = shield
	_last_hits = hits; _last_kills = kills; _last_stun = stun

func _process(delta: float) -> void:
	if speed_scale <= 0.0: return
	super._process(delta)
	_observe_main_state()
	if get_node_or_null('PortraitHeroSkeletalRig')!=null:
		offset=-PIVOT;rotation=0.0
		return
	var dt: float = maxf(0.0,delta)*absf(speed_scale)
	_clock += dt
	var move: Vector2 = Vector2.ZERO
	var angle: float = 0.0
	# Small visual-only offsets give held key poses life without fabricating drawings.
	match visual_action:
		"idle": move.y = sin(_clock*3.6)*0.65
		"walk": move.y = -absf(sin(_clock*10.0))*1.4
		"run": move.y = -absf(sin(_clock*14.0))*2.0
		"knockback": move.x = -sin(minf(_clock/.5,1.0)*PI)*9.0; angle = sin(minf(_clock/.5,1.0)*PI)*-.10
		"dodge": move.x = -sin(minf(_clock/.5,1.0)*PI)*8.0
		"victory": move.y = -absf(sin(minf(_clock/.6,1.0)*PI))*3.0
		"debuff": angle = sin(_clock*7.0)*.02
	offset = -PIVOT + move
	rotation = angle
