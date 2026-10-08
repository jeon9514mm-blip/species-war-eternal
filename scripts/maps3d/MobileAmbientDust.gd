extends Control
## 20 groups x four motes in one canvas, synchronized to the field clock.
const GROUP_COUNT:=20
var field: Control
var clock:=0.0
var _last_focus:=Vector2.ZERO
var _parallax:=Vector2.ZERO
var _motes:=preload('res://scripts/presentation/BatchedMotes.gd').new()
func _process(delta: float) -> void:
	if not is_instance_valid(field) or not is_instance_valid(field.game):return
	visible=field.presentation_visible and field.game.combat_effects_enabled and str(field.game.presentation_options.get('performance','balanced'))!='battery'
	if visible and field.visual_running():
		clock+=maxf(0,delta)
		var movement: Vector2=field.focus-_last_focus
		_parallax=(_parallax+movement*field.size.y/field.camera.size*.12).limit_length(12)
		_parallax=_parallax.lerp(Vector2.ZERO,1-exp(-delta*.6))
	_last_focus=field.focus
	if visible:queue_redraw()
func _draw() -> void:
	if not visible or size.x<1:return
	_motes.begin(GROUP_COUNT*4)
	for group in GROUP_COUNT:
		var base:=Vector2((group%5+.5)*size.x/5.0,(floorf(group/5.0)+.5)*size.y/4.0)
		for mote in 4:
			var seed:=float(group*4+mote)
			var offset:=Vector2(sin(clock*.23+seed*2.1)*12,cos(clock*.19+seed)*9)
			var point:=base+offset+Vector2(mote*6-9,mote*2)-_parallax*(.6+mote*.15)
			_motes.add(point,1.0+fmod(seed,3)*.25,Color(Color('#d8d5cc'),.07+fmod(seed,4)*.02))
	_motes.draw(self)
