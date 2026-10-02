extends Control
## A readable field chart: every blocking shape and road uses the same world
## data as the battlefield. Static geometry is cached; actor dots update at 7 Hz.
const TERRAIN := preload('res://scripts/maps3d/Map3DLayout.gd')
var game: Node
var _elapsed: float = 0.0
var _cached_zone: String = ''
var _cached_size: Vector2 = Vector2.ZERO
var _palette: Dictionary = {}
var _road_points: Array[PackedVector2Array] = []
var _road_widths: Array[float] = []
var _clearings: Array[PackedVector2Array] = []
var _obstacle_shapes: Array[PackedVector2Array] = []
var _obstacle_kinds: Array[String] = []

func _ready() -> void:
	name = 'PortraitMinimap'
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	resized.connect(queue_redraw)

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_elapsed += delta
	if _elapsed >= 0.15:
		_elapsed = 0.0
		queue_redraw()

func map_point(world: Vector2) -> Vector2:
	return world / TERRAIN.WORLD_SIZE * size

func _cache_terrain(zone: String) -> void:
	if zone == _cached_zone and size == _cached_size:
		return
	_cached_zone = zone
	_cached_size = size
	_palette = TERRAIN.palette(zone)
	_road_points.clear()
	_road_widths.clear()
	_clearings.clear()
	_obstacle_shapes.clear()
	_obstacle_kinds.clear()
	for path: Dictionary in TERRAIN.paths(zone):
		var projected := PackedVector2Array()
		for point: Vector2 in path['points']:
			projected.append(map_point(point))
		_road_points.append(projected)
		_road_widths.append(float(path['width']) * size.x / TERRAIN.WORLD_SIZE.x)
	for clearing: Array in TERRAIN.clearings(zone):
		_clearings.append(_ellipse(clearing[0], clearing[1]))
	for obstacle: Array in TERRAIN.obstacles(zone):
		_obstacle_shapes.append(_ellipse(obstacle[0], obstacle[1]))
		_obstacle_kinds.append(str(obstacle[2]))

func _ellipse(world: Vector2, radii: Vector2) -> PackedVector2Array:
	var points := PackedVector2Array()
	points.resize(20)
	var center: Vector2 = map_point(world)
	var radius: Vector2 = map_point(radii)
	for index: int in 20:
		var angle: float = float(index) * TAU / 20.0
		points[index] = center + Vector2(cos(angle), sin(angle)) * radius
	return points

func _draw() -> void:
	if not is_instance_valid(game) or size.x <= 0.0 or size.y <= 0.0:
		return
	_cache_terrain(str(game.current_zone_id))
	var rect := Rect2(Vector2.ZERO, size)
	var ground: Color = _palette['ground']
	var path: Color = _palette['path']
	var edge: Color = _palette['path_edge']
	draw_rect(rect, ground.darkened(0.33))
	for index: int in _road_points.size():
		draw_polyline(_road_points[index], edge.darkened(0.15), _road_widths[index] + 1.5, true)
		draw_polyline(_road_points[index], path.darkened(0.12), _road_widths[index], true)
	for clearing: PackedVector2Array in _clearings:
		draw_colored_polygon(clearing, path.darkened(0.12))
	for index: int in _obstacle_shapes.size():
		var color: Color = ground.darkened(0.62)
		match _obstacle_kinds[index]:
			'pond': color = _palette['water']
			'crystal': color = Color('#9aa7d9')
			'rock': color = Color('#554e4a')
		draw_colored_polygon(_obstacle_shapes[index], color)
	var terrain: Control = game.combat_labels.get('terrain')
	if is_instance_valid(terrain):
		var visible_world: Rect2 = terrain.visible_world_rect().intersection(Rect2(Vector2.ZERO, TERRAIN.WORLD_SIZE))
		if visible_world.has_area():
			var camera_rect := Rect2(map_point(visible_world.position), map_point(visible_world.size))
			draw_rect(camera_rect, Color(1, 0.97, 0.85, 0.08))
			draw_rect(camera_rect, Color('#ede3bbaa'), false, 1.0)
	var route: PackedVector2Array = game.field_navigation.route_preview('party_anchor', game.expedition_position)
	if route.size() > 1:
		var projected := PackedVector2Array()
		projected.resize(route.size())
		for index: int in route.size():
			projected[index] = map_point(route[index])
		draw_polyline(projected, Color('#ffe8a4'), 1.5, true)
	for id: Variant in game.party_movement.positions:
		if int(game.hero_battle_state.get(id, {}).get('hp', 0)) > 0:
			_dot(game.party_movement.positions[id], Color('#8dedff'), 2.0)
	for index: int in game.roaming_hunt.enemy_positions.size():
		if index >= game.enemy_wave.size() or int(game.enemy_wave[index].get('hp', 0)) <= 0:
			continue
		var pos: Vector2 = game.roaming_hunt.enemy_positions[index]
		_dot(pos, Color('#ff9b84'), 2.1)
		if index == game.roaming_hunt.current_target:
			draw_arc(map_point(pos), 4.1, 0, TAU, 16, Color('#ffe7a1'), 1.2, true)
	# A quiet inset frame leaves the map itself clear at its compact HUD size.
	draw_rect(rect.grow(-0.5), Color('#16272bcc'), false, 1.0)
	draw_rect(rect.grow(-1.5), Color('#b9c4a855'), false, 1.0)
	var frame_color := Color('#dfd7b4')
	draw_line(Vector2(2, 2), Vector2(10, 2), frame_color, 1.0)
	draw_line(Vector2(2, 2), Vector2(2, 9), frame_color, 1.0)
	draw_line(size - Vector2(2, 2), size - Vector2(10, 2), frame_color, 1.0)
	draw_line(size - Vector2(2, 2), size - Vector2(2, 9), frame_color, 1.0)

func _dot(world: Vector2, color: Color, radius: float) -> void:
	var point: Vector2 = map_point(world)
	draw_circle(point, radius + 0.9, Color('#132238'))
	draw_circle(point, radius, color)
