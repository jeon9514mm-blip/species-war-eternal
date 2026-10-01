extends Node2D
## Read-only cast accent over the existing per-hero skill choreography.
var tint := Color('#e7c783')
var mode := '딜러'
var ultimate := false
var elapsed := 0.0
var duration := .43
var seed_angle := 0.0

func configure(role: String, color: Color, is_ultimate: bool, sequence: int) -> void:
	name='PortraitSkillBurst'
	mode=role;tint=color;ultimate=is_ultimate
	duration=.65 if ultimate else .43
	seed_angle=float(sequence%7)*TAU/7.0
	z_index=81

func _process(delta: float) -> void:
	elapsed+=delta
	if elapsed>=duration:queue_free();return
	queue_redraw()

func _draw() -> void:
	var t:=clampf(elapsed/duration,0.0,1.0)
	var opacity:=1.0-smoothstep(.58,1.0,t)
	var r: float=(29.0 if ultimate else 20.0)*(0.55+1.45*t)
	var ink:=Color(tint,opacity*.82)
	if mode=='탱커':
		# Expanding shield facets.
		for side in 6:
			var a:=seed_angle+float(side)*TAU/6.0
			var p:=Vector2.from_angle(a)*r
			var q:=Vector2.from_angle(a+TAU/6.0)*r
			draw_line(p,q,ink,3.0 if ultimate else 2.2,true)
			draw_line(p*.63,p,Color.WHITE*Color(1,1,1,opacity*.58),1.2,true)
	elif mode=='서포터':
		draw_arc(Vector2.ZERO,r*.72,seed_angle+t*3.0,seed_angle+t*3.0+PI*1.5,32,ink,2.4,true)
		for side in 4:
			var p:=Vector2.from_angle(seed_angle+float(side)*TAU/4.0-t*2.0)*r
			draw_circle(p,2.8*(1.0-t*.55),Color(tint,opacity))
	elif mode=='컨트롤러':
		for side in 4:
			var a:=seed_angle+float(side)*TAU/4.0+t*1.8
			var p:=Vector2.from_angle(a)*r
			var tangent:=Vector2.from_angle(a+PI*.5)*6.0
			draw_line(p-tangent,p+tangent,ink,2.4,true)
			draw_line(p*.55,p,Color(tint,opacity*.44),1.2,true)
	else:
		# Short blade arcs and directional strike marks.
		for side in 3:
			var a:=seed_angle+float(side)*TAU/3.0
			draw_arc(Vector2.ZERO,r, a+t*.7,a+PI*.52+t*.7,18,ink,2.8 if ultimate else 2.0,true)
			draw_line(Vector2.from_angle(a)*r*.38,Vector2.from_angle(a)*r*1.22,Color.WHITE*Color(1,1,1,opacity*.65),1.2,true)
	if ultimate:
		draw_arc(Vector2.ZERO,r*1.15,0,TAU,40,Color(tint,opacity*.44),2.0,true)
