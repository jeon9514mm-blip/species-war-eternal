extends Control
## Original small colored icons, not copied from the reference game.
var kind := 'battle'
const OUT := Color('#222033')
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
func polygon(points: Array, fill: Color) -> void:
	var pts := PackedVector2Array(points)
	draw_colored_polygon(pts, fill)
	pts.append(pts[0])
	draw_polyline(pts, OUT, 2.6, true)
func _draw() -> void:
	var s := minf(size.x, size.y) / 64.0
	draw_set_transform((size - Vector2.ONE * 64*s)/2.0, 0.0, Vector2.ONE*s)
	match kind:
		'gem', 'summon':
			if kind == 'summon':
				polygon([Vector2(8,44),Vector2(56,44),Vector2(51,59),Vector2(13,59)],Color('#d89937'))
			polygon([Vector2(14,8),Vector2(50,8),Vector2(60,22),Vector2(32,52),Vector2(4,22)],Color('#36ccf9'))
			polygon([Vector2(14,8),Vector2(50,8),Vector2(44,22),Vector2(20,22)],Color('#a3f6ff'))
			polygon([Vector2(20,22),Vector2(44,22),Vector2(32,52)],Color('#22a9eb'))
		'coin':
			draw_circle(Vector2(32,32),28,OUT)
			draw_circle(Vector2(32,32),25,Color('#d78317'))
			draw_circle(Vector2(32,30),21,Color('#ffd643'))
			var pts: Array = []
			for i in 10:
				pts.append(Vector2(32,30)+Vector2.from_angle(-PI/2+PI*i/5)*(15 if i%2==0 else 7))
			polygon(pts,Color('#ffe785'))
		'bag':
			draw_style_box(_style(Color('#84523d')),Rect2(12,15,40,44))
			polygon([Vector2(12,18),Vector2(52,18),Vector2(48,38),Vector2(32,45),Vector2(16,38)],Color('#b38156'))
			draw_arc(Vector2(32,18),12,PI,TAU,20,Color('#e9d49c'),5,true)
			draw_style_box(_style(Color('#edcf81')),Rect2(25,31,14,13))
		'growth':
			polygon([Vector2(12,38),Vector2(4,25),Vector2(32,2),Vector2(60,25),Vector2(49,25),Vector2(49,52),Vector2(16,52),Vector2(16,38)],Color('#eac258'))
			polygon([Vector2(16,54),Vector2(48,54),Vector2(51,61),Vector2(13,61)],Color('#a47f49'))
		'heroes', 'war':
			polygon([Vector2(8,12),Vector2(32,3),Vector2(56,12),Vector2(51,42),Vector2(32,59),Vector2(13,42)],Color('#dfbc6e'))
			polygon([Vector2(15,17),Vector2(32,11),Vector2(49,17),Vector2(45,37),Vector2(32,50),Vector2(19,37)],Color('#6595d5') if kind=='heroes' else Color('#aa617b'))
			draw_line(Vector2(32,18),Vector2(32,42),Color('#f7e7b5'),5,true)
			draw_line(Vector2(22,28),Vector2(42,28),Color('#f7e7b5'),4,true)
		'content', 'quest':
			polygon([Vector2(12,6),Vector2(50,9),Vector2(54,54),Vector2(9,57)],Color('#ffe1a3'))
			draw_polyline(PackedVector2Array([Vector2(17,19),Vector2(30,15),Vector2(44,24),Vector2(28,36),Vector2(39,45)]),Color('#ad8657'),4,true)
			draw_circle(Vector2(30,34),6,Color('#e87960'))
		'lock':
			draw_arc(Vector2(32,26),13,PI,TAU,24,OUT,9,true)
			draw_arc(Vector2(32,26),13,PI,TAU,24,Color('#9cadca'),4,true)
			draw_style_box(_style(Color('#838eb1')),Rect2(13,24,38,31))
			draw_circle(Vector2(32,37),4,OUT)
			draw_line(Vector2(32,38),Vector2(32,46),OUT,4,true)
		'menu':
			for y in 2:
				for x in 2:
					draw_style_box(_style(Color('#fffbed')),Rect2(7+x*28,7+y*28,22,22))
		'auto':
			draw_arc(Vector2(32,32),23,0.3,5.5,40,Color('#dfd8ff'),5,true)
			polygon([Vector2(56,18),Vector2(52,34),Vector2(43,24)],Color('#dfd8ff'))
			polygon([Vector2(24,22),Vector2(24,42),Vector2(40,32)],Color('#fff0ac'))
		_:
			for flip in [-1,1]:
				var pts: Array = []
				for p: Vector2 in [Vector2(9,4),Vector2(22,8),Vector2(50,42),Vector2(43,49),Vector2(13,19)]: pts.append(Vector2(32+(p.x-32)*flip,p.y))
				polygon(pts,Color('#c6e5ed'))
				draw_line(Vector2(32+(36-32)*flip,43),Vector2(32+(49-32)*flip,32),Color('#ecbf4e'),6,true)
				draw_line(Vector2(32+(44-32)*flip,43),Vector2(32+(55-32)*flip,55),Color('#a77e44'),7,true)
	draw_set_transform(Vector2.ZERO)
func _style(color: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color=color; s.border_color=OUT; s.set_border_width_all(3); s.set_corner_radius_all(5)
	return s
