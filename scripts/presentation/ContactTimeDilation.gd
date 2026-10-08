extends Node
## Crit-only short slowdown, plus an explicit bounded ultimate emphasis request.
var game: Node
var enabled:=true
var deadline_us:=0
var cooldown_us:=0
var previous_scale:=1.0
var ultra_cooldown_us:=0
func _ready() -> void:process_mode=Node.PROCESS_MODE_ALWAYS;process_priority=-100
func request(critical:=true) -> void:
	if not critical or not _eligible():return
	var now:=Time.get_ticks_usec()
	if now<cooldown_us or deadline_us>0:return
	previous_scale=Engine.time_scale;Engine.time_scale=previous_scale*.15;deadline_us=now+80000;cooldown_us=now+1500000
func request_ultra() -> bool:
	if not _eligible():return false
	var now:=Time.get_ticks_usec()
	if now<ultra_cooldown_us:return false
	# Upgrade a short contact at the ultimate impact without multiplying two slowdowns.
	if deadline_us<=0:previous_scale=Engine.time_scale
	Engine.time_scale=previous_scale*.08;deadline_us=now+180000
	cooldown_us=now+3000000;ultra_cooldown_us=now+3000000
	return true
func _eligible() -> bool:
	return enabled and is_instance_valid(game) and game.combat_effects_enabled and not game._application_suspended and ((game.active_screen=='combat' and game.combat_running) or (game.active_screen=='raid' and game.raid_running))
func restore() -> void:
	if deadline_us>0:Engine.time_scale=previous_scale
	deadline_us=0
func _process(_delta: float) -> void:
	if deadline_us<=0:return
	if not _eligible() or Time.get_ticks_usec()>=deadline_us:restore()
func _exit_tree() -> void:restore()
