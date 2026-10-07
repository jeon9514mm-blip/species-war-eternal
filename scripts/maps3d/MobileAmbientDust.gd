extends Control
## 12 groups x four motes in one canvas, synchronized to the field clock.
var field: Control
var clock:=0.0
var _last_focus:=Vector2.ZERO
var _parallax:=Vector2.ZERO
func _process(delta: float) -> void:
	if not is_instance_valid(field) or not is_instance_valid(field.game):return
	visible=field.presentation_visible and field.game.combat_effects_enabled
	if field.visual_running():
		clock+=maxf(0,delta)
		var movement: Vector2=field.focus-_last_focus
		_parallax=(_parallax+movement*field.size.y/field.camera.size*.12).limit_length(12)
		_parallax=_parallax.lerp(Vector2.ZERO,1-exp(-delta*.6))
	_last_focus=field.focus;queue_redraw()
func _draw() -> void:
	if not visible or size.x<1:return
	for group in 12:
		var base:=Vector2((group%4+.5)*size.x/4.0,(group/4+.5)*size.y/3.0)
		for mote in 4:
			var seed:=float(group*4+mote)
			var offset:=Vector2(sin(clock*.23+seed*2.1)*12,cos(clock*.19+seed)*9)
			var point:=base+offset+Vector2(mote*6-9,mote*2)-_parallax*(.6+mote*.15)
			draw_circle(point,1.0+fmod(seed,3)*.25,Color(Color('#d8d5cc'),.07+fmod(seed,4)*.02))
