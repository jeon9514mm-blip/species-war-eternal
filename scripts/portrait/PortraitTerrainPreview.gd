extends Control
## The destination card renders the same world geometry as the playable field.
const TERRAIN := preload('res://scripts/portrait/PortraitScenery.gd')
const CATALOG := preload('res://scripts/FieldTerrainCatalog.gd')
const PROPS := preload('res://scripts/portrait/PortraitMeadowProps.gd')
var zone_id := 'gray_meadow'
var _terrain: Control
var _props: Array[Sprite2D]=[]

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	clip_contents=true
	_terrain=TERRAIN.new()
	add_child(_terrain)
	_terrain.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_terrain.configure(zone_id,CATALOG.palette(zone_id)['ground'])
	var obstacles: Array=CATALOG.obstacles(zone_id).duplicate()
	obstacles.sort_custom(func(a: Array,b: Array)->bool:return a[0].y<b[0].y)
	for obstacle: Array in obstacles:
		var kind: String=str(obstacle[2])
		if kind=='pond':continue
		var art: Texture2D=PROPS.texture_for(kind,zone_id)
		var prop:=Sprite2D.new()
		prop.texture=art
		prop.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
		prop.offset=Vector2(0,-float(art.get_height())*.42)
		prop.set_meta('world',obstacle[0])
		prop.set_meta('height',PROPS.visual_height(kind,obstacle[1]))
		add_child(prop)
		_props.append(prop)
	resized.connect(_layout)
	_layout()

func _layout() -> void:
	if not is_instance_valid(_terrain):return
	var ppu: float=minf(size.x/34.0,size.y/22.0)
	_terrain.configure_world_view(ppu,size*.5)
	_terrain.set_camera_position(CATALOG.WORLD_SIZE*.5)
	for prop: Sprite2D in _props:
		var world: Vector2=prop.get_meta('world')
		prop.position=size*.5+(world-CATALOG.WORLD_SIZE*.5)*ppu
		prop.scale=Vector2.ONE*ppu*float(prop.get_meta('height'))/float(prop.texture.get_height())
