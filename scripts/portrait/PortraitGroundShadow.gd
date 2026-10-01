extends Node2D
## A small ground contact shadow keeps animated art attached to the terrain.
var radius := 19.0

func _draw() -> void:
	draw_set_transform(Vector2(0,2),0.0,Vector2(1.0,.35))
	draw_circle(Vector2.ZERO,radius,Color('#102f2990'))
	draw_circle(Vector2.ZERO,radius*.72,Color('#06251d53'))
