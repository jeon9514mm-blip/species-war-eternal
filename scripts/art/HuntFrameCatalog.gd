extends RefCounted
## One complete painting per pose. No anatomical fragmentation or bone weights.
const ROOT := 'res://assets/art-direction/hunt-frame-pilot/'
const ORIGINAL_ROOT := 'res://assets/art-direction/full-body-v2/'
const MONSTERS := {'초원 고블린':'goblin','들개 무리':'wild_dog','가시 멧돼지':'bristle_boar','철갑 두더지':'iron_mole','독버섯 정령':'mushroom','달빛 늑대':'moon_wolf','바람 까마귀':'wind_crow','광산 오크':'mine_orc','용암 박쥐':'lava_bat','수정 거미':'crystal_spider','숲의 망령':'forest_wraith','밤까마귀':'night_raven','서리 사슴':'frost_deer','초원왕 그룬':'grun','광맥의 거인 모르굴':'morgul','월식의 여왕 셀레네':'selene_boss'}
const RELEASE_PHASE := .44
# Leave the final recovery pose enough time to appear at 30 FPS. The impact
# boundary remains .44, the phase owned by the actual simulation release.
const ATTACK_PHASES := [0.0,.12,.28,.44,.56,.68,.80,.90]
var _entries: Dictionary = {}

static func identity(source: AnimatedSprite2D,hero: bool) -> String:
	if hero:return str(source.get('atlas_key'))
	return str(MONSTERS.get(str(source.get('pixel_monster_name')),''))

func load_entry(id: String) -> Dictionary:
	if _entries.has(id):return _entries[id]
	if id.is_empty() or id.contains('/') or id.contains('..'):return {}
	var path: String=ORIGINAL_ROOT+id+'/frames.json'
	var mobile: String='res://assets/mobile25d/'+id+'/frames.json'
	if FileAccess.file_exists(mobile):path=mobile
	if not FileAccess.file_exists(path) and id in ['leonhardt','goblin']:path=ROOT+id+'/frames.json'
	if not FileAccess.file_exists(path):return {}
	var parsed=JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary or str(parsed.get('id',''))!=id:return {}
	var entry: Dictionary=parsed
	for kind in ['attack','motion']:
		var sheet: Dictionary=entry.get(kind,{})
		if not sheet.has('atlas') or sheet.get('frames',[]).size()!=8 or float(sheet.get('native_height',0))<=0:return {}
		var texture:=load(str(sheet.atlas)) as Texture2D
		if texture==null:return {}
		var declared: Array=sheet.get('atlas_size',[])
		if declared.size()!=2 or Vector2(declared[0],declared[1])!=texture.get_size():return {}
		for frame: Dictionary in sheet.frames:
			var region: Array=frame.get('region',[])
			var anchor: Array=frame.get('anchor',[])
			if region.size()!=4 or anchor.size()!=2 or frame.get('silhouette_uv',[]).size()<3:return {}
			var rect:=Rect2(region[0],region[1],region[2],region[3])
			if not Rect2(Vector2.ZERO,texture.get_size()).encloses(rect):return {}
			if anchor[0]<0 or anchor[0]>rect.size.x or anchor[1]<0 or anchor[1]>rect.size.y:return {}
			var polygon:=PackedVector2Array()
			for point: Array in frame.silhouette_uv:polygon.append(Vector2(point[0],point[1])*rect.size)
			if Geometry2D.triangulate_polygon(polygon).is_empty():return {}
	_entries[id]=entry
	return entry

static func attack_frame(phase: float) -> int:
	var index:=0
	for i in ATTACK_PHASES.size():
		if phase+0.00001>=float(ATTACK_PHASES[i]):index=i
	return index
