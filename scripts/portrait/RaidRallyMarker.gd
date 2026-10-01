extends Node2D

var clock := 0.0

func _process(delta: float) -> void:
	if not visible:return
	clock += delta
	queue_redraw()

func _draw() -> void:
	var radius := 17.0 + 3.0 * sin(clock * 7.0)
	draw_circle(Vector2.ZERO,7.0,Color('#8ceacf',.28))
	draw_arc(Vector2.ZERO,radius,0,TAU,36,Color('#b5ffe2',.80),2.5)
	for i in 4:
		var direction := Vector2.RIGHT.rotated(PI*.25+float(i)*PI*.5)
		draw_line(direction*11.0,direction*radius,Color('#ccffe5',.8),2.0)
