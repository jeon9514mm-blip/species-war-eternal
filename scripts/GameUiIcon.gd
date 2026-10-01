extends Control
class_name GameUiIcon

## Small, resolution-independent navigation icons. All paths share a 24-unit grid.
var icon_name: String = "home":
	set(value):
		icon_name = value
		queue_redraw()
var ink: Color = Color("#254239"):
	set(value):
		ink = value
		queue_redraw()

const STROKE := 1.7

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _line(points: Array, width: float = STROKE) -> void:
	draw_polyline(PackedVector2Array(points), ink, width, true)

func _circle(center: Vector2, radius: float, filled: bool = false) -> void:
	draw_circle(center, radius, ink, filled, -1.0 if filled else STROKE, true)

func _arc(center: Vector2, radius: float, start: float, finish: float) -> void:
	draw_arc(center, radius, start, finish, 24, ink, STROKE, true)

func _draw() -> void:
	var scale_factor := minf(size.x, size.y) / 24.0
	if scale_factor <= 0.0:
		return
	draw_set_transform((size - Vector2.ONE * 24.0 * scale_factor) * 0.5, 0.0, Vector2.ONE * scale_factor)
	match icon_name:
		"home", "hub":
			_line([Vector2(3, 10.5), Vector2(12, 3), Vector2(21, 10.5)])
			_line([Vector2(5, 9), Vector2(5, 20), Vector2(10, 20), Vector2(10, 14), Vector2(14, 14), Vector2(14, 20), Vector2(19, 20), Vector2(19, 9)])
		"hero", "heroes", "party", "profile":
			_circle(Vector2(12, 7.5), 3.5)
			_arc(Vector2(12, 20), 7.0, PI, TAU)
			_line([Vector2(5, 20), Vector2(19, 20)])
			_line([Vector2(8.8, 3.7), Vector2(9.5, 1.8), Vector2(12, 3.3), Vector2(14.5, 1.8), Vector2(15.2, 3.7)], 1.3)
		"growth", "upgrade":
			_line([Vector2(5, 20), Vector2(5, 15), Vector2(8, 15), Vector2(8, 20)])
			_line([Vector2(11, 20), Vector2(11, 11), Vector2(14, 11), Vector2(14, 20)])
			_line([Vector2(17, 20), Vector2(17, 7), Vector2(20, 7), Vector2(20, 20)])
			_line([Vector2(4, 10), Vector2(11, 5), Vector2(17, 3)])
			_line([Vector2(13.5, 2.5), Vector2(18, 2.5), Vector2(17.4, 6.5)])
		"bag", "inventory":
			_line([Vector2(5, 8), Vector2(19, 8), Vector2(20, 20), Vector2(4, 20), Vector2(5, 8)])
			_arc(Vector2(12, 8), 4, PI, TAU)
			_line([Vector2(8, 12), Vector2(8, 13)])
			_line([Vector2(16, 12), Vector2(16, 13)])
			_arc(Vector2(12, 13), 4, 0.15, PI - 0.15)
		"compass", "world", "explore":
			_circle(Vector2(12, 12), 9)
			_line([Vector2(15.6, 7.2), Vector2(13.2, 13.4), Vector2(8.4, 16.8), Vector2(10.8, 10.6), Vector2(15.6, 7.2)])
			_line([Vector2(10.8, 10.6), Vector2(13.2, 13.4)], 1.3)
		"summon", "star", "sparkle":
			_line([Vector2(11, 3), Vector2(13.5, 9), Vector2(20, 11), Vector2(13.5, 13.5), Vector2(11, 20), Vector2(8.5, 13.5), Vector2(2, 11), Vector2(8.5, 9), Vector2(11, 3)])
			_line([Vector2(19, 2), Vector2(19, 6)], 1.3)
			_line([Vector2(17, 4), Vector2(21, 4)], 1.3)
		"settings":
			_circle(Vector2(12, 12), 6)
			_circle(Vector2(12, 12), 2.2)
			for index in range(8):
				var direction := Vector2.from_angle(TAU * float(index) / 8.0)
				_line([Vector2(12, 12) + direction * 7, Vector2(12, 12) + direction * 9.5], 2.4)
		"mail", "inbox":
			_line([Vector2(3, 6), Vector2(21, 6), Vector2(21, 18), Vector2(3, 18), Vector2(3, 6)])
			_line([Vector2(3, 7), Vector2(12, 13), Vector2(21, 7)])
		"quest", "journal":
			_line([Vector2(7, 3), Vector2(20, 3), Vector2(20, 19), Vector2(7, 19), Vector2(7, 3)])
			_line([Vector2(7, 6), Vector2(4, 6), Vector2(4, 21), Vector2(17, 21), Vector2(17, 19)])
			_line([Vector2(10, 8), Vector2(17, 8)])
			_line([Vector2(10, 12), Vector2(17, 12)])
			_line([Vector2(10, 16), Vector2(14, 16)])
		"sword", "battle", "war":
			_line([Vector2(8, 15), Vector2(17, 4), Vector2(21, 3), Vector2(20, 7), Vector2(10, 17)])
			_line([Vector2(6, 13), Vector2(12, 19)], 2)
			_line([Vector2(8, 17), Vector2(4, 21)], 2.5)
			_line([Vector2(3, 19), Vector2(5, 21)], 2)
		"shield", "guard":
			_line([Vector2(12, 3), Vector2(20, 6), Vector2(19, 14), Vector2(16, 18), Vector2(12, 21), Vector2(8, 18), Vector2(5, 14), Vector2(4, 6), Vector2(12, 3)])
			_line([Vector2(12, 7), Vector2(12, 16)])
			_line([Vector2(8, 11), Vector2(16, 11)])
		"coin", "gold":
			_circle(Vector2(12, 12), 9)
			_circle(Vector2(12, 12), 6)
			_line([Vector2(12, 7), Vector2(15, 12), Vector2(12, 17), Vector2(9, 12), Vector2(12, 7)], 1.3)
		"gem", "diamond":
			_line([Vector2(6, 4), Vector2(18, 4), Vector2(22, 9), Vector2(12, 21), Vector2(2, 9), Vector2(6, 4)])
			_line([Vector2(2, 9), Vector2(22, 9)])
			_line([Vector2(8, 4), Vector2(7, 9), Vector2(12, 21), Vector2(17, 9), Vector2(16, 4)], 1.2)
		"back", "chevron_left":
			_line([Vector2(14, 5), Vector2(7, 12), Vector2(14, 19)], 2)
		"next", "chevron_right":
			_line([Vector2(9, 5), Vector2(16, 12), Vector2(9, 19)], 2)
		"close":
			_line([Vector2(6, 6), Vector2(18, 18)], 2)
			_line([Vector2(18, 6), Vector2(6, 18)], 2)
		"check":
			_line([Vector2(4, 12), Vector2(9, 17), Vector2(20, 6)], 2.2)
		"lock":
			_arc(Vector2(12, 9), 4, PI, TAU)
			_line([Vector2(8, 9), Vector2(8, 11)])
			_line([Vector2(16, 9), Vector2(16, 11)])
			_line([Vector2(5, 11), Vector2(19, 11), Vector2(19, 21), Vector2(5, 21), Vector2(5, 11)])
			_circle(Vector2(12, 15), 1, true)
			_line([Vector2(12, 15), Vector2(12, 18)], 1.5)
		"leaf", "nature":
			_line([Vector2(4, 20), Vector2(15.5, 8.5)])
			_line([Vector2(6, 16), Vector2(5, 11), Vector2(8, 6), Vector2(13, 4), Vector2(21, 3), Vector2(20, 11), Vector2(18, 16), Vector2(13, 19), Vector2(8, 18), Vector2(6, 16)])
			_line([Vector2(10, 14), Vector2(9, 10)], 1.3)
			_line([Vector2(12, 12), Vector2(16, 13)], 1.3)
		"moon":
			_arc(Vector2(12, 12), 9, 0.1, TAU - 1.9)
			_arc(Vector2(17, 8), 8, 1.08, 4.55)
		"sun":
			_circle(Vector2(12, 12), 4)
			for index in range(8):
				var direction := Vector2.from_angle(TAU * float(index) / 8.0)
				_line([Vector2(12, 12) + direction * 7, Vector2(12, 12) + direction * 9.5])
		"sound", "audio":
			_line([Vector2(3, 9), Vector2(7, 9), Vector2(12, 5), Vector2(12, 19), Vector2(7, 15), Vector2(3, 15), Vector2(3, 9)])
			_arc(Vector2(12, 12), 5, -0.8, 0.8)
			_arc(Vector2(12, 12), 9, -0.8, 0.8)
		"gift", "reward":
			_line([Vector2(3, 9), Vector2(21, 9), Vector2(21, 13), Vector2(3, 13), Vector2(3, 9)])
			_line([Vector2(5, 13), Vector2(5, 21), Vector2(19, 21), Vector2(19, 13)])
			_line([Vector2(12, 9), Vector2(12, 21)])
			_circle(Vector2(8.5, 6), 3)
			_circle(Vector2(15.5, 6), 3)
		"play":
			_line([Vector2(7, 4), Vector2(20, 12), Vector2(7, 20), Vector2(7, 4)])
		"pause":
			_line([Vector2(8, 5), Vector2(8, 19)], 3)
			_line([Vector2(16, 5), Vector2(16, 19)], 3)
		"plus":
			_line([Vector2(5, 12), Vector2(19, 12)], 2)
			_line([Vector2(12, 5), Vector2(12, 19)], 2)
		"info", "help":
			_circle(Vector2(12, 12), 9)
			_circle(Vector2(12, 7.5), 1, true)
			_line([Vector2(12, 11), Vector2(12, 17)], 2)
		_:
			_circle(Vector2(12, 12), 7)
	draw_set_transform(Vector2.ZERO)
