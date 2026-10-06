extends RefCounted
## v16 motion translated from pixels to world metres. Never moves combat bodies.
static func pose(source: AnimatedSprite2D, hero: bool, facing: Vector2, clock: float) -> Dictionary:
	var phase:=float(posmod(str(source.name).hash(),1000))*.013
	var age: float=source.visual_state_time
	var offset:=Vector3.ZERO;var shape:=Vector2.ONE;var roll:=0.0
	match source.state:
		'idle':
			offset.y=sin(clock*2.42+phase)*.012
			offset.x=sin(clock*.68+phase)*.010
			shape.y=1.0+sin(clock*1.18+phase)*.012
		'walk':
			offset.y=absf(sin(age*8.5+phase))*.045
			roll=-facing.x*.025
		'attack':
			var duration: float=maxf(.12,source.visual_attack_duration) if hero else .30
			var hit:=duration*.44 if hero else .098
			var strike:=smoothstep(0,hit,age)*(1.0-smoothstep(hit,duration,age))
			var reach:=.52 if hero and bool(source.get_meta('v16_skill_motion',false)) else (.38 if hero else .32)
			offset=Vector3(facing.x,0,facing.y)*strike*reach
			shape=Vector2(1+strike*.16,1-strike*.12)
		'hit':
			var reaction:=sin(clampf(age/.22,0,1)*PI)
			offset=-Vector3(facing.x,0,facing.y)*reaction*(.17 if hero else .20)
			offset.x+=sin(age*90)*reaction*.025
			roll=sin(age*55)*reaction*.035
		'death':
			var fall:=smoothstep(0,.32,age)
			offset.y=-fall*.12;roll=fall*.20
	return {'offset':offset,'shape':shape,'roll':roll}
