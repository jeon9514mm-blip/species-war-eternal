extends Node
## Raised scenery shares the same obstacle catalog, projection and feet depth
## as the actors. Canopies become transparent when they hide a living hero.
const TERRAIN := preload('res://scripts/FieldTerrainCatalog.gd')
const TREE := preload('res://assets/props/meadow-v60/canopy-tree.png')
const MOON_TREE := preload('res://assets/props/field-v61/moon-tree.png')
const CRYSTAL := preload('res://assets/props/field-v61/mine-crystal.png')
const ROCK_PATH := 'res://assets/terrain-v70/slate-boulder.png'
const OCCLUDED_ALPHA := 0.32
const MAX_PROP_COUNT := 72
var game: Node
var actor_layer: Node2D
var props: Array[Sprite2D] = []
var zone_id: String = 'gray_meadow'
var _world_positions: Array[Vector2] = []
var _world_heights: Array[float] = []
var _kinds: Array[String] = []
var _elapsed: float = 0.0

func install(main: Node, parent: Node2D) -> void:
	game = main
	actor_layer = parent
	zone_id = str(main.current_zone_id)
	name = 'PortraitMeadowProps' if zone_id == 'gray_meadow' else 'PortraitFieldProps'
	var entries: Array = TERRAIN.obstacles(zone_id).duplicate()
	entries.append_array(TERRAIN.decorations(zone_id))
	for obstacle: Array in entries:
		var kind: String = str(obstacle[2])
		if kind == 'pond':
			continue
		if props.size() >= MAX_PROP_COUNT:
			break
		var world: Vector2 = obstacle[0]
		var radii: Vector2 = obstacle[1]
		var art: Texture2D = texture_for(kind, zone_id)
		var height: float = visual_height(kind, radii)
		var prop := Sprite2D.new()
		prop.name = 'FieldProp_%d_%s' % [props.size(), kind]
		prop.texture = art
		prop.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		# The pivot stays at the trunk/rock base so y-sort matches combatants.
		prop.offset = Vector2(0, -float(art.get_height()) * 0.42)
		prop.set_meta('world_position', world)
		prop.set_meta('visual_height', height)
		prop.set_meta('obstacle_kind', kind)
		prop.set_meta('footprint', radii)
		parent.add_child(prop)
		props.append(prop)
		_world_positions.append(world)
		_world_heights.append(height)
		_kinds.append(kind)
	refresh()

static func texture_for(kind: String, zone: String) -> Texture2D:
	if kind == 'crystal':
		return CRYSTAL
	if kind == 'rock':
		return load(ROCK_PATH) as Texture2D if ResourceLoader.exists(ROCK_PATH) else CRYSTAL
	return TREE if zone == 'gray_meadow' else MOON_TREE

static func visual_height(kind: String, radii: Vector2) -> float:
	if kind == 'crystal':
		return clampf(radii.x * 1.8, 1.7, 2.55)
	if kind == 'rock':
		return clampf(radii.x * 1.5, 1.65, 2.5)
	return clampf(radii.x * 1.75 + 1.15, 2.50, 3.60)

func refresh(delta: float = 0.0) -> void:
	if not is_instance_valid(game) or not is_instance_valid(actor_layer):
		return
	var field: Rect2 = game.combat_field_rect
	var map_scale: float = game._combat_map_scale().x
	for index: int in props.size():
		var prop: Sprite2D = props[index]
		if not is_instance_valid(prop):
			continue
		prop.position = game._map_world_position(_world_positions[index])
		var height: float = map_scale * _world_heights[index]
		prop.scale = Vector2.ONE * height / float(prop.texture.get_height())
		prop.z_index = game._field_actor_depth(prop.position.y)
		# The lower edge of a tall canopy can remain outside the viewport while
		# its top is visible; use a full sprite rectangle for camera culling.
		var width: float = float(prop.texture.get_width()) * prop.scale.x
		var bounds := Rect2(prop.position + Vector2(-width * 0.5, -height * 0.92), Vector2(width, height))
		prop.visible = field.grow(12.0).intersects(bounds)
		if not prop.visible:
			continue
		var phase: float = _elapsed * 0.9 + float(index) * 1.73
		if _kinds[index] == 'tree':
			prop.rotation = sin(phase) * 0.009
		elif _kinds[index] == 'crystal':
			var light: float = 0.98 + sin(phase * 1.4) * 0.025
			prop.self_modulate = Color(light, light, 1.0)
		var canopy := Rect2(prop.position + Vector2(-width * 0.42, -height * 0.87), Vector2(width * 0.84, height * 0.77))
		var target_alpha: float = OCCLUDED_ALPHA if _hides_combatant(prop.position, canopy) else 1.0
		prop.modulate.a = move_toward(prop.modulate.a, target_alpha, delta * 3.6) if delta > 0.0 else target_alpha

func _hides_combatant(ground: Vector2, canopy: Rect2) -> bool:
	for index: int in mini(game.hero_map_sprites.size(), game.deployed_heroes.size()):
		var id: String = str(game.deployed_heroes[index].get('id', ''))
		if int(game.hero_battle_state.get(id, {}).get('hp', 0)) <= 0:
			continue
		var hero: Node2D = game.hero_map_sprites[index]
		if is_instance_valid(hero) and hero.visible and hero.position.y < ground.y + 8.0:
			if canopy.intersects(Rect2(hero.position + Vector2(-15, -48), Vector2(30, 45))):
				return true
	# Keep the attacked monster readable behind a foreground tree as well.
	var target: int = game.roaming_hunt.current_target
	if target >= 0 and target < game.enemy_wave_sprites.size() and target < game.enemy_wave.size():
		if int(game.enemy_wave[target].get('hp', 0)) > 0:
			var enemy: Node2D = game.enemy_wave_sprites[target]
			if is_instance_valid(enemy) and enemy.visible and enemy.position.y < ground.y + 8.0:
				return canopy.intersects(Rect2(enemy.position + Vector2(-18, -43), Vector2(36, 40)))
	return false

func _process(delta: float) -> void:
	if is_instance_valid(game) and game.active_screen == 'combat':
		_elapsed += delta
		refresh(delta)

func _exit_tree() -> void:
	for prop: Sprite2D in props:
		if is_instance_valid(prop):
			prop.queue_free()
