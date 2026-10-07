extends RefCounted
## Original Blender meshes; no atlas or billboard fallback in the 3D route.
const IDENTITIES=preload('res://scripts/art/HuntFrameCatalog.gd')
const RELEASE_PHASE=.44
var _entries: Dictionary={}
func _init() -> void:
	var data=JSON.parse_string(FileAccess.get_file_as_string('res://assets/models3d-v1/catalog.json'))
	if data is Dictionary:_entries=data.get('entries',{})
static func identity(source: AnimatedSprite2D,hero: bool) -> String:
	return IDENTITIES.identity(source,hero)
func load_entry(id: String) -> Dictionary:
	return _entries.get(id,{})
