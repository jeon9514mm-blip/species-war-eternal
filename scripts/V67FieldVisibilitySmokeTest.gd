extends SceneTree
const PROPS := preload('res://scripts/portrait/PortraitMeadowProps.gd')
const MAP := preload('res://scripts/portrait/PortraitMinimap.gd')
const CATALOG := preload('res://scripts/FieldTerrainCatalog.gd')
class Hunt extends RefCounted:
	var current_target: int = -1
class Field extends Node:
	var current_zone_id: String = 'gray_meadow'
	var active_screen: String = 'combat'
	var combat_field_rect := Rect2(0,0,2304,1440)
	var hero_map_sprites: Array[Node2D] = []
	var deployed_heroes: Array = [{'id':'hero'}]
	var hero_battle_state: Dictionary = {'hero': {'hp':100}}
	var enemy_wave_sprites: Array[Node2D] = []
	var enemy_wave: Array = []
	var roaming_hunt := Hunt.new()
	func _combat_map_scale() -> Vector2:return Vector2.ONE*72.0
	func _map_world_position(point: Vector2) -> Vector2:return point*72.0
	func _field_actor_depth(y: float) -> int:return 2+clampi(int(y*.01),0,16)
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var field := Field.new()
	root.add_child(field)
	var layer := Node2D.new()
	field.add_child(layer)
	var hero := Node2D.new()
	layer.add_child(hero)
	field.hero_map_sprites.append(hero)
	var props := PROPS.new()
	field.add_child(props)
	props.install(field,layer)
	assert(props.props.size() == CATALOG.obstacles('gray_meadow').size()-2)
	var tree: Sprite2D = props.props[0]
	hero.position = tree.position-Vector2(0,50)
	props.refresh(1.0)
	assert(is_equal_approx(tree.modulate.a,PROPS.OCCLUDED_ALPHA))
	hero.position = tree.position+Vector2(0,30)
	props.refresh(1.0)
	assert(is_equal_approx(tree.modulate.a,1.0))
	hero.position = tree.position-Vector2(0,50)
	field.hero_battle_state['hero']['hp']=0
	props.refresh(1.0)
	assert(is_equal_approx(tree.modulate.a,1.0))
	var map := MAP.new()
	map.size=Vector2(138,84)
	assert(map.map_point(CATALOG.WORLD_SIZE).is_equal_approx(map.size))
	for zone: String in CATALOG.ZONE_IDS:
		map._cache_terrain(zone)
		assert(map._obstacle_shapes.size() == CATALOG.obstacles(zone).size())
		assert(map._road_points.size() == CATALOG.paths(zone).size())
		var count: int = map._obstacle_shapes.size()
		map._cache_terrain(zone)
		assert(map._obstacle_shapes.size() == count)
	map.free()
	field.free()
	print('v67 prop transparency + minimap catalog: 14/14 pass')
	quit()
