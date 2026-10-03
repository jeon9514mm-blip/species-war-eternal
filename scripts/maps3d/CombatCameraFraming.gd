extends RefCounted
## Camera-only framing. Points encode (world x, billboard height, world z).
## The simulation, formation spacing and movement bounds are never modified.
const MINIMUM_SPAN := Vector2(24.0, 17.0)
const PADDING := Vector2(2.4, 1.8)

static func fit(points: Array[Vector3], viewport_size: Vector2, pitch_sine: float) -> Dictionary:
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	var sine := maxf(.1, absf(pitch_sine))
	for point in points:
		var plane := Vector2(point.x, point.z * sine - point.y)
		low = low.min(plane)
		high = high.max(plane)
	if points.is_empty():
		low = Vector2(16, 10 * sine) - MINIMUM_SPAN * .5
		high = low + MINIMUM_SPAN
	var center := (low + high) * .5
	var span := (high - low + PADDING * 2.0).max(MINIMUM_SPAN)
	var bounds := Rect2(center - span * .5, span)
	var aspect := maxf(.1, viewport_size.x / maxf(1, viewport_size.y))
	return {"center": Vector2(center.x, center.y / sine), "bounds": bounds,
		"size": maxf(span.y, span.x / aspect)}

static func size_at_center(bounds: Rect2, center: Vector2, viewport_size: Vector2, pitch_sine: float) -> float:
	var plane := Vector2(center.x, center.y * absf(pitch_sine))
	var half_span := (bounds.position - plane).abs().max((bounds.end - plane).abs())
	var aspect := maxf(.1, viewport_size.x / maxf(1, viewport_size.y))
	return maxf(half_span.y, half_span.x / aspect) * 2.0
