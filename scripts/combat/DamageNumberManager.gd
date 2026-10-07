extends Node
## Reserve the complete motion and pool labels. Coalesce exact rapid-hit totals.
const LABEL = preload('res://scripts/portrait/PortraitDamageNumber.gd')
const STYLE = preload('res://scripts/combat/CombatNumberStyle.gd')
const CAPACITY = 40
var pool: Array[Label] = []
static func placement(origin: Vector2, extent: Vector2, occupied: Array[Rect2], bounds: Rect2, lane: int) -> Rect2:
	var reserve_size := extent + Vector2(12, 32)
	for row in 6:
		for offset in [0, -1, 1, -2, 2]:
			var column: int = int(offset) * (-1 if lane % 2 == 0 else 1)
			var center := origin + Vector2(column * (reserve_size.x + 6), -row * (reserve_size.y + 4))
			var rect := Rect2(center - reserve_size * .5, reserve_size)
			if bounds.has_area():
				if bounds.size.x < reserve_size.x or bounds.size.y < reserve_size.y: return Rect2()
				rect.position = rect.position.clamp(bounds.position, bounds.end - reserve_size)
				if not bounds.encloses(rect): continue
			var clear := true
			for used in occupied:
				if rect.grow(3).intersects(used): clear = false; break
			if clear: return rect
	return Rect2()
func spawn_damage(message: String, tint: Color, origin: Vector2, critical: bool, lane: int, bounds := Rect2(), kind := 'damage', anchor_key := '', numeric_amount := -1) -> Label:
	for i in range(pool.size()-1, -1, -1):
		if not is_instance_valid(pool[i]): pool.remove_at(i)
	if critical: kind = 'critical'
	var label: Label
	var now := Time.get_ticks_msec()
	if not anchor_key.is_empty() and numeric_amount >= 0:
		for candidate in pool:
			if candidate.visible and candidate.anchor_key == anchor_key and candidate.kind == kind and now - candidate.burst_started_at <= 120:
				label = candidate; numeric_amount += candidate.amount; break
	var occupied: Array[Rect2] = []
	for candidate in pool:
		if candidate != label and candidate.visible: occupied.append(candidate.reserved_rect)
	var displayed := STYLE.caption(numeric_amount, kind) if numeric_amount >= 0 else message
	var reserve := placement(origin, STYLE.extent(displayed, kind), occupied, bounds, lane)
	if not reserve.has_area(): return null
	if label == null:
		for candidate in pool:
			if not candidate.visible: label = candidate; break
	if label == null:
		if pool.size() >= CAPACITY: return null
		label = LABEL.new(); label.pooled = true; add_child(label); pool.append(label)
	var combined: bool = label.visible and label.anchor_key == anchor_key and label.amount > 0
	label.kind = kind; label.anchor_key = anchor_key; label.amount = numeric_amount
	label.burst_hits = label.burst_hits + 1 if combined else 1
	if not combined: label.burst_started_at = now
	label.show_value(displayed, tint, reserve.get_center() + Vector2(0, 8), critical, lane)
	label.reserved_rect = reserve
	return label
