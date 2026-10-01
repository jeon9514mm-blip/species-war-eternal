extends Node2D
## A compact visual reward that appears only after an actual monster kill.
var elapsed := 0.0
var duration := .68

func _process(delta: float) -> void:
	elapsed+=delta
	if elapsed>=duration:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var t: float=clampf(elapsed/duration,0.0,1.0)
	var alpha: float=1.0-t
	for index in 7:
		var angle: float=float(index)*TAU/7.0-.8
		var reach: float=9.0+24.0*t
		var point:=Vector2(cos(angle),sin(angle))*reach+Vector2(0,-24.0*t)
		var color:=Color('#fadb5c') if index%2==0 else Color('#72e9f0')
		draw_circle(point,3.8*(1.0-.48*t),Color(color,alpha))
		draw_line(point-Vector2(2,2),point+Vector2(2,2),Color.WHITE*Color(1,1,1,alpha*.7),1.5)
