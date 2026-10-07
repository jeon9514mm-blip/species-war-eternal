extends RefCounted
## One complete painting per pose. No anatomical fragmentation or bone weights.
const ROOT := 'res://assets/art-direction/hunt-frame-pilot/'
const RELEASE_PHASE := .44
const ATTACK_PHASES := [0.0,.12,.28,.44,.56,.70,.84,.95]
var _entries: Dictionary = {}

static func identity(source: AnimatedSprite2D,hero: bool) -> String:
	if hero:return 'leonhardt' if str(source.get('atlas_key'))=='leonhardt' else ''
	return 'goblin' if str(source.get('pixel_monster_name'))=='초원 고블린' else ''

func load_entry(id: String) -> Dictionary:
	if id not in ['leonhardt','goblin']:return {}
	if _entries.has(id):return _entries[id]
	var path:=ROOT+id+'/frames.json'
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
