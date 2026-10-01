extends Control
## Scalable 2D covenant emblem; a tier has its own orbit and colour.
var accent := Color("#8db6b7")
var tier := "고급"
var clock := 0.0

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	custom_minimum_size=Vector2(0,94)

func _process(delta: float) -> void:
	clock+=delta
	queue_redraw()

func _draw() -> void:
	var center:=size*.5
	var radius:=minf(size.y*.39,size.x*.27)
	var level:=maxi(0,["고급","희귀","에픽","전설","신화"].find(tier))
	draw_circle(center,radius*1.18,Color(accent,.07+.015*level))
	draw_arc(center,radius,0,TAU,64,Color(accent,.58),2.0+level*.35)
	draw_arc(center,radius*.78,clock*.32,clock*.32+PI*1.15,48,Color(accent,.88),3.0)
	draw_arc(center,radius*.78,clock*.32+PI*1.3,clock*.32+TAU,35,Color(accent,.46),2.0)
	for index in 6+level*2:
		var angle:=clock*.38+TAU*float(index)/float(6+level*2)
		var point:=center+Vector2(cos(angle),sin(angle))*radius*.92
		draw_circle(point,2.0+level*.19,Color(accent,.60))
	for corner in 4:
		var angle:=PI*.25+float(corner)*PI*.5
		var spoke:=Vector2(cos(angle),sin(angle))
		draw_line(center+spoke*radius*.38,center+spoke*radius*.68,Color(accent,.47),2.0)
	var diamond:=PackedVector2Array([center+Vector2(0,-radius*.37),center+Vector2(radius*.3,0),center+Vector2(0,radius*.37),center+Vector2(-radius*.3,0)])
	draw_colored_polygon(diamond,Color(accent,.35+.08*sin(clock*2.4)))
	draw_polyline(PackedVector2Array([diamond[0],diamond[1],diamond[2],diamond[3],diamond[0]]),Color(accent,.91),2.2)
