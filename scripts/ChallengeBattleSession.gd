extends RefCounted
class_name ChallengeBattleSession

## Runtime-only lifecycle. Victory comes from combat observations, never power.
## Sessions are deliberately not restored after an application restart.
enum State { READY, RUNNING, WON, LOST, CANCELLED, SETTLED }

var state: State = State.READY
var serial: int = 0
var practice: bool = false
var mode: String = ""
var variant: String = ""
var title: String = ""
var objective: String = "waves"
var objective_description: String = ""
var limit_seconds: float = 60.0
var elapsed: float = 0.0
var required_waves: int = 3
var cleared_waves: int = 0
var active_wave_token: int = -1
var reason: String = ""
var entry_context: Dictionary = {}
var _credited_tokens: Dictionary = {}
const MAX_DAMAGE_SCORE: int = 1000000000000
var damage_score: int = 0
# Per-target lowest observed HP prevents duplicate callbacks and return/heal
# loops from scoring the same health twice. Cleared-wave ledgers are discarded.
var _score_target_hp: Dictionary = {}
var _registered_score_targets: int = 0
var pattern: Dictionary = {}
var pattern_metrics: Dictionary = {}
var combat_ledger = preload("res://scripts/ChallengeCombatLedger.gd").new()

func begin(next_serial: int, plan: Dictionary, context: Dictionary) -> bool:
	if state != State.READY or next_serial <= 0:
		return false
	var seconds: float = float(plan.get("limit_seconds", 0.0))
	var waves: int = int(plan.get("required_waves", 0))
	var next_objective: String = str(plan.get("objective", "waves"))
	if not is_finite(seconds) or seconds <= 0.0 or next_objective not in ["waves", "survive", "score"]:
		return false
	if (next_objective == "waves" and waves <= 0) or (next_objective in ["survive", "score"] and waves != 0):
		return false
	practice = bool(plan.get("practice", false))
	serial = next_serial
	mode = str(plan.get("mode", "daily"))
	variant = str(plan.get("variant", "gold_rush"))
	title = str(plan.get("title", "일일 원정"))
	objective = next_objective
	objective_description = str(plan.get("description", ""))
	limit_seconds = seconds
	required_waves = waves
	entry_context = context.duplicate(true)
	pattern = plan.get("pattern", {}).duplicate(true)
	pattern_metrics.clear()
	state = State.RUNNING
	return true

func is_running() -> bool:
	return state == State.RUNNING

func remaining_seconds() -> float:
	return maxf(0.0, limit_seconds - elapsed)

func start_wave(token: int) -> bool:
	if not is_running() or token < 0 or active_wave_token >= 0 or _credited_tokens.has(token):
		return false
	active_wave_token = token
	_score_target_hp.clear()
	return true

func register_score_target(token: int, enemy_id: String, hp: int) -> bool:
	if not is_running() or mode != "weekly" or objective != "score" or token != active_wave_token or token < 0 or hp <= 0 or enemy_id.is_empty() or _score_target_hp.has(enemy_id):
		return false
	_score_target_hp[enemy_id] = hp
	_registered_score_targets += 1
	return true

func record_hp_loss(token: int, enemy_id: String, before_hp: int, after_hp: int) -> int:
	if not is_running() or mode != "weekly" or objective != "score" or token != active_wave_token or token < 0 or elapsed >= limit_seconds or not _score_target_hp.has(enemy_id):
		return 0
	if before_hp <= 0 or after_hp < 0 or after_hp >= before_hp:
		return 0
	var lowest: int = int(_score_target_hp[enemy_id])
	var credit: int = maxi(0, mini(lowest, before_hp) - after_hp)
	_score_target_hp[enemy_id] = mini(lowest, after_hp)
	credit = mini(credit, MAX_DAMAGE_SCORE - damage_score)
	damage_score += credit
	return credit

func complete_wave(token: int, alive_enemies: int, alive_heroes: int) -> bool:
	if not is_running() or token != active_wave_token or token < 0 or _credited_tokens.has(token):
		return false
	if alive_enemies != 0 or alive_heroes <= 0:
		return false
	_credited_tokens[token] = true
	active_wave_token = -1
	cleared_waves += 1
	if objective == "waves" and cleared_waves >= required_waves:
		state = State.WON
		reason = "waves_cleared"
	return true

func advance_clock(delta: float, alive_heroes: int = 0) -> void:
	if not is_running() or not is_finite(delta) or delta <= 0.0:
		return
	elapsed = minf(limit_seconds, elapsed + delta)
	if elapsed < limit_seconds:
		return
	# A living party and an actually spawned encounter are necessary. A blank
	# survival screen cannot become a free clear just by advancing its clock.
	if objective == "score" and alive_heroes > 0 and _registered_score_targets > 0 and damage_score > 0:
		state = State.WON
		reason = "score_finished"
	elif objective == "score":
		defeat("party_defeated" if alive_heroes <= 0 else "no_damage")
	elif objective == "survive" and alive_heroes > 0 and (active_wave_token >= 0 or cleared_waves > 0):
		state = State.WON
		reason = "survived"
	else:
		defeat("party_defeated" if objective == "survive" and alive_heroes <= 0 else "timeout")

func defeat(cause: String = "party_defeated") -> void:
	if not is_running():
		return
	state = State.LOST
	reason = cause

func cancel(cause: String = "left_screen") -> void:
	if not is_running():
		return
	state = State.CANCELLED
	reason = cause

func take_victory_receipt(expected_serial: int) -> Dictionary:
	if practice or state != State.WON or expected_serial != serial:
		return {}
	state = State.SETTLED
	return {"serial": serial, "mode": mode, "variant": variant, "elapsed": elapsed,
		"waves": cleared_waves, "damage_score": damage_score, "reason": reason, "entry": entry_context.duplicate(true)}

func progress_ratio() -> float:
	if objective in ["survive", "score"]:
		return clampf(elapsed / maxf(0.001, limit_seconds), 0.0, 1.0)
	return clampf(float(cleared_waves) / maxf(1.0, float(required_waves)), 0.0, 1.0)

func progress_text() -> String:
	if objective == "score":
		return "피해 %d · %.0f/%.0f초" % [damage_score, elapsed, limit_seconds]
	if objective == "survive":
		return "생존 %.0f / %.0f초" % [elapsed, limit_seconds]
	return "%d / %d 무리" % [cleared_waves, required_waves]

func status_text() -> String:
	var suffix: String = "준비" if state == State.READY else "전투"
	if state == State.WON or state == State.SETTLED:
		suffix = "완료"
	elif state == State.LOST:
		suffix = "시간 초과" if reason == "timeout" else "전투 종료"
	elif state == State.CANCELLED:
		suffix = "취소"
	return "%s · %s · 남은 %.0f초 · %s" % [title, progress_text(), remaining_seconds(), suffix]
