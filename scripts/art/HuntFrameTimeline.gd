extends RefCounted
## Presentation-only clock. The simulation owns anticipation and release;
## there are no timers, random draws, callbacks to damage, or source writes.
const RELEASE_PHASE := .44
var elapsed := 0.0
var release_age := -1.0
var hit_age := -1.0
var death_age := -1.0
var sequence := 0
var release_action := "attack_1"
var duration := .15 / RELEASE_PHASE
var recoil := Vector2.ZERO
var _release_pending := false
var _hit_pending := false
var _last: Dictionary = {}
var _dead := false
var _initialized := false

func release(action: String, windup: float) -> void:
	sequence += 1
	release_action = action
	duration = clampf(windup / RELEASE_PHASE, .20, 1.0)
	release_age = 0.0
	_release_pending = true

func hit(direction: Vector2) -> void:
	hit_age = 0.0
	recoil = direction.normalized() if direction.is_finite() else Vector2.ZERO
	_hit_pending = true

func sample(runtime: Dictionary, walking: bool, dead: bool, delta: float, active: bool) -> Dictionary:
	var event := _release_pending or _hit_pending or (_initialized and dead!=_dead)
	if not active and not event and not _last.is_empty():
		var held := _last.duplicate(); held.event = false
		return held
	var dt := clampf(delta, 0.0, .1) if active and is_finite(delta) else 0.0
	if not dead and _dead:
		death_age=-1.0;release_age=-1.0;hit_age=-1.0
	_dead=dead;_initialized=true
	elapsed += dt
	if release_age >= 0.0 and not _release_pending: release_age += dt
	if hit_age >= 0.0 and not _hit_pending: hit_age += dt
	if dead and death_age < 0.0: death_age = 0.0
	elif death_age >= 0.0: death_age += dt
	var action := "walk" if walking else "idle"
	var time := elapsed
	var action_duration := .6
	var windup := float(runtime.get("windup", -1.0))
	if dead or death_age >= 0.0:
		action = "death"; time = death_age; action_duration = .65
	elif windup >= 0.0:
		var prepare := maxf(.001, float(runtime.get("attack_windup_duration", .15)))
		action_duration = prepare / RELEASE_PHASE
		time = clampf(1.0 - windup / prepare, 0.0, 1.0) * action_duration * RELEASE_PHASE
		action = str(runtime.get("visual_action", "attack_1"))
	elif release_age >= 0.0 and release_age < duration * (1.0 - RELEASE_PHASE):
		action = release_action; action_duration = duration
		time = duration * RELEASE_PHASE + release_age
	elif hit_age >= 0.0 and hit_age < .22:
		action = "hit"; time = hit_age; action_duration = .22
	_last = {"action":action, "time":time, "duration":action_duration,
		"sequence":sequence, "event":event, "hit_age":hit_age, "recoil":recoil}
	_release_pending = false; _hit_pending = false
	return _last.duplicate()
