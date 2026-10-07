extends Node
## Explicit user-requested 60ms global slow motion, restored on real wall time.
var game: Node
var enabled:=true
var deadline_us:=0
var cooldown_us:=0
var previous_scale:=1.0
func _ready() -> void:process_mode=Node.PROCESS_MODE_ALWAYS;process_priority=-100
func request() -> void:
	if not enabled or not is_instance_valid(game) or not game.combat_effects_enabled or game._application_suspended:return
	if not ((game.active_screen=='combat' and game.combat_running) or (game.active_screen=='raid' and game.raid_running)):return
	var now:=Time.get_ticks_usec()
	if now<cooldown_us or deadline_us>0:return
	previous_scale=Engine.time_scale;Engine.time_scale=previous_scale*.1;deadline_us=now+60000;cooldown_us=now+160000
func restore() -> void:
	if deadline_us>0:Engine.time_scale=previous_scale
	deadline_us=0
func _process(_delta: float) -> void:
	if deadline_us<=0:return
	if not is_instance_valid(game) or game._application_suspended or not game.combat_effects_enabled or not ((game.active_screen=='combat' and game.combat_running) or (game.active_screen=='raid' and game.raid_running)) or Time.get_ticks_usec()>=deadline_us:restore()
func _exit_tree() -> void:restore()
