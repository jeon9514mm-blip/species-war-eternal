extends "res://scripts/MapTerrainRenderer.gd"
## One world-space source of truth for painted ground, paths and collision shores.
## All shape construction is cached per zone; camera motion only changes a transform.
const TERRAIN := preload('res://scripts/FieldTerrainCatalog.gd')
const CASUAL_ART := {
	'gray_meadow': preload('res://assets/terrain-v70/evergreen-meadow.png'),
	'forgotten_mine': preload('res://assets/terrain-v70/crimson-canyon.png'),
	'moonrest_forest': preload('res://assets/terrain-v70/arcane-sanctuary.png'),
}
const AMBIENT_INTERVAL: float = 0.08
var _shapes: Array[Dictionary] = []
var _lines: Array[Dictionary] = []
var _ponds: Array = []
var _motes: Array[Vector3] = []
var _palette: Dictionary = {}
var _unit_ring: PackedVector2Array = PackedVector2Array()
var _cached_zone: String = ''

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_load_ground()
	_cache_geometry()

func _process(delta: float) -> void:
	elapsed += delta
	redraw_accumulator += delta
	if redraw_accumulator >= AMBIENT_INTERVAL:
		redraw_accumulator = fmod(redraw_accumulator, AMBIENT_INTERVAL)
		queue_redraw()

func configure(next_zone_id: String, next_zone_color: Color) -> void:
	super.configure(next_zone_id, next_zone_color)
	_load_ground()
	_cache_geometry()
	queue_redraw()

func _load_ground() -> void:
	field_texture = CASUAL_ART.get(zone_id, CASUAL_ART['gray_meadow']) as Texture2D

func art_world_rect() -> Rect2:
	return TERRAIN.ART_RECT

func source_rect_for_world(world_rect: Rect2) -> Rect2:
	if not is_instance_valid(field_texture):
		return Rect2()
	var art: Rect2 = art_world_rect()
	var pixels: Vector2 = field_texture.get_size() / art.size
	return Rect2((world_rect.position - art.position) * pixels, world_rect.size * pixels)

func _draw() -> void:
	if _cached_zone != zone_id:
		_cache_geometry()
	var ground: Color = _palette.get('ground', Color('#83a56c'))
	draw_rect(Rect2(Vector2.ZERO, size), ground)
	var visible: Rect2 = visible_world_rect()
	if is_instance_valid(field_texture):
		var region: Rect2 = visible.intersection(art_world_rect())
		if region.has_area():
			draw_texture_rect_region(field_texture, Rect2(_map_point(region.position), region.size * pixels_per_unit), source_rect_for_world(region))
	# Keep cached vertices in world units: no per-draw polygon copies on mobile.
	draw_set_transform(_map_point(Vector2.ZERO), 0.0, Vector2.ONE * pixels_per_unit)
	var padded: Rect2 = visible.grow(0.6)
	for shape in _shapes:
		if padded.intersects(shape['bounds']):
			draw_colored_polygon(shape['points'], shape['color'])
	for line in _lines:
		if padded.intersects(line['bounds']):
			draw_polyline(line['points'], line['color'], float(line['width']), true)
	_draw_ambient(padded)
	draw_set_transform(Vector2.ZERO)

func _cache_geometry() -> void:
	if _cached_zone == zone_id:
		return
	_cached_zone = zone_id
	_palette = TERRAIN.palette(zone_id)
	_shapes.clear()
	_lines.clear()
	_ponds.clear()
	_motes.clear()
	_unit_ring = PackedVector2Array()
	for index in range(49):
		var angle: float = float(index) / 48.0 * TAU
		_unit_ring.append(Vector2(cos(angle), sin(angle)))
	# v70: the generated background is the finished ground painting. Navigation
	# still uses FieldTerrainCatalog, but legacy synthetic path/footprint paint is disabled.
	_cache_ambient()

func _cache_clearings() -> void:
	var ground: Color = _palette['ground']
	var path_color: Color = _palette['path']
	var index: int = 0
	for clearing in TERRAIN.clearings(zone_id):
		var center: Vector2 = clearing[0]
		var radii: Vector2 = clearing[1]
		# Wide, quiet combat spaces. Each soft layer fades into the painted ground.
		for step in range(6):
			var fraction: float = float(step) / 5.0
			var shade: Color = ground.lerp(path_color, 0.36)
			shade.a = 0.018 + fraction * 0.014
			_add_shape(_ellipse(center, radii * (1.12 - fraction * 0.18), 64, float(index) * 0.6, 0.022), shade)
		index += 1

func _cache_paths() -> void:
	var path_color: Color = _palette['path']
	var edge_color: Color = _palette['path_edge']
	var path_index: int = 0
	for route in TERRAIN.paths(zone_id):
		var controls: PackedVector2Array = route['points']
		var smooth: PackedVector2Array = _smooth_route(controls)
		var width: float = float(route['width'])
		# Adjacent layered margins soften terrain transitions without square tiles.
		for step in range(5):
			var fraction: float = float(step) / 4.0
			var edge: Color = edge_color.lerp(path_color, fraction * 0.75)
			edge.a = 0.035 + fraction * 0.025
			_add_shape(_ribbon(smooth, width + 0.66 - fraction * 0.5), edge)
		var core: Color = path_color
		core.a = 0.36 if zone_id == 'forgotten_mine' else 0.30
		_add_shape(_ribbon(smooth, width), core)
		var middle: Color = path_color.lightened(0.035)
		middle.a = 0.09
		_add_shape(_ribbon(smooth, width * 0.72), middle)
		# Small irregular ground flecks restore texture above the translucent route.
		for sample in range(2, smooth.size() - 2, 4):
			var tangent: Vector2 = (smooth[sample + 1] - smooth[sample - 1]).normalized()
			var normal: Vector2 = Vector2(-tangent.y, tangent.x)
			var side: float = sin(float(sample * 3 + path_index * 7)) * width * 0.31
			var position: Vector2 = smooth[sample] + normal * side
			var shade: Color = path_color.darkened(0.17)
			shade.a = 0.14
			_add_shape(_ellipse(position, Vector2(0.075, 0.034), 7, float(sample), 0.16), shade)
		if zone_id == 'forgotten_mine' and path_index == 0:
			_cache_rails(smooth)
		path_index += 1

func _cache_rails(route: PackedVector2Array) -> void:
	var left: PackedVector2Array = PackedVector2Array()
	var right: PackedVector2Array = PackedVector2Array()
	var distance: float = 0.0
	var next_tie: float = 0.0
	for index in range(route.size()):
		var previous: Vector2 = route[maxi(0, index - 1)]
		var following: Vector2 = route[mini(route.size() - 1, index + 1)]
		var normal: Vector2 = (following - previous).normalized().orthogonal()
		left.append(route[index] + normal * 0.19)
		right.append(route[index] - normal * 0.19)
		if index > 0:
			distance += route[index].distance_to(previous)
		if distance >= next_tie:
			_add_line(PackedVector2Array([route[index] - normal * 0.3, route[index] + normal * 0.3]), Color('#6b615463'), 0.075)
			next_tie = distance + 0.42
	_add_line(left, Color('#403f4564'), 0.065)
	_add_line(right, Color('#403f4564'), 0.065)
	_add_line(left, Color('#b3b8b16b'), 0.02)
	_add_line(right, Color('#b3b8b16b'), 0.02)

func _cache_ground_details() -> void:
	var ground: Color = _palette['ground']
	# A fixed integer sequence avoids gameplay RNG and survives screen rebuilds.
	for index in range(115):
		var center: Vector2 = Vector2(fposmod(float(index * 47 + 13) * 0.317, 48.0) - 8.0, fposmod(float(index * 31 + 9) * 0.413, 36.0) - 8.0)
		if _inside_pond(center, 1.15):
			continue
		var phase: float = float(index) * 2.39996
		if zone_id == 'forgotten_mine':
			var shard: PackedVector2Array = PackedVector2Array([center + Vector2(-0.10, 0.015), center + Vector2(0.02, -0.035), center + Vector2(0.16, 0.025), center + Vector2(0.01, 0.065)])
			var shade: Color = ground.lightened(0.20)
			shade.a = 0.19
			_add_shape(shard, shade)
		else:
			var shade: Color = ground.darkened(0.28)
			shade.a = 0.19
			var blade: PackedVector2Array = PackedVector2Array([center + Vector2(-0.10, 0.07), center + Vector2(-0.11, -0.04), center + Vector2(0.0, 0.04), center + Vector2(0.06, -0.10), center + Vector2(0.1, 0.05)])
			_add_line(blade, shade, 0.021)
			if index % 4 == 0:
				var petal: Color = Color('#f5e1ae') if zone_id == 'gray_meadow' else Color('#80c9c6')
				petal.a = 0.32
				_add_shape(_ellipse(center + Vector2(cos(phase), sin(phase)) * 0.1, Vector2(0.048, 0.025), 6, phase, 0.0), petal)

func _cache_obstacle_footprints() -> void:
	for obstacle in TERRAIN.obstacles(zone_id):
		var center: Vector2 = obstacle[0]
		var radii: Vector2 = obstacle[1]
		var kind: String = str(obstacle[2])
		if kind == 'pond':
			_ponds.append(obstacle)
			_cache_pond(center, radii)
		else:
			# A trunk/crystal has a readable ground contact before its raised sprite.
			for step in range(3):
				var shadow: Color = Color('#1d3041') if zone_id == 'forgotten_mine' else Color('#233f35')
				shadow.a = 0.026 + float(step) * 0.021
				_add_shape(_ellipse(center + Vector2(0.05, 0.08), radii * (1.22 - float(step) * 0.13), 32, 0.0, 0.0), shadow)

func _cache_pond(center: Vector2, radii: Vector2) -> void:
	var bank: Color = _palette['path_edge']
	var water: Color = _palette['water']
	var shore: Color = _palette['water_edge']
	# Banks are OUTSIDE the collision ellipse; the actual water boundary is exact.
	for step in range(5):
		var margin: float = 0.34 - float(step) * 0.055
		var shade: Color = bank.lerp(_palette['path'], float(step) * 0.09)
		shade.a = 0.065 + float(step) * 0.035
		_add_shape(_ellipse(center, radii + Vector2(margin, margin * 0.8), 72, 0.75, 0.028), shade)
	shore.a = 0.90
	_add_shape(_ellipse(center, radii, 72, 0.75, 0.022), shore)
	# Closely spaced shallow-to-deep layers provide a quiet painted water gradient.
	for step in range(12):
		var fraction: float = float(step) / 11.0
		var shade: Color = shore.lerp(water, 0.5 + fraction * 0.5)
		shade.a = 0.32
		var water_center: Vector2 = center + Vector2(-0.035, 0.03) * fraction
		_add_shape(_ellipse(water_center, radii * (0.977 - fraction * 0.34), 72, 0.75 + fraction, 0.018), shade)
	var glint: PackedVector2Array = PackedVector2Array()
	for index in range(17):
		var angle: float = PI * (1.1 + float(index) / 16.0 * 0.62)
		glint.append(center + Vector2(cos(angle), sin(angle)) * radii * 0.963)
	var glint_color: Color = water.lightened(0.45)
	glint_color.a = 0.32
	_add_line(glint, glint_color, 0.022)

func _cache_ambient() -> void:
	var count: int = 22 if zone_id == 'moonrest_forest' else 14
	for index in range(count):
		var point: Vector2 = Vector2(fposmod(float(index * 17 + 3) * 1.193, 34.0) - 1.0, fposmod(float(index * 11 + 5) * 0.779, 22.0) - 1.0)
		_motes.append(Vector3(point.x, point.y, float(index) * 2.137))

func _draw_ambient(visible: Rect2) -> void:
	for pond in _ponds:
		var center: Vector2 = pond[0]
		var radii: Vector2 = pond[1]
		if not visible.intersects(Rect2(center - radii, radii * 2.0)):
			continue
		for ring in range(2):
			var phase: float = fposmod(elapsed * 0.11 + float(ring) * 0.5, 1.0)
			var scale: Vector2 = radii * (0.16 + phase * 0.63)
			draw_set_transform(_map_point(center), 0.0, scale * pixels_per_unit)
			var shimmer: Color = Color('#d2eee9')
			shimmer.a = sin(phase * PI) * 0.13
			draw_polyline(_unit_ring, shimmer, 0.010, true)
	draw_set_transform(_map_point(Vector2.ZERO), 0.0, Vector2.ONE * pixels_per_unit)
	var glow: Color = _palette['glow']
	for mote in _motes:
		var point: Vector2 = Vector2(mote.x, mote.y) + Vector2(sin(elapsed * 0.28 + mote.z) * 0.11, cos(elapsed * 0.21 + mote.z) * 0.08)
		if not visible.has_point(point):
			continue
		var pulse: float = 0.45 + sin(elapsed * 0.72 + mote.z) * 0.35
		var outer: Color = glow
		outer.a = pulse * 0.09
		draw_circle(point, 0.065, outer)
		var inner: Color = glow
		inner.a = pulse * (0.46 if zone_id == 'moonrest_forest' else 0.20)
		draw_circle(point, 0.020, inner)

func _inside_pond(point: Vector2, scale: float) -> bool:
	for obstacle in TERRAIN.obstacles(zone_id):
		if str(obstacle[2]) != 'pond':
			continue
		var center: Vector2 = obstacle[0]
		var radii: Vector2 = obstacle[1]
		if ((point - center) / (radii * scale)).length_squared() <= 1.0:
			return true
	return false

func _add_shape(points: PackedVector2Array, color: Color) -> void:
	if points.size() >= 3:
		_shapes.append({'points': points, 'color': color, 'bounds': _bounds(points)})

func _add_line(points: PackedVector2Array, color: Color, width: float) -> void:
	if points.size() >= 2:
		_lines.append({'points': points, 'color': color, 'width': width, 'bounds': _bounds(points).grow(width)})

func _bounds(points: PackedVector2Array) -> Rect2:
	var bounds: Rect2 = Rect2(points[0], Vector2.ZERO)
	for point in points:
		bounds = bounds.expand(point)
	return bounds

func _ellipse(center: Vector2, radii: Vector2, segments: int, phase: float, irregularity: float) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	for index in range(segments):
		var angle: float = float(index) / float(segments) * TAU
		var modulation: float = 1.0 + sin(angle * 3.0 + phase) * irregularity + cos(angle * 5.0 - phase) * irregularity * 0.5
		points.append(center + Vector2(cos(angle), sin(angle)) * radii * modulation)
	return points

func _smooth_route(controls: PackedVector2Array) -> PackedVector2Array:
	var samples: PackedVector2Array = PackedVector2Array()
	if controls.size() < 2:
		return controls
	for index in range(controls.size() - 1):
		var p0: Vector2 = controls[maxi(0, index - 1)]
		var p1: Vector2 = controls[index]
		var p2: Vector2 = controls[index + 1]
		var p3: Vector2 = controls[mini(controls.size() - 1, index + 2)]
		var count: int = maxi(6, int(ceil(p1.distance_to(p2) * 5.0)))
		for sample in range(count):
			var t: float = float(sample) / float(count)
			var position: Vector2 = (p1 * 2.0 + (p2 - p0) * t + (p0 * 2.0 - p1 * 5.0 + p2 * 4.0 - p3) * t * t + (-p0 + p1 * 3.0 - p2 * 3.0 + p3) * t * t * t) * 0.5
			samples.append(position)
	samples.append(controls[controls.size() - 1])
	return samples

func _ribbon(route: PackedVector2Array, width: float) -> PackedVector2Array:
	var outline: PackedVector2Array = PackedVector2Array()
	var other: PackedVector2Array = PackedVector2Array()
	for index in range(route.size()):
		var previous: Vector2 = route[maxi(0, index - 1)]
		var following: Vector2 = route[mini(route.size() - 1, index + 1)]
		var normal: Vector2 = (following - previous).normalized().orthogonal()
		var variation: float = 1.0 + sin(float(index) * 0.17) * 0.025
		outline.append(route[index] + normal * width * 0.5 * variation)
		other.append(route[index] - normal * width * 0.5 * variation)
	other.reverse()
	outline.append_array(other)
	return outline
