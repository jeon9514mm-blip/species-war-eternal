extends RefCounted
## Stable, short label lanes; never move an actor to make a health bar fit.
static func place(anchor: Vector2, bar_size: Vector2, occupied: Array[Rect2], bounds: Rect2) -> Rect2:
	for lane in [0.0, -9.0, 9.0, -18.0, 18.0, -27.0]:
		var rect := Rect2(anchor + Vector2(-bar_size.x * .5, lane), bar_size)
		rect.position.x = clampf(rect.position.x, bounds.position.x, maxf(bounds.position.x, bounds.end.x - bar_size.x))
		rect.position.y = clampf(rect.position.y, bounds.position.y, maxf(bounds.position.y, bounds.end.y - bar_size.y))
		var clear := true
		for used in occupied:
			if rect.grow(2.0).intersects(used):
				clear = false
				break
		if clear:
			return rect
	return Rect2()
