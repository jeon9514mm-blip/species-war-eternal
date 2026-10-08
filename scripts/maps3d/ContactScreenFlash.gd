extends Control
## A short bounded gold contact flash over the battlefield, not its controls.
var field: Control
var deadline_us:=0
var cooldown_us:=0
var duration_us:=50000
func _ready() -> void:mouse_filter=Control.MOUSE_FILTER_IGNORE;z_index=90
func flash() -> void:
	var now:=Time.get_ticks_usec()
	if now<cooldown_us or not is_instance_valid(field) or not field.game.combat_effects_enabled:return
	deadline_us=now+duration_us;cooldown_us=now+1500000;queue_redraw()
func _process(_delta: float) -> void:
	if deadline_us<=0:return
	if not is_instance_valid(field) or not field.battle_clock_running() or not field.game.combat_effects_enabled or Time.get_ticks_usec()>=deadline_us:deadline_us=0
	queue_redraw()
func _draw() -> void:
	var remaining:=deadline_us-Time.get_ticks_usec()
	if remaining<=0:return
	var fade:=float(remaining)/duration_us
	draw_rect(Rect2(Vector2.ZERO,size),Color(1,.92,.58,fade*.12))
