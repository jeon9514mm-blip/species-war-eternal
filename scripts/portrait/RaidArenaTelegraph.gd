extends Control
## World-space attack footprints. The simulated cast timer drives the fill so
## the warning lands on the exact frame that the boss attack resolves.
var active := false
var kind := ''
var shape: Dictionary = {}
var progress := 0.0
var accent := Color('#ffd78b')
var targets: Array[Vector2] = []
var clock := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	if not active:return
	clock += delta
	queue_redraw()

func _draw() -> void:
	if not active or shape.is_empty():return
	var glow := .10 + .07 * progress
	var warning:=Color('#ffba69').lerp(Color('#ff626f'),smoothstep(.65,1.0,progress))
	var edge := Color(warning,.9 + .1 * sin(clock * 8.0))
	var fill := Color(accent,glow)
	match str(shape.get('shape','')):
		'lane':
			_draw_warning_rect(shape['rect'],fill,edge)
		'rects':
			for rect_value in shape.get('rects',[]):
				_draw_warning_rect(rect_value as Rect2,fill,edge)
		'cone':
			var origin: Vector2=shape['origin']
			var direction: Vector2=shape['direction']
			var radius: float=float(shape['radius'])
			var half_angle: float=float(shape['half_angle'])
			var points:=PackedVector2Array([origin])
			var base_angle:=direction.angle()
			for i in 25:
				var angle:=lerpf(base_angle-half_angle,base_angle+half_angle,float(i)/24.0)
				points.append(origin+Vector2.from_angle(angle)*radius)
			draw_colored_polygon(points,fill)
			draw_polyline(points,Color('#101823'),10.0,true)
			draw_polyline(points,edge,5.0,true)
			if points.size()>2:
				draw_line(origin,points[1],edge,5.0)
				draw_line(origin,points[points.size()-1],edge,5.0)
		'marks':
			for point: Vector2 in shape['centers']:
				draw_circle(point,float(shape['radius']),fill)
				draw_arc(point,float(shape['radius']),0,TAU,48,Color('#101823'),11.0,true)
				draw_arc(point,float(shape['radius']),0,TAU,48,edge,5.0)
				draw_line(point-Vector2(10,0),point+Vector2(10,0),edge,4.0,true)
				draw_line(point-Vector2(0,10),point+Vector2(0,10),edge,4.0,true)
		'ring':
			var center: Vector2=shape['center']
			var inner: float=shape['inner']
			var outer: float=shape['outer']
			draw_arc(center,(inner+outer)*.5,0,TAU,100,Color(accent,glow),outer-inner)
			draw_arc(center,inner,0,TAU,100,Color('#101823'),11.0,true)
			draw_arc(center,outer,0,TAU,100,Color('#101823'),11.0,true)
			draw_arc(center,inner,0,TAU,100,edge,5.0)
			draw_arc(center,outer,0,TAU,100,edge,5.0)
		'circle':
			var center: Vector2=shape['center']
			var radius: float=shape['radius']
			draw_circle(center,radius,fill)
			draw_arc(center,radius,0,TAU,100,Color('#101823'),12.0,true)
			draw_arc(center,radius,0,TAU,100,edge,6.0)
	if progress>0.0 and str(shape.get('shape','')) in ['ring','circle']:
		var center: Vector2=shape['center']
		var radius: float=float(shape['outer'] if shape['shape']=='ring' else shape['radius'])
		draw_arc(center,radius*(1.0-progress),0,TAU,80,Color(accent,.5),3.0)


func _draw_warning_rect(rect: Rect2, fill: Color, edge: Color) -> void:
	draw_rect(rect,fill)
	draw_rect(rect,Color('#101823'),false,11.0)
	draw_rect(rect,edge,false,5.0)
	var stripe_count := maxi(2,int(rect.size.x/34.0)) if rect.size.x < rect.size.y else maxi(2,int(rect.size.y/34.0))
	for i in stripe_count:
		if rect.size.x < rect.size.y:
			var y := rect.position.y + 12.0 + float(i) * rect.size.y / float(stripe_count)
			draw_line(Vector2(rect.position.x+6.0,y),Vector2(rect.end.x-6.0,y+18.0),edge,2.5)
		else:
			var x := rect.position.x + 12.0 + float(i) * rect.size.x / float(stripe_count)
			draw_line(Vector2(x,rect.position.y+6.0),Vector2(x+18.0,rect.end.y-6.0),edge,2.5)
