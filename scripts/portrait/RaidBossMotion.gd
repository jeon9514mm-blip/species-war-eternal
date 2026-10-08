extends Node2D
## Vector layers around the existing painted four-pose boss atlas. Feet, crest,
## weapon trails and spell particles animate separately from the body frames.
var actor: Node2D
var zone_id := "gray_meadow"
var accent := Color("#e8ba6b")
var casting := false
var enraged := false
var clock := 0.0
var strike := 0.0
var last_state := "idle"
var decorative_ground_enabled := true

func _process(delta: float) -> void:
	if not is_instance_valid(actor): return
	position = actor.position
	visible = actor.visible and actor.modulate.a > 0.1
	clock += delta
	var state: String = str(actor.get("state"))
	if state == "attack" and last_state != "attack": strike = 1.0
	strike = maxf(0.0, strike - delta * 2.4)
	last_state = state
	queue_redraw()

func _draw() -> void:
	var lit := (0.62 + 0.20 * sin(clock * (6.0 if casting else 2.8))) * (1.5 if enraged else 1.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0 + strike * .12, 1.0))
	if decorative_ground_enabled:
		_paint_ground_oval(Vector2(0,2), Vector2(58,13), Color("#041522",.50))
		draw_arc(Vector2.ZERO, 54.0 + 5.0 * sin(clock * 2.0), 0, TAU, 48, Color(accent,.29 * lit),3.0)
	if zone_id == "gray_meadow":
		for i in 5:
			var angle := clock * .35 + float(i) * TAU / 5.0
			var foot := Vector2.from_angle(angle) * Vector2(49,16)
			draw_line(foot,foot + Vector2(7 * sin(clock * 2.0 + i),-12.0 - 10.0 * lit),Color(accent,.58 * lit),2.5)
			if casting: draw_arc(Vector2(0,-24),76.0 + float(i)*9.0,PI*.15,PI*.85,20,Color(accent,.18),3.0)
	elif zone_id == "forgotten_mine":
		for i in 5:
			var point := Vector2(-52 + i * 25,-28 - (i % 2) * 34 + sin(clock * 2.8 + i)*9)
			draw_colored_polygon(PackedVector2Array([point+Vector2(-7,6),point+Vector2(1,-13),point+Vector2(9,5)]),Color(accent,.25 + .26*lit))
		if casting or strike>0.0:
			draw_arc(Vector2(0,-54),67.0 + 30.0*strike,PI*.84,PI*1.88,36,Color(accent,.55*lit),6.0)
	else:
		for i in 7:
			var angle := clock * .6 + float(i) * TAU / 7.0
			var point := Vector2(49*cos(angle),-57 + 24*sin(angle))
			draw_circle(point,2.5 + 2.0*lit,Color(accent,.43*lit))
		if casting: draw_arc(Vector2(0,-68),69.0,0,TAU,60,Color(accent,.57*lit),4.0)
	if casting:
		for index in 3:
			var radius := 32.0 + fmod(clock * 46.0 + index * 34.0,102.0)
			draw_arc(Vector2(0,-50),radius,PI*.12,PI*.88,35,Color(accent,(1.0-radius/150.0)*.45),2.0)
	if strike>0.0:
		draw_arc(Vector2(-4,-67),120.0 - strike*45.0,PI*.7,PI*1.5,28,Color(accent,strike*.9),6.0)

func _paint_ground_oval(center: Vector2, radius: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for index in 32:
		var angle := TAU * float(index) / 32.0
		points.append(center + Vector2(cos(angle)*radius.x,sin(angle)*radius.y))
	draw_colored_polygon(points,color)
