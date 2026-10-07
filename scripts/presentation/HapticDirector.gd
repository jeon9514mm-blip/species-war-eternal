class_name HapticDirector
extends RefCounted
## One bounded pulse per event. Unit tests inject a sink, never vibrate hardware.
var mode: String = "off"
var suspended: bool = false
var sink: Callable
var _last_ms: int = -10000
var accepted: int = 0
const PULSES := {"ui_click": [12, 0.22], "equip": [18, 0.32], "upgrade": [25, 0.4],
	"reward": [22, 0.3], "summon": [40, 0.5], "victory": [55, 0.55], "ultimate": [30, 0.45],
	"boss_warning": [50, 0.65], "shield_break": [35, 0.5], "critical": [12, 0.22]}

func pulse(event: String, now_ms: int = -1) -> bool:
	if mode == "off" or suspended or not PULSES.has(event): return false
	var now: int = Time.get_ticks_msec() if now_ms < 0 else now_ms
	var gap: int = 200 if event in ["ui_click", "equip", "upgrade"] else 500
	if now - _last_ms < gap: return false
	var spec: Array = PULSES[event]
	var duration: int = mini(80, int(spec[0]))
	var strength: float = float(spec[1]) * (0.5 if mode == "light" else 1.0)
	if sink.is_valid():
		sink.call(duration, strength)
	elif OS.has_feature("android") or OS.has_feature("ios"):
		Input.vibrate_handheld(duration, strength)
	else:
		return false
	_last_ms = now
	accepted += 1
	return true
